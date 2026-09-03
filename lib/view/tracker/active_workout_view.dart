import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/workout_session_models.dart';
import '../../services/workout_session_service.dart';

/// The workout you are doing right now.
///
/// One screen for the whole session rather than a screen per exercise: mid-set
/// with a bar in your hands, navigating in and out to log three numbers is the
/// wrong shape. Everything is here - the clock, every exercise, every set -
/// and a set is one tap and two fields.
///
/// Time-based exercises (plank and friends) are logged as reps for now. The
/// backend already stores `duration_seconds` per set; nothing writes it yet.
class ActiveWorkoutView extends StatefulWidget {
  final WorkoutSession session;

  const ActiveWorkoutView({super.key, required this.session});

  @override
  State<ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> {
  late WorkoutSession _session = widget.session;
  bool _busy = false;

  /// Seconds ticked locally since the server last told us the elapsed time.
  ///
  /// The clock is the server's - it knows when the session started and how
  /// long it was paused - and this only fills the gaps between responses, so
  /// a backgrounded app or a phone with a skewed clock still shows the truth
  /// the moment anything is saved.
  int _ticks = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTicker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTicker() {
    _timer?.cancel();
    _ticks = 0;
    if (!_session.isInProgress) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ticks++);
    });
  }

  void _apply(WorkoutSession session) {
    setState(() => _session = session);
    _restartTicker();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }

  Future<void> _reload() async {
    try {
      _apply(await WorkoutSessionService.instance
          .getSession(_session.sessionId));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _run(Future<WorkoutSession> Function() action) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      _apply(updated);
      setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _togglePause() => _run(() => _session.isPaused
      ? WorkoutSessionService.instance.resumeSession(_session.sessionId)
      : WorkoutSessionService.instance.pauseSession(_session.sessionId));

  Future<void> _finish() async {
    final logged = _session.summary.completedSetCount;
    final total = _session.summary.setCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(tr('finishWorkout'),
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
          // Worth saying out loud: an unfinished workout is easy to walk away
          // from by accident, and finishing cannot be undone.
          logged < total
              ? tr('finishWithUnlogged')
                  .replaceFirst('{done}', '$logged')
                  .replaceFirst('{total}', '$total')
              : tr('finishConfirm'),
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel'),
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('finishWorkout'),
                style: TextStyle(color: context.colors.primary1)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance.finishSession(_session.sessionId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  /// Records one set, then re-reads the session so the totals at the top stay
  /// consistent with the rows underneath.
  Future<void> _logSet(SessionExercise exercise, SessionSet target) async {
    final values = await showDialog<_Performed>(
      context: context,
      builder: (_) => _SetDialog(
        title: '${exercise.name ?? ""} · '
            '${tr("setNumber").replaceFirst("{n}", "${target.setOrder}")}',
        reps: target.reps ?? target.targetReps,
        weight: target.weightKg ?? target.targetWeightKg,
        targetReps: target.targetReps,
        targetWeight: target.targetWeightKg,
      ),
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance.recordSet(
        target.id,
        reps: values.reps,
        weightKg: values.weight,
        completed: true,
        clearReps: values.reps == null,
        clearWeight: values.weight == null,
      );
      await _reload();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _addSet(SessionExercise exercise) async {
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;
    final values = await showDialog<_Performed>(
      context: context,
      builder: (_) => _SetDialog(
        title: '${exercise.name ?? ""} · ${tr("addSet")}',
        reps: last?.reps,
        weight: last?.weightKg,
      ),
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance
          .addSet(exercise.id, reps: values.reps, weightKg: values.weight);
      await _reload();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _deleteSet(SessionSet set) async {
    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance.deleteSet(set.id);
      await _reload();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  static String _clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  int get _elapsed => (_session.durationSeconds ?? 0) + _ticks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      // Leaving does not end the workout - it keeps running on the server, and
      // the calendar offers to come back to it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.textPrimary),
          title: Text(
            // Not dayName: days created from the calendar are named with the
            // ISO date, which is an identifier for the plan, not a label for
            // a screen. The plan's own name is what the user recognises.
            _session.planName ?? tr('workoutInProgress'),
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
              _buildHeader(),
              Expanded(
                child: _session.exercises.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            tr('noExercisesInSession'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        itemCount: _session.exercises.length,
                        itemBuilder: (_, i) => _ExerciseCard(
                          exercise: _session.exercises[i],
                          busy: _busy,
                          onLog: (s) => _logSet(_session.exercises[i], s),
                          onAdd: () => _addSet(_session.exercises[i]),
                          onDelete: _deleteSet,
                        ),
                      ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
    final s = _session.summary;
    final paused = _session.isPaused;

    Widget stat(String value, String label) => Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: paused
            ? Border.all(color: colors.primary1.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(paused ? Icons.pause_circle : Icons.timer,
                  size: 20, color: colors.primary1),
              const SizedBox(width: 8),
              Text(
                _clock(_elapsed),
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          if (paused)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(tr('workoutPaused'),
                  style: TextStyle(color: colors.primary1, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              stat('${s.completedSetCount}/${s.setCount}', tr('setsLabel')),
              stat('${s.totalReps}', tr('reps')),
              stat(_volume(s.totalVolumeKg), tr('volumeLabel')),
            ],
          ),
        ],
      ),
    );
  }

  static String _volume(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}t';
    return '${kg.round()}kg';
  }

  Widget _buildActions() {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _togglePause,
                icon: Icon(
                    _session.isPaused ? Icons.play_arrow : Icons.pause,
                    size: 18,
                    color: colors.primary1),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.primary1),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                label: Text(
                  _session.isPaused ? tr('resumeWorkout') : tr('pauseWorkout'),
                  style: TextStyle(
                      color: colors.primary1, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _finish,
                icon: const Icon(Icons.check, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary1,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                label: Text(tr('finishWorkout'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final SessionExercise exercise;
  final bool busy;
  final void Function(SessionSet) onLog;
  final VoidCallback onAdd;
  final void Function(SessionSet) onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.busy,
    required this.onLog,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logged = exercise.loggedSetCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExerciseThumbnail(
                url: exercise.thumbnailUrl,
                cacheKey: 'icon-${exercise.exerciseId}',
                size: 42,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name ?? '#${exercise.exerciseId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('setProgress')
                          .replaceFirst('{done}', '$logged')
                          .replaceFirst('{total}', '${exercise.sets.length}'),
                      style: TextStyle(
                          color: logged == exercise.sets.length &&
                                  exercise.sets.isNotEmpty
                              ? const Color(0xFF27AE60)
                              : colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in exercise.sets)
            _SetRow(
              set: s,
              onTap: busy ? null : () => onLog(s),
              onDelete: busy ? null : () => onDelete(s),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : onAdd,
              icon: Icon(Icons.add, size: 16, color: colors.primary1),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              label: Text(tr('addSet'),
                  style: TextStyle(color: colors.primary1, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final SessionSet set;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _SetRow({required this.set, this.onTap, this.onDelete});

  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = set.isLogged;

    String target() {
      if (set.targetReps == null && set.targetWeightKg == null) return '—';
      final reps = set.targetReps?.toString() ?? '—';
      final w = set.targetWeightKg == null
          ? ''
          : ' × ${_trim(set.targetWeightKg!)}kg';
      return '$reps$w';
    }

    String actual() {
      if (!done) return tr('notLogged');
      final reps = set.reps?.toString() ?? '—';
      final w = set.weightKg == null ? '' : ' × ${_trim(set.weightKg!)}kg';
      return '$reps$w';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? const Color(0xFF27AE60) : colors.surface,
                shape: BoxShape.circle,
              ),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text('${set.setOrder}',
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text('${tr("plannedShort")} ${target()}',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 11)),
                  ),
                  Expanded(
                    child: Text(
                      '${tr("actualShort")} ${actual()}',
                      style: TextStyle(
                          color:
                              done ? colors.textPrimary : colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close,
                  color: Color(0xFFE74C3C), size: 16),
            ),
          ],
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

class _SetDialog extends StatefulWidget {
  final String title;
  final int? reps;
  final double? weight;
  final int? targetReps;
  final double? targetWeight;

  const _SetDialog({
    required this.title,
    this.reps,
    this.weight,
    this.targetReps,
    this.targetWeight,
  });

  @override
  State<_SetDialog> createState() => _SetDialogState();
}

class _SetDialogState extends State<_SetDialog> {
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
            // Select-all on focus: the field is pre-filled with the target,
            // and the usual edit is to replace it, not to append to it.
            onTap: () => c.selection =
                TextSelection(baseOffset: 0, extentOffset: c.text.length),
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

    final hasTarget = widget.targetReps != null || widget.targetWeight != null;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
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
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
