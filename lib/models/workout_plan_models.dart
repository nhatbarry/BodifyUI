/// Models for the workout planner.
///
/// The backend calls the top-level object a *plan* (`workout_plans`), and its
/// own `schedules` table is the layer that maps a plan's days onto dates. The
/// UI calls the whole thing "lịch tập" because that is what a user is picking
/// between, but the code keeps the backend's vocabulary so the two never drift
/// - `WorkoutPlan` here is `workout_plans` there, nothing else.

import 'progress_models.dart';

/// Strips the time so two DateTimes on the same day compare equal.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// yyyy-MM-dd, the only date format the API accepts or returns.
String apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// One planned set: a target, never something that was performed.
class TargetSet {
  final int id;
  final int setOrder;
  final int? targetReps;
  final double? targetWeightKg;
  final int? targetDurationSeconds;
  final double? targetDistanceM;
  final int? restSeconds;
  final String? notes;

  const TargetSet({
    required this.id,
    required this.setOrder,
    this.targetReps,
    this.targetWeightKg,
    this.targetDurationSeconds,
    this.targetDistanceM,
    this.restSeconds,
    this.notes,
  });

  factory TargetSet.fromJson(Map<String, dynamic> json) => TargetSet(
        id: json['workout_exercise_set_id'] as int,
        setOrder: json['set_order'] as int,
        targetReps: json['target_reps'] as int?,
        // NUMERIC arrives as a string from JSON, not a double.
        targetWeightKg: json['target_weight_kg'] == null
            ? null
            : double.tryParse('${json['target_weight_kg']}'),
        targetDurationSeconds: json['target_duration_seconds'] as int?,
        targetDistanceM: json['target_distance_m'] == null
            ? null
            : double.tryParse('${json['target_distance_m']}'),
        restSeconds: json['rest_seconds'] as int?,
        notes: json['notes'] as String?,
      );
}

/// A catalog exercise placed on a day.
class PlannedExercise {
  final int workoutExerciseId;
  final int exerciseId;
  final int exerciseOrder;
  final String? notes;

  /// Null for the one catalog row with no translation in any language, so the
  /// UI must fall back rather than assume a name is always there.
  final String? name;
  final String? language;

  /// Small variant for list rows; null until the icon is uploaded.
  final String? iconUrl;

  /// Null for the 16 exercises with no thumbnail on file.
  final String? thumbnailUrl;

  /// What the target editor should ask for: reps, seconds or metres.
  final TrackingType trackingType;

  /// The camera algorithm that can score this movement, null if none can.
  final String? aiAlgorithm;

  final List<TargetSet> sets;

  const PlannedExercise({
    required this.workoutExerciseId,
    required this.exerciseId,
    required this.exerciseOrder,
    required this.sets,
    this.notes,
    this.name,
    this.language,
    this.iconUrl,
    this.thumbnailUrl,
    this.trackingType = TrackingType.reps,
    this.aiAlgorithm,
  });

  /// What a row should draw, and the cache identity that goes with it.
  String? get listImageUrl => iconUrl ?? thumbnailUrl;

  String get listImageCacheKey =>
      iconUrl != null ? 'icon-$exerciseId' : 'thumb-$exerciseId';

  factory PlannedExercise.fromJson(Map<String, dynamic> json) => PlannedExercise(
        workoutExerciseId: json['workout_exercise_id'] as int,
        exerciseId: json['exercise_id'] as int,
        exerciseOrder: json['exercise_order'] as int,
        notes: json['notes'] as String?,
        name: json['name'] as String?,
        language: json['language'] as String?,
        iconUrl: json['icon_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        trackingType: TrackingType.parse(json['tracking_type'] as String?),
        aiAlgorithm: json['ai_algorithm'] as String?,
        sets: (json['sets'] as List<dynamic>? ?? const [])
            .map((e) => TargetSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One day's worth of training, as returned for a single date.
class WorkoutDayDetail {
  final int workoutDayId;
  final String name;
  final int dayOrder;
  final bool isRestDay;
  final String? description;
  final List<PlannedExercise> exercises;

  const WorkoutDayDetail({
    required this.workoutDayId,
    required this.name,
    required this.dayOrder,
    required this.isRestDay,
    required this.exercises,
    this.description,
  });

  factory WorkoutDayDetail.fromJson(Map<String, dynamic> json) => WorkoutDayDetail(
        workoutDayId: json['workout_day_id'] as int,
        name: json['name'] as String,
        dayOrder: json['day_order'] as int,
        isRestDay: json['is_rest_day'] as bool,
        description: json['description'] as String?,
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A day as it appears in the plan list - counts only, no exercises.
class WorkoutDaySummary {
  final int workoutDayId;
  final String name;
  final int dayOrder;
  final bool isRestDay;
  final int exerciseCount;

  const WorkoutDaySummary({
    required this.workoutDayId,
    required this.name,
    required this.dayOrder,
    required this.isRestDay,
    required this.exerciseCount,
  });

  factory WorkoutDaySummary.fromJson(Map<String, dynamic> json) => WorkoutDaySummary(
        workoutDayId: json['workout_day_id'] as int,
        name: json['name'] as String,
        dayOrder: json['day_order'] as int,
        isRestDay: json['is_rest_day'] as bool,
        // Two shapes arrive here. `GET /workout-plans` sends a shallow preview
        // with `exercise_count`; the detail responses - including the one
        // `PUT /workout-plans/{id}/active` returns - send the full `exercises`
        // list and no count at all. Casting the missing count straight to int
        // was the "type 'Null' is not a subtype of type 'int'" crash on
        // switching between two plans.
        exerciseCount: json['exercise_count'] as int? ??
            (json['exercises'] as List<dynamic>?)?.length ??
            0,
      );
}

/// A workout plan - "lịch tập" in the UI.
class WorkoutPlan {
  final int planId;
  final String name;
  final String? description;
  final String? goal;
  final int? durationWeeks;
  final String status;

  /// Exactly one of a user's plans is active: the one they are following. The
  /// backend enforces it with a partial unique index, so the app can toggle
  /// freely without clearing the previous one itself.
  final bool isActive;

  final DateTime createdAt;
  final List<WorkoutDaySummary> days;

  const WorkoutPlan({
    required this.planId,
    required this.name,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.days,
    this.description,
    this.goal,
    this.durationWeeks,
  });

  int get plannedDayCount => days.length;

  WorkoutPlan copyWith({String? name, bool? isActive}) => WorkoutPlan(
        planId: planId,
        name: name ?? this.name,
        status: status,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        days: days,
        description: description,
        goal: goal,
        durationWeeks: durationWeeks,
      );

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
        planId: json['plan_id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        goal: json['goal'] as String?,
        durationWeeks: json['duration_weeks'] as int?,
        status: json['status'] as String,
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        days: (json['days'] as List<dynamic>? ?? const [])
            .map((e) => WorkoutDaySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One real date on the calendar, with any weekly rule already expanded by the
/// server. A date that has no entry simply has nothing planned.
class CalendarEntry {
  final DateTime date;
  final int workoutDayId;
  final String title;
  final bool isRestDay;
  final int planId;

  const CalendarEntry({
    required this.date,
    required this.workoutDayId,
    required this.title,
    required this.isRestDay,
    required this.planId,
  });

  factory CalendarEntry.fromJson(Map<String, dynamic> json) => CalendarEntry(
        date: DateTime.parse(json['date'] as String),
        workoutDayId: json['workout_day_id'] as int,
        title: json['title'] as String,
        isRestDay: json['is_rest_day'] as bool,
        planId: json['plan_id'] as int,
      );
}
