/// Mirrors the backend's Page[T].
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int total;

  const PagedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  bool get hasMore => page * limit < total;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    return PagedResult(
      items: (json['items'] as List<dynamic>)
          .map((e) => parseItem(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
    );
  }
}

/// One row in the explorer list.
class ExerciseListItem {
  final int exerciseId;
  final String? name;
  final String? language;
  final String? thumbnailUrl;
  final String? exerciseType;
  final String? mechanics;
  final String? forceType;
  final String? experienceLevel;

  const ExerciseListItem({
    required this.exerciseId,
    this.name,
    this.language,
    this.thumbnailUrl,
    this.exerciseType,
    this.mechanics,
    this.forceType,
    this.experienceLevel,
  });

  factory ExerciseListItem.fromJson(Map<String, dynamic> json) => ExerciseListItem(
        exerciseId: json['exercise_id'] as int,
        name: json['name'] as String?,
        language: json['language'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        exerciseType: json['exercise_type'] as String?,
        mechanics: json['mechanics'] as String?,
        forceType: json['force_type'] as String?,
        experienceLevel: json['experience_level'] as String?,
      );
}

class ExerciseMuscle {
  final int id;
  final String name;
  final String role;

  const ExerciseMuscle({required this.id, required this.name, required this.role});

  factory ExerciseMuscle.fromJson(Map<String, dynamic> json) => ExerciseMuscle(
        id: json['id'] as int,
        name: json['name'] as String,
        role: json['role'] as String,
      );
}

class ExerciseEquipment {
  final int id;
  final String name;

  const ExerciseEquipment({required this.id, required this.name});

  factory ExerciseEquipment.fromJson(Map<String, dynamic> json) => ExerciseEquipment(
        id: json['id'] as int,
        name: json['name'] as String,
      );
}

class ExerciseDetail {
  final int exerciseId;
  final String? name;
  final String? language;
  final String? overview;
  final String? instructions;
  final String? tips;
  final String? exerciseType;
  final String? mechanics;
  final String? forceType;
  final String? experienceLevel;
  final List<ExerciseMuscle> muscles;
  final List<ExerciseEquipment> equipment;
  final String? thumbnailUrl;
  final String? videoUrl;

  const ExerciseDetail({
    required this.exerciseId,
    this.name,
    this.language,
    this.overview,
    this.instructions,
    this.tips,
    this.exerciseType,
    this.mechanics,
    this.forceType,
    this.experienceLevel,
    this.muscles = const [],
    this.equipment = const [],
    this.thumbnailUrl,
    this.videoUrl,
  });

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    final media = (json['media'] as Map<String, dynamic>?) ?? const {};
    return ExerciseDetail(
      exerciseId: json['exercise_id'] as int,
      name: json['name'] as String?,
      language: json['language'] as String?,
      overview: json['overview'] as String?,
      instructions: json['instructions'] as String?,
      tips: json['tips'] as String?,
      exerciseType: json['exercise_type'] as String?,
      mechanics: json['mechanics'] as String?,
      forceType: json['force_type'] as String?,
      experienceLevel: json['experience_level'] as String?,
      muscles: ((json['muscles'] as List<dynamic>?) ?? [])
          .map((e) => ExerciseMuscle.fromJson(e as Map<String, dynamic>))
          .toList(),
      equipment: ((json['equipment'] as List<dynamic>?) ?? [])
          .map((e) => ExerciseEquipment.fromJson(e as Map<String, dynamic>))
          .toList(),
      thumbnailUrl: media['thumbnail_url'] as String?,
      videoUrl: media['video_url'] as String?,
    );
  }
}

/// Mirrors GET /exercises/filters.
class FilterOption {
  final int id;
  final String name;

  const FilterOption({required this.id, required this.name});

  factory FilterOption.fromJson(Map<String, dynamic> json) => FilterOption(
        id: json['id'] as int,
        name: json['name'] as String,
      );
}

class ExerciseFilters {
  final List<FilterOption> muscleGroups;
  final List<FilterOption> equipment;
  final List<String> experienceLevels;
  final List<String> exerciseTypes;

  const ExerciseFilters({
    this.muscleGroups = const [],
    this.equipment = const [],
    this.experienceLevels = const [],
    this.exerciseTypes = const [],
  });

  factory ExerciseFilters.fromJson(Map<String, dynamic> json) => ExerciseFilters(
        muscleGroups: ((json['muscle_groups'] as List<dynamic>?) ?? [])
            .map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        equipment: ((json['equipment'] as List<dynamic>?) ?? [])
            .map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        experienceLevels:
            ((json['experience_levels'] as List<dynamic>?) ?? []).cast<String>(),
        exerciseTypes:
            ((json['exercise_types'] as List<dynamic>?) ?? []).cast<String>(),
      );
}
