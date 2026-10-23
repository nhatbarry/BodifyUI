import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../core/refresh_flags.dart';
import '../../models/workout_plan_models.dart';
import '../../services/workout_plan_service.dart';
import 'schedule_calendar_view.dart';

/// The Workout tab: a list of the user's training schedules.
///
/// A schedule is opened to see and edit its calendar. Exactly one can be
/// switched on at a time - that is the one the rest of the app treats as "what
/// I am doing right now" - so the switch here is a radio, not a checkbox: the
/// server clears whichever schedule was on before, and the list re-reads its
/// answer rather than guessing at it locally.
class ScheduleListView extends StatefulWidget {
  const ScheduleListView({super.key});

  @override
  State<ScheduleListView> createState() => _ScheduleListViewState();
}

class _ScheduleListViewState extends State<ScheduleListView> {
  List<WorkoutPlan> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Drawn from the last list seen, if any, and refreshed underneath.
    final cached = _cached;
    if (cached != null) {
      _plans = List.of(cached);
      _isLoading = false;
    }
    _load(silent: cached != null);
    RefreshFlags.plans.addListener(_onPlansChanged);
  }

  @override
  void dispose() {
    RefreshFlags.plans.removeListener(_onPlansChanged);
    super.dispose();
  }

  /// A plan changed elsewhere - an AI Coach schedule was applied.
  void _onPlansChanged() => _load(silent: true);

  /// The last plan list seen, for as long as the app runs (memory only).
  static List<WorkoutPlan>? _cached;

  /// Writes sent and not yet answered - see [_mutate].
  int _inFlight = 0;

  /// [silent] refreshes without a spinner and keeps what is drawn on failure.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final plans = await WorkoutPlanService.instance.listPlans();
      _cached = plans;
      if (!mounted || _inFlight > 0) return;
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  /// Draws [next] at once, sends [write], and reloads quietly once the last
  /// write is answered; on failure the list goes back and the reason shows.
  Future<void> _mutate(
    List<WorkoutPlan> next,
    Future<void> Function() write,
  ) async {
    final before = _plans;
    setState(() => _plans = next);
    _cached = next;
    _inFlight++;
    try {
      await write();
    } catch (e) {
      _cached = before;
      if (mounted) setState(() => _plans = before);
      _showError(e);
    } finally {
      _inFlight--;
      if (_inFlight == 0 && mounted) _load(silent: true);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException ? error.message : '$error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleActive(WorkoutPlan plan) async {
    final activating = !plan.isActive;
    // Exactly one plan can be active (a partial unique index), so switching
    // one on switches whichever was on off - predictable, and drawn now.
    await _mutate(
      [
        for (final p in _plans)
          p.planId == plan.planId
              ? p.copyWith(isActive: activating)
              : (activating && p.isActive ? p.copyWith(isActive: false) : p),
      ],
      () => WorkoutPlanService.instance.setActive(plan.planId, activating),
    );
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || name.isEmpty) return;

    try {
      final plan = await WorkoutPlanService.instance.createPlan(name);
      // A user's first schedule becomes the active one; later ones do not
      // steal the switch from whatever they are currently following.
      if (_plans.every((p) => !p.isActive)) {
        await WorkoutPlanService.instance.setActive(plan.planId, true);
      }
      _load(silent: true);
      if (mounted) _open(plan);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _rename(WorkoutPlan plan) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: plan.name),
    );
    if (name == null || name.isEmpty || name == plan.name) return;
    await _mutate(
      [
        for (final p in _plans)
          p.planId == plan.planId ? p.copyWith(name: name) : p,
      ],
      () => WorkoutPlanService.instance.renamePlan(plan.planId, name),
    );
  }

  Future<void> _delete(WorkoutPlan plan) async {
    // Deleting cascades to every day and exercise underneath and cannot be
    // undone, so it asks first and names what goes with it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(tr('title_delete_schedule'),
            style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
        content: Text(
          tr('msg_delete_schedule_warning').replaceFirst('{name}', plan.name),
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('btn_cancel'),
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('btn_delete'),
                style: const TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _mutate(
      [for (final p in _plans) if (p.planId != plan.planId) p],
      () => WorkoutPlanService.instance.deletePlan(plan.planId),
    );
  }

  Future<void> _open(WorkoutPlan plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScheduleCalendarView(plan: plan)),
    );
    // Day counts on the cards go stale while the calendar is open.
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBody(),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _create,
            backgroundColor: context.colors.primary1,
            child: Icon(Icons.add, color: context.colors.onPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _plans.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: context.colors.primary1));
    }

    if (_error != null && _plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: context.colors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: Text(tr('btn_retry'))),
            ],
          ),
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: context.colors.surfaceVariant, shape: BoxShape.circle),
                child: Icon(Icons.calendar_month,
                    color: context.colors.textSecondary, size: 34),
              ),
              const SizedBox(height: 18),
              Text(tr('msg_no_schedules'),
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(tr('msg_no_schedules_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: context.colors.primary1,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
        itemCount: _plans.length,
        itemBuilder: (_, i) => _ScheduleCard(
          plan: _plans[i],
          onOpen: () => _open(_plans[i]),
          onToggleActive: () => _toggleActive(_plans[i]),
          onRename: () => _rename(_plans[i]),
          onDelete: () => _delete(_plans[i]),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final WorkoutPlan plan;
  final VoidCallback onOpen;
  final VoidCallback onToggleActive;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.plan,
    required this.onOpen,
    required this.onToggleActive,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dayCount = plan.plannedDayCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: plan.isActive
            ? Border.all(color: colors.primary1, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.calendar_month,
                      color: colors.primary1, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dayCount == 0
                            ? tr('msg_no_workout_days')
                            : tr('label_workout_days_count')
                                .replaceFirst('{n}', '$dayCount'),
                        style: TextStyle(
                            color: dayCount == 0
                                ? colors.textSecondary
                                : colors.primary1,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      if (plan.isActive) ...[
                        const SizedBox(height: 3),
                        Text(
                          tr('label_currently_following'),
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: plan.isActive,
                  onChanged: (_) => onToggleActive(),
                  activeThumbColor: colors.primary1,
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: colors.textSecondary, size: 20),
                  color: colors.surface,
                  onSelected: (value) {
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(tr('btn_rename'),
                          style: TextStyle(color: colors.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr('btn_delete'),
                          style: const TextStyle(color: Color(0xFFE74C3C))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String? initial;

  const _NameDialog({this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        widget.initial == null ? tr('title_new_schedule') : tr('btn_rename'),
        style: TextStyle(
            color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: tr('hint_schedule_name'),
          hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
          filled: true,
          fillColor: colors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text(tr('btn_cancel'), style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(tr('btn_save'), style: TextStyle(color: colors.primary1)),
        ),
      ],
    );
  }
}
