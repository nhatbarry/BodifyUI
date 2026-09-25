import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/ai_badge.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/app_strings.dart';
import '../../services/workout_plan_service.dart';
import '../../models/workout_plan_models.dart';
import '../../core/api_exception.dart';
import '../../models/exercise_models.dart';
import '../../services/exercise_service.dart';
import 'exercise_detail_view.dart';

class ExerciseExplorerView extends StatefulWidget {
  /// Inside the catalog explorer, which draws its own app bar with the
  /// exercises / foods switch.
  final bool embedded;

  const ExerciseExplorerView({super.key, this.embedded = false});

  @override
  State<ExerciseExplorerView> createState() => _ExerciseExplorerViewState();
}

class _ExerciseExplorerViewState extends State<ExerciseExplorerView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ExerciseListItem> _items = [];
  ExerciseFilters? _filters;

  // The muscle filter travels as an id, not a label: labels are translated and
  // can be renamed, ids cannot.
  int? _muscleGroupId;
  String? _experienceLevel;

  int _page = 1;
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFilters();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Adds one exercise to today, always asking first.
  ///
  /// A shortcut, not a new concept: it ends at the same
  /// `PUT /workout-plans/{id}/dates/{date}/exercises` the calendar's picker
  /// uses. What it adds is the conversation that shortcut needs - a button
  /// that silently edits today's plan from a browsing screen is a button
  /// nobody trusts.
  ///
  /// Exactly one dialog per tap. When something is in the way, that dialog
  /// carries the decision (convert the rest day, pick a schedule); when
  /// nothing is, a plain "add this?" stands in its place.
  Future<void> _addToToday(ExerciseListItem item) async {
    final name = item.name ?? '#${item.exerciseId}';
    try {
      final plans = await WorkoutPlanService.instance.listPlans();
      if (!mounted) return;

      // No schedule at all: there is nothing to add to. Send them to the
      // Tracker tab rather than pushing the list screen here - out of its tab
      // it loses the chrome it is designed inside.
      if (plans.isEmpty) {
        final go = await _confirm(
          title: tr('title_no_plan_yet'),
          message: tr('msg_create_plan_first'),
          confirmLabel: tr('btn_go_to_schedules'),
        );
        if (go == true && mounted) Navigator.pop(context, _trackerTabIndex);
        return;
      }

      var plan = plans.where((p) => p.isActive).firstOrNull;
      // True once a dialog has already asked for this tap, so the final
      // confirmation is not a second prompt for the same decision.
      var asked = false;

      // Schedules exist but none is being followed. Asking which one also
      // answers "which schedule is mine now", so the choice is applied rather
      // than used once and forgotten.
      if (plan == null) {
        final chosen = await _pickPlan(plans);
        if (chosen == null || !mounted) return;
        await WorkoutPlanService.instance.setActive(chosen.planId, true);
        plan = chosen;
        asked = true;
      }

      final today = dateOnly(DateTime.now());
      final day =
          await WorkoutPlanService.instance.dayForDate(plan.planId, today);
      if (!mounted) return;

      final existing =
          day?.exercises.map((e) => e.exerciseId).toList() ?? <int>[];

      if (existing.contains(item.exerciseId)) {
        await _confirm(
          title: tr('title_already_added'),
          message: tr('msg_already_in_today_long').replaceFirst('{name}', name),
          confirmLabel: null,
        );
        return;
      }

      // A rest day is a deliberate row, not an empty date. Turning it into a
      // training day is the user's call, so it is asked rather than assumed -
      // and the API would answer 409 anyway.
      if (day?.isRestDay ?? false) {
        final convert = await _confirm(
          title: tr('title_rest_day'),
          message: tr('msg_convert_rest_day'),
          confirmLabel: tr('btn_convert_rest_day'),
        );
        if (convert != true || !mounted) return;
        await WorkoutPlanService.instance
            .setDateRestDay(plan.planId, today, false);
        asked = true;
      }

      if (!asked) {
        final confirmed = await _confirm(
          title: tr('title_add_to_today'),
          message: tr('msg_add_to_today')
              .replaceFirst('{name}', name)
              .replaceFirst('{plan}', plan.name),
          confirmLabel: tr('btn_add_to_today'),
        );
        if (confirmed != true || !mounted) return;
      }

      await WorkoutPlanService.instance.setDateExercises(
        plan.planId,
        today,
        [...existing, item.exerciseId],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            tr('toast_added_to_today').replaceFirst('{name}', name)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : tr('error_save_failed')),
      ));
    }
  }

  /// Tracker is the second tab. Popping this index asks MainTabView to land
  /// there instead of back on whatever opened the explorer.
  static const int _trackerTabIndex = 1;

  /// A yes/no prompt. `confirmLabel` null makes it an acknowledgement, with
  /// only a way out - used where there is nothing to decide.
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String? confirmLabel,
  }) {
    final colors = context.colors;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(title,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(message,
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(confirmLabel == null ? tr('btn_nice') : tr('btn_cancel'),
                style: TextStyle(color: colors.textSecondary)),
          ),
          if (confirmLabel != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel,
                  style: TextStyle(color: colors.primary1)),
            ),
        ],
      ),
    );
  }

  Future<WorkoutPlan?> _pickPlan(List<WorkoutPlan> plans) {
    final colors = context.colors;
    return showDialog<WorkoutPlan>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: colors.surface,
        title: Text(tr('title_pick_plan'),
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(tr('msg_pick_plan_activates'),
                style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ),
          for (final plan in plans)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, plan),
              child: Text(plan.name,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await ExerciseService.instance.getFilters();
      if (mounted) setState(() => _filters = filters);
    } on ApiException {
      // The list still works without the filter chips.
    }
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Search on a debounce so typing does not fire a request per keystroke.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
      });
    }

    try {
      final result = await ExerciseService.instance.listExercises(
        page: _page,
        search: _searchController.text,
        muscleGroup: _muscleGroupId?.toString(),
        experienceLevel: _experienceLevel,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _total = result.total;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _items.length >= _total) return;
    setState(() => _isLoadingMore = true);
    _page += 1;
    await _load();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _toggleMuscle(int id) {
    setState(() => _muscleGroupId = _muscleGroupId == id ? null : id);
    _load(reset: true);
  }

  void _toggleLevel(String level) {
    setState(() => _experienceLevel = _experienceLevel == level ? null : level);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: context.colors.surface,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: context.colors.textPrimary),
              title: Text(
                tr('title_exercises'),
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(15)),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
                  border: InputBorder.none,
                  hintText: tr('hint_search_exercises'),
                  hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: context.colors.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: context.colors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _load(reset: true);
                          },
                        ),
                ),
              ),
            ),
          ),
          if (_filters != null) _buildFilterChips(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  _isLoading ? tr('msg_loading') : "$_total ${tr('label_exercise_count')}",
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // Two rows rather than one long strip: levels and muscle groups are
    // independent filters, and mixing them in a single scroller meant scrolling
    // past the levels to reach any muscle.
    return Column(
      children: [
        _chipRow([
          for (final level in _filters!.experienceLevels)
            _chip(level, _experienceLevel == level, () => _toggleLevel(level)),
        ]),
        const SizedBox(height: 6),
        // Every muscle group, not a truncated slice: the row scrolls
        // horizontally, and cutting the list hid common filters ("Cơ ngực" sat
        // at position 15).
        _chipRow([
          for (final muscle in _filters!.muscleGroups)
            _chip(muscle.name, _muscleGroupId == muscle.id,
                () => _toggleMuscle(muscle.id)),
        ]),
      ],
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: chips,
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: context.colors.primaryGradient)
                : null,
            color: selected ? null : context.colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.colors.surface : context.colors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: context.colors.primary1));
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: context.colors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(reset: true),
                child: Text(tr('btn_retry'),
                    style: TextStyle(color: context.colors.primary1)),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(tr('msg_no_exercises_found'),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _items.length + (_items.length < _total ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(color: context.colors.primary1)),
          );
        }
        return _ExerciseRow(
          item: _items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDetailView(exerciseId: _items[index].exerciseId),
            ),
          ),
          onAddToToday: () => _addToToday(_items[index]),
        );
      },
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseListItem item;
  final VoidCallback onTap;
  final VoidCallback onAddToToday;

  const _ExerciseRow({
    required this.item,
    required this.onTap,
    required this.onAddToToday,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            ExerciseThumbnail(
              url: item.listImageUrl,
              cacheKey: item.listImageCacheKey,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name ?? "#${item.exerciseId}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      AiBadge(algorithm: item.aiAlgorithm),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [item.experienceLevel, item.exerciseType, item.mechanics]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(" · "),
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            // The shortcut: from browsing straight into today's plan, without
            // going Tracker -> plan -> today -> picker to add one exercise.
            IconButton(
              onPressed: onAddToToday,
              visualDensity: VisualDensity.compact,
              tooltip: tr('btn_add_to_today'),
              icon: Icon(Icons.add_circle_outline,
                  color: context.colors.primary1, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
