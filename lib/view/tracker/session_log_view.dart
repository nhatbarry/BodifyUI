import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../common_widget/set_input_fields.dart';
import '../../models/progress_models.dart';
import '../../models/workout_session_models.dart';
import '../../services/workout_session_service.dart';

/// Planned vs actual, told apart by colour instead of a "KH"/"TT" prefix.
/// Green matches the completed-checkmark colour already used on this screen.
const _kPlannedColor = Color(0xFFF2994A);
const _kActualColor = Color(0xFF27AE60);

/// Recording what was actually lifted, one exercise at a time.
///
/// The rows arrive already laid out: starting a session copies the planned
/// sets in with their targets, so this screen is filling in blanks rather than
/// building a list. Each row shows the target it is aiming at, which is the
/// number the user is trying to beat or match.
class SessionLogView extends StatefulWidget {
  final SessionExercise exercise;

  /// The session the exercise belongs to. Needed because a finished session
  /// refuses new sets until it is reopened, and this screen offers to do that
  /// rather than letting the tap fail.
  final WorkoutSession session;

  const SessionLogView(
      {super.key, required this.exercise, required this.session});

  @override
  State<SessionLogView> createState() => _SessionLogViewState();
}

class _SessionLogViewState extends State<SessionLogView> {
  late final List<SessionSet> _sets =
      List<SessionSet>.from(widget.exercise.sets);
  late bool _sessionActive = widget.session.isActive;
  bool _busy = false;
  bool _changed = false;

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }

  /// The last set before this one that actually has numbers in it. Untouched
  /// sets are skipped - prefilling from a blank would just clear the form.
  SessionSet? _previousLogged(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_sets[i].isLogged) return _sets[i];
    }
    return null;
  }

  Future<void> _record(int index) async {
    final target = _sets[index];
    final values = await showDialog<SetValues>(
      context: context,
      builder: (_) => _LogDialog(
        title: tr('title_set_number').replaceFirst('{n}', '${target.setOrder}'),
        trackingType: widget.exercise.trackingType,
        from: target,
        previous: _previousLogged(index),
      ),
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      final updated = await WorkoutSessionService.instance.recordSet(
        target.id,
        reps: values.reps,
        weightKg: values.weightKg,
        durationSeconds: values.durationSeconds,
        distanceM: values.distanceM,
        completed: true,
        // Clearing only the axes this exercise actually uses. A Plank has no
        // reps to clear, and sending null for one would be a correction the
        // user never made.
        clearReps: values.reps == null &&
            SetFieldSpec.of(widget.exercise.trackingType).reps,
        clearWeight: values.weightKg == null,
        clearDuration: values.durationSeconds == null &&
            SetFieldSpec.of(widget.exercise.trackingType).duration,
        clearDistance: values.distanceM == null &&
            SetFieldSpec.of(widget.exercise.trackingType).distance,
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

  /// Reopens the session if it has been finished, asking first.
  ///
  /// "Finish" is the user saying they were done, not a lock: doing one more
  /// set afterwards is ordinary, and the alternative - a second session - would
  /// read in the history as two workouts on the same afternoon. Returns false
  /// if the user backed out or the reopen failed.
  Future<bool> _ensureSessionActive() async {
    if (_sessionActive) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(tr('title_reopen_session'),
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(tr('msg_reopen_session'),
            style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('btn_cancel'),
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('btn_train_again'),
                style: TextStyle(color: context.colors.primary1)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    setState(() => _busy = true);
    try {
      await WorkoutSessionService.instance
          .reopenSession(widget.session.sessionId);
      if (!mounted) return false;
      setState(() {
        _sessionActive = true;
        _busy = false;
        _changed = true;
      });
      return true;
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
      return false;
    }
  }

  Future<void> _addExtraSet() async {
    if (!await _ensureSessionActive()) return;
    if (!mounted) return;
    final last = _sets.isEmpty ? null : _sets.last;
    final values = await showDialog<SetValues>(
      context: context,
      builder: (_) => _LogDialog(
        title: tr('btn_add_set'),
        trackingType: widget.exercise.trackingType,
        from: last,
        showTarget: false,
      ),
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      final created = await WorkoutSessionService.instance.addSet(
        widget.exercise.id,
        reps: values.reps,
        weightKg: values.weightKg,
        durationSeconds: values.durationSeconds,
        distanceM: values.distanceM,
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
                        tr('label_set_progress')
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
                        child: Text(tr('msg_no_target_sets'),
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
                      label: Text(tr('btn_add_set'),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logged = set.isLogged;

    // Both lines are built from whichever axes the set actually carries, so a
    // Plank reads "60 giây" rather than "— × —" and a carry reads "20m × 40kg".
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
      if (!logged) return tr('label_not_logged');
      final text = formatTarget(
        reps: set.reps,
        weightKg: set.weightKg,
        durationSeconds: set.durationSeconds,
        distanceM: set.distanceM,
      );
      return text.isEmpty ? '—' : text;
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
                      Text(target(),
                          style: const TextStyle(
                              color: _kPlannedColor, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(actual(),
                          style: TextStyle(
                              color: logged
                                  ? _kActualColor
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

// Replaced by SetValues from set_input_fields.dart, which carries every axis.

class _LogDialog extends StatefulWidget {
  final String title;
  final TrackingType trackingType;
  final SessionSet? from;

  /// The set logged just before this one, if any. Sets in a row usually
  /// repeat, and after the first one the number the user is about to type is
  /// far more likely to be "the same as last set" than "whatever the plan said
  /// weeks ago".
  final SessionSet? previous;

  /// An extra set has no plan of its own. Prefilling from the previous set is
  /// helpful; showing that set's target as if it were this one's is not.
  final bool showTarget;

  const _LogDialog({
    required this.title,
    required this.trackingType,
    this.from,
    this.previous,
    this.showTarget = true,
  });

  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  // Prefilled from whatever the set already holds - a performed value if there
  // is one, otherwise the target. Most sets are done as planned, so the common
  // case is one tap.
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

  static String _pre(double? v) => v == null ? '' : _trim(v);

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
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
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
