import '../core/app_strings.dart';

/// Phase 4: progress figures, personal records and achievements.

/// Translates a unit that arrived from the database.
///
/// `achievements.requirement_unit` and `personal_records.unit` are stored in
/// English because the database has no business holding UI language - the same
/// reason `icon_url` is null and the client maps `code` to an asset. Anything
/// unrecognised falls through unchanged: `kg` needs no translation, and a unit
/// the app has not met yet is better shown raw than swallowed.
String translateUnit(String unit) {
  const keys = {
    'workout': 'unit_workout',
    'day': 'unit_day',
    'seconds': 'unit_seconds',
    'reps': 'unit_reps',
    'record': 'unit_record',
    'plan': 'unit_plan',
    'm': 'unit_m',
  };
  final key = keys[unit];
  return key == null ? unit : tr(key);
}

/// How an exercise is measured, mirrored from `exercises.tracking_type`.
///
/// Weight is deliberately not one of these. A Farmer's Carry is metres *and*
/// 40 kg; a Weighted Pull Up Hang is seconds *and* 20 kg. This says what the
/// effort is counted in, and the weight field applies to all of them.
enum TrackingType {
  reps,
  duration,
  distance,
  repsDuration;

  static TrackingType parse(String? raw) {
    switch (raw) {
      case 'duration':
        return TrackingType.duration;
      case 'distance':
        return TrackingType.distance;
      case 'reps_duration':
        return TrackingType.repsDuration;
      default:
        return TrackingType.reps;
    }
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class ProgressSummary {
  final int plannedSets;
  final int completedPlannedSets;

  /// Null rather than zero when there is nothing to measure. Nobody completed
  /// 0% of a plan they never had, and a 0 on screen reads as failure instead
  /// of absence.
  final double? completionPercent;
  final double? performancePercent;

  final double totalVolumeKg;
  final int sessionCount;
  final double? workoutsPerWeek;
  final int? daysSpan;

  const ProgressSummary({
    required this.plannedSets,
    required this.completedPlannedSets,
    required this.completionPercent,
    required this.performancePercent,
    required this.totalVolumeKg,
    required this.sessionCount,
    required this.workoutsPerWeek,
    required this.daysSpan,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) => ProgressSummary(
        plannedSets: json['planned_sets'] as int? ?? 0,
        completedPlannedSets: json['completed_planned_sets'] as int? ?? 0,
        completionPercent: _toDouble(json['completion_percent']),
        performancePercent: _toDouble(json['performance_percent']),
        totalVolumeKg: _toDouble(json['total_volume_kg']) ?? 0,
        sessionCount: json['session_count'] as int? ?? 0,
        workoutsPerWeek: _toDouble(json['workouts_per_week']),
        daysSpan: json['days_span'] as int?,
      );
}

/// One training day for one exercise - the best set of that day.
class ProgressPoint {
  final DateTime day;
  final double? bestWeightKg;
  final int? bestReps;
  final int? bestDurationSeconds;
  final double? bestDistanceM;
  final double volumeKg;

  const ProgressPoint({
    required this.day,
    required this.bestWeightKg,
    required this.bestReps,
    required this.bestDurationSeconds,
    required this.bestDistanceM,
    required this.volumeKg,
  });

  factory ProgressPoint.fromJson(Map<String, dynamic> json) => ProgressPoint(
        day: DateTime.parse(json['day'] as String),
        bestWeightKg: _toDouble(json['best_weight_kg']),
        bestReps: json['best_reps'] as int?,
        bestDurationSeconds: json['best_duration_seconds'] as int?,
        bestDistanceM: _toDouble(json['best_distance_m']),
        volumeKg: _toDouble(json['volume_kg']) ?? 0,
      );
}

class ExerciseProgression {
  final int exerciseId;
  final String? name;
  final TrackingType trackingType;
  final List<ProgressPoint> points;

  const ExerciseProgression({
    required this.exerciseId,
    required this.name,
    required this.trackingType,
    required this.points,
  });

  factory ExerciseProgression.fromJson(Map<String, dynamic> json) =>
      ExerciseProgression(
        exerciseId: json['exercise_id'] as int,
        name: json['name'] as String?,
        trackingType: TrackingType.parse(json['tracking_type'] as String?),
        points: ((json['points'] as List?) ?? const [])
            .map((e) => ProgressPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// The series worth plotting for this exercise.
  ///
  /// Plotting all four would give three flat lines and one real one, which is
  /// why the API sends `tracking_type` alongside the points.
  List<double?> get series => switch (trackingType) {
        TrackingType.duration =>
          points.map((p) => p.bestDurationSeconds?.toDouble()).toList(),
        TrackingType.distance => points.map((p) => p.bestDistanceM).toList(),
        _ => points.map((p) => p.bestWeightKg).toList(),
      };
}

/// One day of the home screen's activity strip.
class ActivityDay {
  final DateTime day;
  final int completedSets;
  final double volumeKg;
  final int sessionCount;

  const ActivityDay({
    required this.day,
    required this.completedSets,
    required this.volumeKg,
    required this.sessionCount,
  });

  factory ActivityDay.fromJson(Map<String, dynamic> json) => ActivityDay(
        day: DateTime.parse(json['day'] as String),
        completedSets: json['completed_sets'] as int? ?? 0,
        volumeKg: _toDouble(json['volume_kg']) ?? 0,
        sessionCount: json['session_count'] as int? ?? 0,
      );

  bool get trained => sessionCount > 0;
}

/// One exercise the user trained recently, with that day's numbers.
class RecentExercise {
  final int exerciseId;
  final String? name;
  final TrackingType trackingType;
  final String? thumbnailUrl;

  final DateTime day;
  final int sessionId;

  final int setCount;
  final int totalReps;
  final double totalVolumeKg;
  final int? bestDurationSeconds;
  final double? bestDistanceM;

  const RecentExercise({
    required this.exerciseId,
    required this.name,
    required this.trackingType,
    required this.thumbnailUrl,
    required this.day,
    required this.sessionId,
    required this.setCount,
    required this.totalReps,
    required this.totalVolumeKg,
    required this.bestDurationSeconds,
    required this.bestDistanceM,
  });

  factory RecentExercise.fromJson(Map<String, dynamic> json) => RecentExercise(
        exerciseId: json['exercise_id'] as int,
        name: json['name'] as String?,
        trackingType: TrackingType.parse(json['tracking_type'] as String?),
        thumbnailUrl: json['thumbnail_url'] as String?,
        day: DateTime.parse(json['day'] as String),
        sessionId: json['session_id'] as int,
        setCount: json['set_count'] as int? ?? 0,
        totalReps: json['total_reps'] as int? ?? 0,
        totalVolumeKg: _toDouble(json['total_volume_kg']) ?? 0,
        bestDurationSeconds: json['best_duration_seconds'] as int?,
        bestDistanceM: _toDouble(json['best_distance_m']),
      );

  /// The one line of numbers worth showing, chosen by how the exercise is
  /// measured. A Plank's volume is always zero, and a carry's reps are too -
  /// printing them anyway would make every timed row read as "0kg".
  String get summary {
    String trim(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    final sets = '$setCount ${tr('label_sets')}';

    switch (trackingType) {
      case TrackingType.duration:
        if (bestDurationSeconds == null) return sets;
        return '$sets · $bestDurationSeconds ${tr('unit_seconds')}';
      case TrackingType.distance:
        if (bestDistanceM == null) return sets;
        return '$sets · ${trim(bestDistanceM!)}m';
      default:
        final volume =
            totalVolumeKg > 0 ? ' · ${trim(totalVolumeKg)}kg' : '';
        return '$sets · $totalReps ${tr('label_reps')}$volume';
    }
  }
}

class PersonalBest {
  final int exerciseId;
  final String? name;
  final String recordType;
  final double value;
  final String unit;
  final DateTime achievedAt;

  const PersonalBest({
    required this.exerciseId,
    required this.name,
    required this.recordType,
    required this.value,
    required this.unit,
    required this.achievedAt,
  });

  factory PersonalBest.fromJson(Map<String, dynamic> json) => PersonalBest(
        exerciseId: json['exercise_id'] as int,
        name: json['name'] as String?,
        recordType: json['record_type'] as String,
        value: _toDouble(json['value']) ?? 0,
        unit: json['unit'] as String,
        achievedAt: DateTime.parse(json['achieved_at'] as String),
      );
}

/// A point on one record's history: 40 -> 45 -> 50 kg.
class PersonalRecordEntry {
  final int prId;
  final int exerciseId;
  final String recordType;
  final double value;
  final String unit;
  final DateTime achievedAt;

  const PersonalRecordEntry({
    required this.prId,
    required this.exerciseId,
    required this.recordType,
    required this.value,
    required this.unit,
    required this.achievedAt,
  });

  factory PersonalRecordEntry.fromJson(Map<String, dynamic> json) =>
      PersonalRecordEntry(
        prId: json['pr_id'] as int,
        exerciseId: json['exercise_id'] as int,
        recordType: json['record_type'] as String,
        value: _toDouble(json['value']) ?? 0,
        unit: json['unit'] as String,
        achievedAt: DateTime.parse(json['achieved_at'] as String),
      );
}

class Achievement {
  final int achievementId;
  final String code;
  final String name;
  final String? description;

  final String achievementType;
  final double requirementValue;
  final String requirementUnit;
  final int? exerciseId;

  final bool unlocked;
  final DateTime? achievedAt;

  /// Where the user stands now, in the same unit as [requirementValue].
  /// Present for locked entries too - a badge you can see yourself
  /// approaching is the reason to come back.
  final double? currentValue;

  const Achievement({
    required this.achievementId,
    required this.code,
    required this.name,
    required this.description,
    required this.achievementType,
    required this.requirementValue,
    required this.requirementUnit,
    required this.exerciseId,
    required this.unlocked,
    required this.achievedAt,
    required this.currentValue,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        achievementId: json['achievement_id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        achievementType: json['achievement_type'] as String,
        requirementValue: _toDouble(json['requirement_value']) ?? 0,
        requirementUnit: json['requirement_unit'] as String,
        exerciseId: json['exercise_id'] as int?,
        unlocked: json['unlocked'] as bool? ?? false,
        achievedAt: json['achieved_at'] == null
            ? null
            : DateTime.parse(json['achieved_at'] as String),
        currentValue: _toDouble(json['current_value']),
      );

  /// 0..1, for the bar under a locked badge.
  double get progress {
    if (unlocked) return 1;
    if (currentValue == null || requirementValue <= 0) return 0;
    final ratio = currentValue! / requirementValue;
    return ratio.clamp(0, 1).toDouble();
  }

  /// The bundled icon for this badge.
  ///
  /// Mapped from `code` rather than read from `icon_url`: the icons ship in
  /// the app bundle, and putting an asset path in the database would make
  /// renaming a file a migration. PLANK_60 and PLANK_120 share one icon and
  /// are shown as tiers of the same badge.
  String get iconAsset {
    const assets = {
      'WORKOUT_FIRST': 'runner.png',
      'WORKOUT_7': 'six-pack.png',
      'WORKOUT_10': 'medal-of-honor.png',
      'STREAK_7': 'faster.png',
      'VOLUME_10000': 'bicep.png',
      'PLANK_60': 'insignia.png',
      'PLANK_120': 'insignia.png',
      'PR_FIRST': 'trophy.png',
      'PLAN_COMPLETE': 'goal.png',
    };
    return 'assets/img/achievements/${assets[code] ?? 'trophy.png'}';
  }
}
