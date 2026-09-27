import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/app_locale.dart';
import '../models/exercise_models.dart';

/// Reads the exercise catalog from the Bodify backend.
///
/// These endpoints are public - no token is attached.
class ExerciseService {
  ExerciseService._();

  static final ExerciseService instance = ExerciseService._();

  final http.Client _client = http.Client();

  /// Workout content follows the UI language: pick English and the API returns
  /// the English translations, pick Vietnamese and it returns the Vietnamese
  /// ones.
  static String get currentLanguage => LocaleController.instance.apiLanguage;

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    late http.Response response;
    try {
      final uri = ApiConfig.path(path).replace(queryParameters: query);
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException('Cannot reach the server. Is the backend running?');
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw const ApiException('Unexpected response from the server.');
    }
    throw ApiException(
      parseErrorMessage(decoded, fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  /// GET /exercises
  Future<PagedResult<ExerciseListItem>> listExercises({
    int page = 1,
    int limit = 20,
    String? language,
    String? search,
    String? muscleGroup,
    String? equipment,
    String? experienceLevel,
    String? exerciseType,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'language': language ?? currentLanguage,
      // Only send filters that are actually set: an empty value would be
      // treated as a real filter and match nothing.
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (equipment != null) 'equipment': equipment,
      if (experienceLevel != null) 'experience_level': experienceLevel,
      if (exerciseType != null) 'exercise_type': exerciseType,
    };

    final json = await _get('/exercises', query);
    return PagedResult.fromJson(json, ExerciseListItem.fromJson);
  }

  /// GET /exercises/{id}
  Future<ExerciseDetail> getExercise(
    int exerciseId, {
    String? language,
  }) async {
    final json = await _get(
        '/exercises/$exerciseId', {'language': language ?? currentLanguage});
    return ExerciseDetail.fromJson(json);
  }

  /// GET /exercises/filters
  ///
  /// Returns muscle/equipment labels already translated, so the app never has
  /// to keep its own copy of those names.
  ///
  /// Kept per language for the life of the app: the catalog's muscles and
  /// equipment change with a migration, not between two openings of the
  /// exercise picker, which used to fetch them every time it opened.
  Future<ExerciseFilters> getFilters({String? language}) async {
    final lang = language ?? currentLanguage;
    final cached = _filters[lang];
    if (cached != null) return cached;
    final json = await _get('/exercises/filters', {'language': lang});
    return _filters[lang] = ExerciseFilters.fromJson(json);
  }

  final Map<String, ExerciseFilters> _filters = {};
}
