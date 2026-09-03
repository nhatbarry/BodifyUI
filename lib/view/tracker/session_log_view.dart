import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/workout_session_models.dart';
import '../../services/workout_session_service.dart';

/// Recording what was actually lifted, one exercise at a time.
///
/// The rows arrive already laid out: starting a session copies the planned
/// sets in with their targets, so this screen is filling in blanks rather than
/// building a list. Each row shows the target it is aiming at, which is the
/// number the user is trying to beat or match.
class SessionLogView extends StatefulWidget {
  final SessionExercise exercise;

  const SessionLogView({super.key, required this.exercise});

  @override
  State<SessionLogView> createState() => _SessionLogViewState();
}

class _SessionLogViewState extends State<SessionLogView> {
  late final List<SessionSet> _sets =
      List<SessionSet>.from(widget.exercise.sets);
  bool _busy = false;
  bool _changed = false;

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }

  Future<void> _record(int index) async {
    final target = _sets[index];
    final values = await showDialog<_Performed>(
      context: context,
      builder: (_) => _LogDialog(
        title: tr('setNumber').replaceFirst('{n}', '${target.setOrder}'),
        // Prefill from the target when nothing has been logged yet: most sets
        // are performed as planned, so the common case becomes one tap.
        reps: target.reps ?? target.targetReps,
        weight: target.weightKg ?? target.targetWeightKg,
        targetReps: target.targetReps,
        targetWeight: target.targetWeightKg,
      ),
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      final updated = await WorkoutSessionService.instance.recordSet(
        target.id,
        reps: values.reps,
        weightKg: values.weight,
        completed: true,
        clearReps: values.reps == null,
        clearWeight: values.weight == null,
      );
      if (!mounted) return;
      setState(() {
        _sets[index] = updated;
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _addExtraSet() async {
    final last = _sets.isEmpty ? null : _sets.last;
    final values = await showDialog<_Performed>(
      context: context,
      builder: (_) => _LogDialog(
        title: tr('addSet'),
        reps: last?.reps,
        weight: last?.weightKg,
      ),
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      final created = await WorkoutSessionService.instance.addSet(
        widget.exercise.id,
        reps: values.reps,
        weightKg: values.weight,
      );
      if (!mounted) return;
      setState(() {
        _sets.add(created);
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _delete(int index) async {
    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance.deleteSet(_sets[index].id);
      if (!mounted) return;
      setState(() {
        _sets.removeAt(index);
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final loggedCount = _sets.where((s) => s.isLogged).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.textPrimary),
          title: Text(
            widget.exercise.name ?? '#${widget.exercise.exerciseId}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 2,
                child: _busy
                    ? LinearProgressIndicator(
                        color: colors.primary1,
                        backgroundColor: Colors.transparent)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    ExerciseThumbnail(
                      url: widget.exercise.thumbnailUrl,
                      cacheKey: 'icon-${widget.exercise.exerciseId}',
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('setProgress')
                            .replaceFirst('{done}', '$loggedCount')
                            .replaceFirst('{total}', '${_sets.length}'),
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _sets.isEmpty
                    ? Center(
                        child: Text(tr('noTargetSets'),
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 13)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _sets.length,
                        itemBuilder: (_, i) => _LogRow(
                          set: _sets[i],
                          onTap: () => _record(i),
                          onDelete: () => _delete(i),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _addExtraSet,
                      icon: Icon(Icons.add, size: 18, color: colors.primary1),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary1),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      label: Text(tr('addSet'),
                          style: TextStyle(
                              color: colors.primary1,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final SessionSet set;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LogRow({
    required this.set,
    required this.onTap,
    required this.onDelete,
  });

  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logged = set.isLogged;

    String target() {
      if (set.targetReps == null && set.targetWeightKg == null) return '—';
      final reps = set.targetReps?.toString() ?? '—';
      final weight =
          set.targetWeightKg == null ? '' : ' × ${_trim(set.targetWeightKg!)}kg';
      return '$reps$weight';
    }

    String actual() {
      if (!logged) return tr('notLogged');
      final reps = set.reps?.toString() ?? '—';
      final weight =
          set.weightKg == null ? '' : ' × ${_trim(set.weightKg!)}kg';
      return '$reps$weight';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: logged
            ? Border.all(color: const Color(0xFF27AE60), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: logged ? const Color(0xFF27AE60) : colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: logged
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text('${set.setOrder}',
                          style: TextStyle(
                              color: colors.primary1,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tr("plannedShort")} ${target()}',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('${tr("actualShort")} ${actual()}',
                          style: TextStyle(
                              color: logged
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close,
                      color: Color(0xFFE74C3C), size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Performed {
  final int? reps;
  final double? weight;

  const _Performed(this.reps, this.weight);
}

class _LogDialog extends StatefulWidget {
  final String title;
  final int? reps;
  final double? weight;
  final int? targetReps;
  final double? targetWeight;

  const _LogDialog({
    required this.title,
    this.reps,
    this.weight,
    this.targetReps,
    this.targetWeight,
  });

  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
  late final _reps = TextEditingController(text: widget.reps?.toString() ?? '');
  late final _weight = TextEditingController(
      text: widget.weight == null ? '' : _trim(widget.weight!));

  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget field(String label, TextEditingController c,
            {bool decimal = false, bool autofocus = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            autofocus: autofocus,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              labelStyle:
                  TextStyle(color: colors.textSecondary, fontSize: 13),
              isDense: true,
              filled: true,
              fillColor: colors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );

    final hasTarget =
        widget.targetReps != null || widget.targetWeight != null;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(widget.title,
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTarget)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${tr("plannedShort")} ${widget.targetReps ?? "—"}'
                  '${widget.targetWeight == null ? "" : " × ${_trim(widget.targetWeight!)}kg"}',
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
            ),
          field(tr('reps'), _reps, autofocus: true),
          field(tr('targetWeightKg'), _weight, decimal: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel'),
              style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _Performed(
              int.tryParse(_reps.text.trim()),
              double.tryParse(_weight.text.trim().replaceAll(',', '.')),
            ),
          ),
          child: Text(tr('save'), style: TextStyle(color: colors.primary1)),
        ),
      ],
    );
  }
}
