import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/app_locale.dart';
import '../models/workout_plan_models.dart';
import 'auth_service.dart';

/// The workout planner API.
///
/// Everything here is behind auth. The backend takes user_id from the token,
/// so the app never sends it and cannot reach another user's plan - a plan
/// that is not yours answers 404, the same as one that does not exist.
class WorkoutPlanService {
  WorkoutPlanService._();

  static final WorkoutPlanService instance = WorkoutPlanService._();

  final http.Client _client = http.Client();

  /// Exercise names follow the UI language, exactly as the explorer does.
  static String get _language => LocaleController.instance.apiLanguage;

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

    // An expired access token is the common case; refresh once and retry
    // rather than bouncing the user out to the login screen.
    if (response.statusCode == 401) {
      final session = await AuthService.instance.refreshSession();
      if (session == null) {
        throw const ApiException('Session expired', statusCode: 401);
      }
      try {
        response = await request(session.accessToken)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const ApiException('Cannot reach the server. Is the backend running?');
      }
    }

    return response;
  }

  dynamic _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(
      parseErrorMessage(decoded, fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Map<String, String> _authJson(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // ── Plans ────────────────────────────────────────────────────────────────

  /// GET /workout-plans - shallow: day names and counts, no exercises.
  Future<List<WorkoutPlan>> listPlans() async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/workout-plans')
              .replace(queryParameters: {'limit': '100'}),
          headers: {'Authorization': 'Bearer $token'},
        ));

    final json = _decode(response) as Map<String, dynamic>;
    return (json['items'] as List<dynamic>)
        .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /workout-plans
  Future<WorkoutPlan> createPlan(String name) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/workout-plans'),
          headers: _authJson(token),
          body: jsonEncode({'name': name}),
        ));
    return WorkoutPlan.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /workout-plans/{id}/active
  ///
  /// Activating one plan deactivates whichever was active before - the server
  /// does both in a single transaction, so the app does not have to.
  Future<WorkoutPlan> setActive(int planId, bool isActive) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-plans/$planId/active'),
          headers: _authJson(token),
          body: jsonEncode({'is_active': isActive}),
        ));
    return WorkoutPlan.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /workout-plans/{id} - rename, or archive with status.
  Future<WorkoutPlan> renamePlan(int planId, String name) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-plans/$planId'),
          headers: _authJson(token),
          body: jsonEncode({'name': name}),
        ));
    return WorkoutPlan.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /workout-plans/{id}
  ///
  /// Permanent, and it cascades to every day, exercise, target set and
  /// schedule underneath. There is no undo, so callers must confirm first.
  Future<void> deletePlan(int planId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/workout-plans/$planId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode != 204) _decode(response);
  }

  // ── One plan's calendar ──────────────────────────────────────────────────

  /// GET /schedules/calendar?plan_id=&from=&to=
  ///
  /// Only dates that actually have something planned come back, so a date
  /// missing from the result means "nothing scheduled", while one present with
  /// isRestDay means a rest was planned. The two are different states.
  Future<List<CalendarEntry>> calendar({
    required int planId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/schedules/calendar').replace(queryParameters: {
            'plan_id': '$planId',
            'from': apiDate(from),
            'to': apiDate(to),
          }),
          headers: {'Authorization': 'Bearer $token'},
        ));

    final json = _decode(response) as Map<String, dynamic>;
    return (json['items'] as List<dynamic>)
        .map((e) => CalendarEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /workout-plans/{id}/dates/{date} - null when the date is empty.
  Future<WorkoutDayDetail?> dayForDate(int planId, DateTime date) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/workout-plans/$planId/dates/${apiDate(date)}')
              .replace(queryParameters: {'language': _language}),
          headers: {'Authorization': 'Bearer $token'},
        ));

    final decoded = _decode(response);
    if (decoded == null) return null;
    return WorkoutDayDetail.fromJson(decoded as Map<String, dynamic>);
  }

  /// PUT /workout-plans/{id}/dates/{date}/exercises
  ///
  /// Sends the complete list for that date, in display order. This is what the
  /// picker's ticks mean: anything left out is removed, and an empty list
  /// clears the date entirely (the response is then null).
  ///
  /// Exercises that stay keep their rows on the server, so their target sets
  /// survive a trip through the picker.
  Future<WorkoutDayDetail?> setDateExercises(
    int planId,
    DateTime date,
    List<int> exerciseIds,
  ) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-plans/$planId/dates/${apiDate(date)}/exercises')
              .replace(queryParameters: {'language': _language}),
          headers: _authJson(token),
          body: jsonEncode({'exercise_ids': exerciseIds}),
        ));

    final decoded = _decode(response);
    if (decoded == null) return null;
    return WorkoutDayDetail.fromJson(decoded as Map<String, dynamic>);
  }

  /// PUT /workout-days/{id}/exercises/reorder
  ///
  /// Sends every exercise on the day, not just the ones that moved: the server
  /// rejects a partial list, because the rows left out would keep positions
  /// that collide with the ones being moved. One request, one transaction -
  /// which is also the only way the deferred unique constraint tolerates the
  /// duplicate position that exists mid-swap.
  Future<WorkoutDayDetail> reorderDayExercises(
    int workoutDayId,
    List<int> workoutExerciseIdsInOrder,
  ) async {
    final items = [
      for (var i = 0; i < workoutExerciseIdsInOrder.length; i++)
        {
          'workout_exercise_id': workoutExerciseIdsInOrder[i],
          'exercise_order': i + 1,
        }
    ];
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-days/$workoutDayId/exercises/reorder')
              .replace(queryParameters: {'language': _language}),
          headers: _authJson(token),
          body: jsonEncode({'items': items}),
        ));
    return WorkoutDayDetail.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /workout-exercises/{id}/sets/reorder - same whole-list rule.
  Future<PlannedExercise> reorderSets(
    int workoutExerciseId,
    List<int> setIdsInOrder,
  ) async {
    final items = [
      for (var i = 0; i < setIdsInOrder.length; i++)
        {'workout_exercise_set_id': setIdsInOrder[i], 'set_order': i + 1}
    ];
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-exercises/$workoutExerciseId/sets/reorder')
              .replace(queryParameters: {'language': _language}),
          headers: _authJson(token),
          body: jsonEncode({'items': items}),
        ));
    return PlannedExercise.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /workout-plans/{id}/dates/{date}/rest
  ///
  /// Ticking an empty date creates the day; unticking removes it again, so a
  /// date never ends up as a day with no exercises and no meaning. Answers
  /// null when the date is left with nothing on it.
  Future<WorkoutDayDetail?> setDateRestDay(
    int planId,
    DateTime date,
    bool isRestDay,
  ) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-plans/$planId/dates/${apiDate(date)}/rest'),
          headers: _authJson(token),
          body: jsonEncode({'is_rest_day': isRestDay}),
        ));
    final json = _decode(response);
    return json == null
        ? null
        : WorkoutDayDetail.fromJson(json as Map<String, dynamic>);
  }

  // ── Target sets ──────────────────────────────────────────────────────────

  /// POST /workout-exercises/{id}/sets - appends one set.
  Future<TargetSet> addSet(
    int workoutExerciseId, {
    int? targetReps,
    double? targetWeightKg,
    int? targetDurationSeconds,
    double? targetDistanceM,
    int? restSeconds,
  }) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/workout-exercises/$workoutExerciseId/sets'),
          headers: _authJson(token),
          body: jsonEncode({
            if (targetReps != null) 'target_reps': targetReps,
            if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
            if (targetDurationSeconds != null)
              'target_duration_seconds': targetDurationSeconds,
            if (targetDistanceM != null) 'target_distance_m': targetDistanceM,
            if (restSeconds != null) 'rest_seconds': restSeconds,
          }),
        ));
    return TargetSet.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /workout-exercise-sets/{id}
  ///
  /// Omitted keys keep their value; an explicit null clears one. `clearWeight`
  /// exists because Dart cannot tell "not passed" from "passed as null".
  Future<TargetSet> updateSet(
    int setId, {
    int? targetReps,
    double? targetWeightKg,
    int? targetDurationSeconds,
    double? targetDistanceM,
    int? restSeconds,
    bool clearWeight = false,
    bool clearDuration = false,
    bool clearDistance = false,
    bool clearRest = false,
  }) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/workout-exercise-sets/$setId'),
          headers: _authJson(token),
          body: jsonEncode({
            if (targetReps != null) 'target_reps': targetReps,
            if (clearWeight) 'target_weight_kg': null
            else if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
            if (clearDuration) 'target_duration_seconds': null
            else if (targetDurationSeconds != null)
              'target_duration_seconds': targetDurationSeconds,
            if (clearDistance) 'target_distance_m': null
            else if (targetDistanceM != null)
              'target_distance_m': targetDistanceM,
            if (clearRest) 'rest_seconds': null
            else if (restSeconds != null) 'rest_seconds': restSeconds,
          }),
        ));
    return TargetSet.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /workout-exercise-sets/{id}
  Future<void> deleteSet(int setId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/workout-exercise-sets/$setId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode != 204) _decode(response);
  }
}
