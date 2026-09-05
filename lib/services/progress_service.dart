import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/progress_models.dart';
import 'auth_service.dart';
import 'exercise_service.dart';

/// Phase 4 reads: progress figures, personal records and achievements.
///
/// All read-only. Records and unlocks are written by the backend when a
/// session is finished - they are consequences of training, not something the
/// app gets to assert.
class ProgressService {
  ProgressService._();

  static final ProgressService instance = ProgressService._();

  final http.Client _client = http.Client();

  Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) async {
    final token = await AuthService.instance.validAccessToken();
    if (token == null) {
      throw const ApiException('Not signed in', statusCode: 401);
    }

    http.Response response;
    try {
      response = await request(token).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException('Cannot reach the server. Is the backend running?');
    }

    if (response.statusCode == 401) {
      final session = await AuthService.instance.refreshSession();
      if (session == null) {
        throw const ApiException('Session expired', statusCode: 401);
      }
      try {
        response = await request(session.accessToken)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const ApiException(
            'Cannot reach the server. Is the backend running?');
      }
    }

    return response;
  }

  dynamic _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(
      parseErrorMessage(decoded,
          fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// GET /progress/summary - completion, performance, volume, frequency.
  Future<ProgressSummary> summary({DateTime? from, DateTime? to}) async {
    final query = <String, String>{
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
    };

    final response = await _send((token) => _client.get(
          ApiConfig.path('/progress/summary').replace(queryParameters: query),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ProgressSummary.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// GET /progress/exercises/{id} - the best set of each training day.
  Future<ExerciseProgression> exerciseProgression(
    int exerciseId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{
      // The same setting that drives the UI, so a chart's title cannot end up
      // in a different language from the screen around it.
      'language': ExerciseService.currentLanguage,
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
    };

    final response = await _send((token) => _client.get(
          ApiConfig.path('/progress/exercises/$exerciseId')
              .replace(queryParameters: query),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ExerciseProgression.fromJson(
        _decode(response) as Map<String, dynamic>);
  }

  /// GET /progress/activity - completed sets per day, oldest first.
  Future<List<ActivityDay>> recentActivity({int days = 7}) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/progress/activity')
              .replace(queryParameters: {'days': '$days'}),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ((_decode(response) as List?) ?? const [])
        .map((e) => ActivityDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /progress/recent-exercises - what the user has been training.
  Future<List<RecentExercise>> recentExercises({int limit = 4}) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/progress/recent-exercises').replace(
            queryParameters: {
              'limit': '$limit',
              'language': ExerciseService.currentLanguage,
            },
          ),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ((_decode(response) as List?) ?? const [])
        .map((e) => RecentExercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /personal-records - every record the user currently holds.
  Future<List<PersonalBest>> personalBests() async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/personal-records').replace(
            queryParameters: {'language': ExerciseService.currentLanguage},
          ),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ((_decode(response) as List?) ?? const [])
        .map((e) => PersonalBest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /personal-records/{exercise_id} - how one record was built up.
  Future<List<PersonalRecordEntry>> recordHistory(
    int exerciseId, {
    String? recordType,
  }) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/personal-records/$exerciseId').replace(
            queryParameters: {
              if (recordType != null) 'record_type': recordType,
            },
          ),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ((_decode(response) as List?) ?? const [])
        .map((e) => PersonalRecordEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /achievements - the whole catalog, locked entries included.
  Future<List<Achievement>> achievements() async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/achievements'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return ((_decode(response) as List?) ?? const [])
        .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
