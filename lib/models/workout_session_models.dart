/// Models for recorded workouts - what was actually performed.
///
/// The planner (`workout_plan_models.dart`) and this file describe two
/// different things about the same exercise, and the calendar shows them side
/// by side: what you meant to lift, and what you lifted. They are never merged
/// into one object, because a plan keeps changing and a finished session does
/// not.

import 'progress_models.dart';

/// One set as performed. `targetReps` / `targetWeightKg` are the plan's numbers
/// as they stood when the set was recorded - a snapshot, not a live reading, so
/// editing the plan afterwards cannot rewrite them.
class SessionSet {
  final int id;
  final int setOrder;

  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceM;
  final int? restSeconds;
  final bool completed;

  final int? targetReps;
  final double? targetWeightKg;
  final int? targetDurationSeconds;
  final double? targetDistanceM;

  /// Which camera algorithm scored this set, null if it was logged by hand.
  /// A snapshot: the server will not let a correction rewrite it.
  final String? aiAlgorithm;

  /// One score per counted rep - 0, 50 or 100 by how deep the rep went.
  final List<int>? aiRepScores;

  /// The set's score as a percentage of what it could have scored, as the
  /// server computed it. Null when the set was not judged by the camera.
  final double? aiScorePercent;

  const SessionSet({
    required this.id,
    required this.setOrder,
    required this.completed,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceM,
    this.restSeconds,
    this.targetReps,
    this.targetWeightKg,
    this.targetDurationSeconds,
    this.targetDistanceM,
    this.aiAlgorithm,
    this.aiRepScores,
    this.aiScorePercent,
  });

  /// True when the camera recorded this set rather than the user typing it.
  bool get isAiScored => aiRepScores != null && aiRepScores!.isNotEmpty;

  /// True once the user has actually put a number against this set. A set
  /// copied in from the plan and not yet touched has targets but no numbers.
  ///
  /// All four axes count: a Plank is logged with seconds and no reps, a carry
  /// with metres, so checking reps alone would call them untouched forever.
  bool get isLogged =>
      reps != null ||
      weightKg != null ||
      durationSeconds != null ||
      distanceM != null;

  static double? _num(dynamic v) =>
      v == null ? null : double.tryParse('$v');

  /// This set with the performed values replaced - what the workout screen
  /// draws while the write is in flight. Every value is given explicitly
  /// (null clears it), matching what the screen sends; targets and the AI
  /// snapshot are never touched, the server does not let a correction
  /// rewrite them either.
  SessionSet performed({
    int? id,
    required int? reps,
    required double? weightKg,
    required int? durationSeconds,
    required double? distanceM,
    bool completed = true,
  }) =>
      SessionSet(
        id: id ?? this.id,
        setOrder: setOrder,
        completed: completed,
        reps: reps,
        weightKg: weightKg,
        durationSeconds: durationSeconds,
        distanceM: distanceM,
        restSeconds: restSeconds,
        targetReps: targetReps,
        targetWeightKg: targetWeightKg,
        targetDurationSeconds: targetDurationSeconds,
        targetDistanceM: targetDistanceM,
        aiAlgorithm: aiAlgorithm,
        aiRepScores: aiRepScores,
        aiScorePercent: aiScorePercent,
      );

  factory SessionSet.fromJson(Map<String, dynamic> json) => SessionSet(
        id: json['session_set_id'] as int,
        setOrder: json['set_order'] as int,
        reps: json['reps'] as int?,
        // NUMERIC arrives as a string from JSON, not a double.
        weightKg: _num(json['weight_kg']),
        durationSeconds: json['duration_seconds'] as int?,
        distanceM: _num(json['distance_m']),
        restSeconds: json['rest_seconds'] as int?,
        completed: json['completed'] as bool,
        targetReps: json['target_reps'] as int?,
        targetWeightKg: _num(json['target_weight_kg']),
        targetDurationSeconds: json['target_duration_seconds'] as int?,
        targetDistanceM: _num(json['target_distance_m']),
        aiAlgorithm: json['ai_algorithm'] as String?,
        aiRepScores: (json['ai_rep_scores'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        aiScorePercent: _num(json['ai_score_percent']),
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
  /// What the effort is counted in - reps, seconds or metres - so the logging
  /// form asks for the right thing. Weight is orthogonal and applies to all of
  /// them: a Farmer's Carry is metres *and* 40 kg.
  final TrackingType trackingType;

  /// Which camera algorithm can count and score this movement, null if none
  /// can. Read live from the catalog, like [trackingType]: it describes the
  /// exercise, not this performance of it. Decides whether the "AI" tag and
  /// the camera option appear.
  final String? aiAlgorithm;

  final List<SessionSet> sets;

  const SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseOrder,
    required this.sets,
    this.name,
    this.thumbnailUrl,
    this.trackingType = TrackingType.reps,
    this.aiAlgorithm,
  });

  int get loggedSetCount => sets.where((s) => s.isLogged).length;

  SessionExercise withSets(List<SessionSet> next) => SessionExercise(
        id: id,
        exerciseId: exerciseId,
        exerciseOrder: exerciseOrder,
        sets: next,
        name: name,
        thumbnailUrl: thumbnailUrl,
        trackingType: trackingType,
        aiAlgorithm: aiAlgorithm,
      );

  factory SessionExercise.fromJson(Map<String, dynamic> json) => SessionExercise(
        id: json['session_exercise_id'] as int,
        trackingType: TrackingType.parse(json['tracking_type'] as String?),
        exerciseId: json['exercise_id'] as int,
        name: json['exercise_name'] as String?,
        exerciseOrder: json['exercise_order'] as int,
        thumbnailUrl: json['thumbnail_url'] as String?,
        aiAlgorithm: json['ai_algorithm'] as String?,
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

  /// The server's `summaries()`, repeated so the header can move with the
  /// rows before the server answers: every set counts toward the set total,
  /// and volume is sum(reps x weight) over sets that have both.
  factory SessionSummary.of(List<SessionExercise> exercises) {
    var sets = 0, done = 0, reps = 0;
    var volume = 0.0;
    for (final e in exercises) {
      for (final s in e.sets) {
        sets++;
        if (s.completed) done++;
        reps += s.reps ?? 0;
        if (s.reps != null && s.weightKg != null) {
          volume += s.reps! * s.weightKg!;
        }
      }
    }
    return SessionSummary(
      exerciseCount: exercises.length,
      setCount: sets,
      completedSetCount: done,
      totalReps: reps,
      totalVolumeKg: volume,
    );
  }

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

  /// The same session with other exercises; the summary is recomputed from
  /// them rather than carried, so the header never disagrees with the rows.
  WorkoutSession withExercises(List<SessionExercise> next) => WorkoutSession(
        sessionId: sessionId,
        workoutDayId: workoutDayId,
        planName: planName,
        dayName: dayName,
        scheduledDate: scheduledDate,
        startedAt: startedAt,
        completedAt: completedAt,
        status: status,
        durationSeconds: durationSeconds,
        pausedSeconds: pausedSeconds,
        notes: notes,
        summary: SessionSummary.of(next),
        exercises: next,
      );

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
