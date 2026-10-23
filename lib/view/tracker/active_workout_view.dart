import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../core/refresh_flags.dart';
import '../../common_widget/achievement_unlock_dialog.dart';
import '../../common_widget/ai_badge.dart';
import '../../common_widget/set_input_fields.dart';
import '../../models/ai_set_result.dart';
import '../../models/progress_models.dart';
import '../../models/workout_session_models.dart';
import '../../posecoach/exercise_processor_factory.dart';
import '../../services/workout_session_service.dart';
import 'live_camera_set_view.dart';

/// Planned vs actual, told apart by colour instead of a "KH"/"TT" prefix.
/// Green matches the completed-checkmark colour already used on this screen.
const _kPlannedColor = Color(0xFFF2994A);
const _kActualColor = Color(0xFF27AE60);

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
    _syncWithPlan();
  }

  /// Pulls the session's exercise list back in line with the plan for its date.
  ///
  /// Run on open rather than only on start: the copy taken when the workout
  /// began goes stale the moment the user edits the day and comes back, which
  /// left them looking at exercises they had just replaced with no way out.
  ///
  /// Failure is swallowed on purpose. The session on screen is still the one
  /// the server has; refusing to show a workout because a re-sync failed would
  /// be a worse outcome than showing a slightly stale list.
  Future<void> _syncWithPlan() async {
    try {
      final synced = await WorkoutSessionService.instance
          .syncSessionWithPlan(_session.sessionId);
      if (mounted) _apply(synced);
    } catch (_) {}
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

  /// Writes sent and not yet answered - see [_mutate].
  int _inFlight = 0;

  /// Draws [next] at once and sends [write] in the background: a set logged
  /// with a bar in hand should tick the moment it is tapped, not a round trip
  /// later. On success the session is re-read quietly so server figures
  /// replace the prediction; a re-read that lands while another write is still
  /// out is dropped, the last one to finish reads again. On failure the screen
  /// goes back to what it was and says why.
  Future<void> _mutate(
    WorkoutSession next,
    Future<void> Function() write,
  ) async {
    final before = _session;
    setState(() => _session = next);
    _inFlight++;
    try {
      await write();
    } catch (e) {
      if (mounted) setState(() => _session = before);
      _showError(e);
    } finally {
      _inFlight--;
      if (_inFlight == 0 && mounted) {
        try {
          final fresh = await WorkoutSessionService.instance
              .getSession(_session.sessionId);
          if (mounted && _inFlight == 0) _apply(fresh);
        } catch (_) {
          // Keep the prediction; the next write or visit reads again.
        }
      }
    }
  }

  WorkoutSession _withSets(
    int exerciseId,
    List<SessionSet> Function(List<SessionSet>) change,
  ) =>
      _session.withExercises([
        for (final e in _session.exercises)
          e.id == exerciseId ? e.withSets(change(e.sets)) : e,
      ]);

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
        title: Text(tr('btn_finish_workout'),
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
          // Worth saying out loud: an unfinished workout is easy to walk away
          // from by accident, and finishing cannot be undone.
          logged < total
              ? tr('msg_finish_with_unlogged')
                  .replaceFirst('{done}', '$logged')
                  .replaceFirst('{total}', '$total')
              : tr('msg_finish_confirm'),
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
            child: Text(tr('btn_finish_workout'),
                style: TextStyle(color: context.colors.primary1)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      // Snapshotted before finishing: the backend decides unlocks during the
      // finish call, so the only way to know which ones are new is to have
      // asked beforehand. "The count went up" would celebrate again on every
      // reload.
      final before = await unlockedAchievementIds();
      final finished =
          await WorkoutSessionService.instance.finishSession(_session.sessionId);
      // The one moment records, achievements and completion stats actually
      // change - Home and Profile should pick this up next time either is
      // opened, not keep showing whatever they last loaded.
      RefreshFlags.markWorkoutFinished();
      if (!mounted) return;

      // Celebrate before leaving: popping first would put the dialog on a
      // screen that is already tearing down.
      await showNewUnlocks(context, before);
      if (!mounted) return;
      Navigator.pop(context, finished);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  /// The last set before this one that actually has numbers in it.
  ///
  /// Skips untouched sets: a plan of three copies in three blanks, and
  /// prefilling set 3 from an empty set 2 would just clear the form.
  static SessionSet? _previousLogged(SessionExercise exercise, SessionSet current) {
    SessionSet? found;
    for (final set in exercise.sets) {
      if (set.setOrder >= current.setOrder) break;
      if (set.isLogged) found = set;
    }
    return found;
  }

  /// Records one set, then re-reads the session so the totals at the top stay
  /// consistent with the rows underneath.
  Future<void> _logSet(SessionExercise exercise, SessionSet target) async {
    if (target.id < 0) return;
    final spec = SetFieldSpec.of(exercise.trackingType);
    final outcome = await showDialog<Object>(
      context: context,
      builder: (_) => _SetDialog(
        title: '${exercise.name ?? ""} · '
            '${tr("title_set_number").replaceFirst("{n}", "${target.setOrder}")}',
        trackingType: exercise.trackingType,
        from: target,
        previous: _previousLogged(exercise, target),
        aiAlgorithm: exercise.aiAlgorithm,
      ),
    );
    if (outcome == null) return;

    // The dialog offers two ways to fill a set in, and hands back whichever
    // the user chose: typed numbers, or "let the camera do it".
    if (outcome == _SetDialog.trainWithAi) {
      await _logSetWithCamera(exercise);
      return;
    }

    final values = outcome as SetValues;

    // Only the axes this exercise uses can be cleared. Sending null for a
    // Plank's reps would be a correction the user never made - and drawing
    // it would show one.
    final clearReps = values.reps == null && spec.reps;
    final clearDuration = values.durationSeconds == null && spec.duration;
    final clearDistance = values.distanceM == null && spec.distance;

    await _mutate(
      _withSets(exercise.id, (sets) => [
            for (final s in sets)
              s.id != target.id
                  ? s
                  : s.performed(
                      reps: values.reps ?? (clearReps ? null : s.reps),
                      weightKg: values.weightKg,
                      durationSeconds: values.durationSeconds ??
                          (clearDuration ? null : s.durationSeconds),
                      distanceM: values.distanceM ??
                          (clearDistance ? null : s.distanceM),
                    ),
          ]),
      () => WorkoutSessionService.instance.recordSet(
        target.id,
        reps: values.reps,
        weightKg: values.weightKg,
        durationSeconds: values.durationSeconds,
        distanceM: values.distanceM,
        completed: true,
        clearReps: clearReps,
        clearWeight: values.weightKg == null,
        clearDuration: clearDuration,
        clearDistance: clearDistance,
      ),
    );
  }

  /// Hands the exercise to the camera, then records whatever it counted.
  ///
  /// The result always lands as a *new* set rather than filling in the planned
  /// one the user tapped: the AI fields can only be written when a set is
  /// created (the server treats them as a snapshot and refuses to revise
  /// them), so writing them into an existing row is not something the API
  /// allows - by design.
  Future<void> _logSetWithCamera(SessionExercise exercise) async {
    final result = await Navigator.push<AiSetResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LiveCameraSetView(exercise: exercise),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance.addSet(
        exercise.id,
        reps: result.reps,
        aiAlgorithm: result.algorithm,
        aiRepScores: result.repScores,
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
    final outcome = await showDialog<Object>(
      context: context,
      builder: (_) => _SetDialog(
        title: '${exercise.name ?? ""} · ${tr("btn_add_set")}',
        trackingType: exercise.trackingType,
        from: last,
        showTarget: false,
        aiAlgorithm: exercise.aiAlgorithm,
      ),
    );
    if (outcome == null) return;

    if (outcome == _SetDialog.trainWithAi) {
      await _logSetWithCamera(exercise);
      return;
    }

    final values = outcome as SetValues;

    // Drawn under a negative id until the server hands out the real one; a
    // tap on it before then is ignored (see _logSet/_deleteSet).
    final draft = SessionSet(
      id: -DateTime.now().microsecondsSinceEpoch,
      setOrder: last == null ? 1 : last.setOrder + 1,
      // A set added mid-workout is one the user just did.
      completed: true,
      reps: values.reps,
      weightKg: values.weightKg,
      durationSeconds: values.durationSeconds,
      distanceM: values.distanceM,
    );
    await _mutate(
      _withSets(exercise.id, (sets) => [...sets, draft]),
      () => WorkoutSessionService.instance.addSet(
        exercise.id,
        reps: values.reps,
        weightKg: values.weightKg,
        durationSeconds: values.durationSeconds,
        distanceM: values.distanceM,
      ),
    );
  }

  Future<void> _deleteSet(SessionSet set) async {
    if (set.id < 0) return;
    await _mutate(
      _session.withExercises([
        for (final e in _session.exercises)
          e.withSets([for (final s in e.sets) if (s.id != set.id) s]),
      ]),
      () => WorkoutSessionService.instance.deleteSet(set.id),
    );
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
        if (!didPop) Navigator.pop(context, _session);
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
            _session.planName ?? tr('label_workout_in_progress'),
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
                            tr('msg_no_exercises_in_session'),
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
              child: Text(tr('label_workout_paused'),
                  style: TextStyle(color: colors.primary1, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              stat('${s.completedSetCount}/${s.setCount}', tr('label_sets')),
              stat('${s.totalReps}', tr('label_reps')),
              stat(_volume(s.totalVolumeKg), tr('label_volume')),
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
                  _session.isPaused ? tr('btn_resume_workout') : tr('btn_pause_workout'),
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
                label: Text(tr('btn_finish_workout'),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            exercise.name ?? '#${exercise.exerciseId}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        AiBadge(algorithm: exercise.aiAlgorithm),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('label_set_progress')
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
              label: Text(tr('btn_add_set'),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = set.isLogged;

    // Built from whichever axes the set carries, so a Plank reads "60 giây"
    // instead of "— × —".
    String target() {
      final text = formatTarget(
        reps: set.targetReps,
        weightKg: set.targetWeightKg,
        durationSeconds: set.targetDurationSeconds,
        distanceM: set.targetDistanceM,
      );
      return text.isEmpty ? '—' : text;
    }

    String actual() {
      if (!done) return tr('label_not_logged');
      final text = formatTarget(
        reps: set.reps,
        weightKg: set.weightKg,
        durationSeconds: set.durationSeconds,
        distanceM: set.distanceM,
      );
      return text.isEmpty ? '—' : text;
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
                    child: Text(target(),
                        style: const TextStyle(
                            color: _kPlannedColor, fontSize: 11)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            actual(),
                            style: TextStyle(
                                color:
                                    done ? _kActualColor : colors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        // What the camera made of the set, when it was the one
                        // that counted it. A rep count alone cannot say whether
                        // those reps were worth having.
                        if (set.isAiScored && set.aiScorePercent != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${set.aiScorePercent!.round()}%',
                              style: TextStyle(
                                color: set.aiScorePercent! >= 90
                                    ? _kActualColor
                                    : _kPlannedColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
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

// Replaced by SetValues from set_input_fields.dart, which carries every axis.

class _SetDialog extends StatefulWidget {
  final String title;
  final TrackingType trackingType;
  final SessionSet? from;

  /// The set logged just before this one, if any. Sets in a row usually
  /// repeat, and after the first one the number the user is about to type is
  /// far more likely to be "the same as last set" than "whatever the plan said
  /// weeks ago".
  final SessionSet? previous;

  /// An extra set has no plan of its own, so the previous set's target must
  /// not be shown as if it were this one's.
  final bool showTarget;

  /// The exercise's camera algorithm, if it has one. Only then is there a
  /// second way to fill this set in.
  final String? aiAlgorithm;

  /// What the dialog pops when the user picks the camera instead of typing.
  /// A sentinel rather than a second dialog result type: the caller has to
  /// tell "typed these numbers" from "go to the camera", and null already
  /// means "cancelled".
  static const String trainWithAi = 'train_with_ai';

  const _SetDialog({
    required this.title,
    required this.trackingType,
    this.from,
    this.previous,
    this.showTarget = true,
    this.aiAlgorithm,
  });

  @override
  State<_SetDialog> createState() => _SetDialogState();
}

class _SetDialogState extends State<_SetDialog> {
  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';
  static String _pre(double? v) => v == null ? '' : _trim(v);

  // Prefilled from the performed value if there is one, otherwise the target:
  // most sets go as planned, so the common case is one tap.
  // Prefill order: what is already on this set, then what the previous set was
  // actually done at, then the plan. Sets in a row usually repeat, so after
  // the first one "the same as last set" beats "whatever the plan said weeks
  // ago" as a starting guess.
  late final _reps = TextEditingController(
      text: '${widget.from?.reps ?? widget.previous?.reps ?? widget.from?.targetReps ?? ''}');
  late final _weight = TextEditingController(
      text: _pre(widget.from?.weightKg ??
          widget.previous?.weightKg ??
          widget.from?.targetWeightKg));
  late final _duration = TextEditingController(
      text: '${widget.from?.durationSeconds ?? widget.previous?.durationSeconds ?? widget.from?.targetDurationSeconds ?? ''}');
  late final _distance = TextEditingController(
      text: _pre(widget.from?.distanceM ??
          widget.previous?.distanceM ??
          widget.from?.targetDistanceM));

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    _duration.dispose();
    _distance.dispose();
    super.dispose();
  }

  String _label(String key) => switch (key) {
        'duration' => tr('label_duration_seconds'),
        'distance' => tr('label_distance_m'),
        'weight' => tr('label_target_weight_kg'),
        _ => tr('label_reps'),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final set = widget.from;

    final target = set == null || !widget.showTarget
        ? ''
        : formatTarget(
            reps: set.targetReps,
            weightKg: set.targetWeightKg,
            durationSeconds: set.targetDurationSeconds,
            distanceM: set.targetDistanceM,
          );

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
          if (target.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(target,
                    style: const TextStyle(
                        color: _kPlannedColor, fontSize: 12)),
              ),
            ),
          // Offered above the fields, not instead of them: the camera is the
          // faster way to fill this set in when it can, and typing stays the
          // way that always works.
          if (supportsAiCoach(widget.aiAlgorithm)) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _SetDialog.trainWithAi),
                icon: Icon(Icons.videocam, size: 18, color: colors.primary1),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: colors.primary1.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                label: Text(tr('btn_train_with_ai'),
                    style: TextStyle(color: colors.primary1, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SetInputFields(
            trackingType: widget.trackingType,
            reps: _reps,
            weight: _weight,
            duration: _duration,
            distance: _distance,
            label: _label,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('btn_cancel'),
              style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            readSetValues(
              trackingType: widget.trackingType,
              reps: _reps,
              weight: _weight,
              duration: _duration,
              distance: _distance,
            ),
          ),
          child: Text(tr('btn_save'), style: TextStyle(color: colors.primary1)),
        ),
      ],
    );
  }
}
