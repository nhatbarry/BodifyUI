/// Models for recorded workouts - what was actually performed.
///
/// The planner (`workout_plan_models.dart`) and this file describe two
/// different things about the same exercise, and the calendar shows them side
/// by side: what you meant to lift, and what you lifted. They are never merged
/// into one object, because a plan keeps changing and a finished session does
/// not.

/// One set as performed. `targetReps` / `targetWeightKg` are the plan's numbers
/// as they stood when the set was recorded - a snapshot, not a live reading, so
/// editing the plan afterwards cannot rewrite them.
class SessionSet {
  final int id;
  final int setOrder;

  final int? reps;
  final double? weightKg;
  final int? restSeconds;
  final bool completed;

  final int? targetReps;
  final double? targetWeightKg;

  const SessionSet({
    required this.id,
    required this.setOrder,
    required this.completed,
    this.reps,
    this.weightKg,
    this.restSeconds,
    this.targetReps,
    this.targetWeightKg,
  });

  /// True once the user has actually put a number against this set. A set
  /// copied in from the plan and not yet touched has targets but no reps.
  bool get isLogged => reps != null || weightKg != null;

  static double? _num(dynamic v) =>
      v == null ? null : double.tryParse('$v');

  factory SessionSet.fromJson(Map<String, dynamic> json) => SessionSet(
        id: json['session_set_id'] as int,
        setOrder: json['set_order'] as int,
        reps: json['reps'] as int?,
        // NUMERIC arrives as a string from JSON, not a double.
        weightKg: _num(json['weight_kg']),
        restSeconds: json['rest_seconds'] as int?,
        completed: json['completed'] as bool,
        targetReps: json['target_reps'] as int?,
        targetWeightKg: _num(json['target_weight_kg']),
      );
}

/// One exercise as performed. `name` is the snapshot the backend stored when
/// the exercise was recorded, so history keeps reading the way it read then.
class SessionExercise {
  final int id;
  final int exerciseId;
  final String? name;
  final int exerciseOrder;
  final String? thumbnailUrl;
  final List<SessionSet> sets;

  const SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseOrder,
    required this.sets,
    this.name,
    this.thumbnailUrl,
  });

  int get loggedSetCount => sets.where((s) => s.isLogged).length;

  factory SessionExercise.fromJson(Map<String, dynamic> json) => SessionExercise(
        id: json['session_exercise_id'] as int,
        exerciseId: json['exercise_id'] as int,
        name: json['exercise_name'] as String?,
        exerciseOrder: json['exercise_order'] as int,
        thumbnailUrl: json['thumbnail_url'] as String?,
        sets: (json['sets'] as List<dynamic>? ?? const [])
            .map((e) => SessionSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SessionSummary {
  final int exerciseCount;
  final int setCount;
  final int completedSetCount;
  final int totalReps;
  final double totalVolumeKg;

  const SessionSummary({
    required this.exerciseCount,
    required this.setCount,
    required this.completedSetCount,
    required this.totalReps,
    required this.totalVolumeKg,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        exerciseCount: json['exercise_count'] as int,
        setCount: json['set_count'] as int,
        completedSetCount: json['completed_set_count'] as int,
        totalReps: json['total_reps'] as int,
        totalVolumeKg:
            double.tryParse('${json['total_volume_kg']}') ?? 0,
      );
}

/// A recorded workout. `exercises` is empty in list responses, which carry
/// totals only - the history screen shows "12 sets", not every set.
class WorkoutSession {
  final int sessionId;
  final int? workoutDayId;
  final String? planName;
  final String? dayName;
  final DateTime? scheduledDate;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;
  /// Training time so far with pauses already subtracted, straight from the
  /// server. The screen ticks its own second counter on top of this rather
  /// than computing elapsed time itself, so a phone with a skewed clock or an
  /// app that was backgrounded still shows the server's figure.
  final int? durationSeconds;
  final int pausedSeconds;
  final String? notes;
  final SessionSummary summary;
  final List<SessionExercise> exercises;

  const WorkoutSession({
    required this.sessionId,
    required this.startedAt,
    required this.status,
    required this.summary,
    required this.exercises,
    this.workoutDayId,
    this.planName,
    this.dayName,
    this.scheduledDate,
    this.completedAt,
    this.durationSeconds,
    this.pausedSeconds = 0,
    this.notes,
  });

  bool get isInProgress => status == 'in_progress';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';

  /// Still the user's current workout. Paused counts: the clock has stopped,
  /// the workout has not.
  bool get isActive => isInProgress || isPaused;

  /// The performed exercise for a catalog exercise, if it was recorded.
  /// Matched on exercise_id because the calendar starts from the *plan* and
  /// asks "did this get done", not the other way round.
  SessionExercise? forExercise(int exerciseId) {
    for (final e in exercises) {
      if (e.exerciseId == exerciseId) return e;
    }
    return null;
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        sessionId: json['session_id'] as int,
        workoutDayId: json['workout_day_id'] as int?,
        planName: json['plan_name'] as String?,
        dayName: json['day_name'] as String?,
        scheduledDate: json['scheduled_date'] == null
            ? null
            : DateTime.parse(json['scheduled_date'] as String),
        startedAt: DateTime.parse(json['started_at'] as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
        status: json['status'] as String,
        durationSeconds: json['duration_seconds'] as int?,
        pausedSeconds: json['paused_seconds'] as int? ?? 0,
        notes: json['notes'] as String?,
        summary: SessionSummary.fromJson(
            json['summary'] as Map<String, dynamic>),
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}


/// Totals across a stretch of completed sessions, aggregated by the server.
///
/// The client never adds these up itself: doing so would mean pulling every
/// set of every session to render one summary line.
class HistoryTotals {
  final int sessionCount;
  final int totalDurationSeconds;
  final int totalSets;
  final int totalReps;
  final double totalVolumeKg;

  const HistoryTotals({
    required this.sessionCount,
    required this.totalDurationSeconds,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolumeKg,
  });

  factory HistoryTotals.fromJson(Map<String, dynamic> json) => HistoryTotals(
        sessionCount: json['session_count'] as int,
        totalDurationSeconds: json['total_duration_seconds'] as int,
        totalSets: json['total_sets'] as int,
        totalReps: json['total_reps'] as int,
        totalVolumeKg: double.tryParse('${json['total_volume_kg']}') ?? 0,
      );
}

class WorkoutHistory {
  final HistoryTotals totals;
  final List<WorkoutSession> items;

  const WorkoutHistory({required this.totals, required this.items});

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) => WorkoutHistory(
        totals: HistoryTotals.fromJson(json['totals'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
