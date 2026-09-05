import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/app_locale.dart';
import '../models/workout_plan_models.dart' show apiDate;
import '../models/workout_session_models.dart';
import 'auth_service.dart';

/// The recorded-workout API.
///
/// Behind auth like the planner: user_id comes from the token, and a session
/// that is not yours answers 404 rather than 403.
class WorkoutSessionService {
  WorkoutSessionService._();

  static final WorkoutSessionService instance = WorkoutSessionService._();

  final http.Client _client = http.Client();

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
      parseErrorMessage(decoded,
          fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Map<String, String> _authJson(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// The session recorded for one date, or null if the user did not train.
  ///
  /// Two calls: the list endpoint answers "was there one" cheaply, and only
  /// then is the detail - every set of every exercise - worth fetching. The
  /// calendar asks this for each date the user taps, so most answers are
  /// "nothing here" and cost one small response.
  Future<WorkoutSession?> sessionForDate(DateTime date) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/workout-sessions')
              .replace(queryParameters: {'date': apiDate(date), 'limit': '1'}),
          headers: {'Authorization': 'Bearer $token'},
        ));
    final json = _decode(response) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;
    if (items.isEmpty) return null;

    final summary = items.first as Map<String, dynamic>;
    return getSession(summary['session_id'] as int);
  }

  /// GET /workout-sessions/{id} - the full tree, sets included.
  Future<WorkoutSession> getSession(int sessionId) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/workout-sessions/$sessionId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return WorkoutSession.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// The session currently being recorded, if any. There can only be one.
  Future<WorkoutSession?> activeSession() async {
    // Two statuses count as active, and the list endpoint filters on one at a
    // time, so ask for both.
    for (final status in ['in_progress', 'paused']) {
      final response = await _send((token) => _client.get(
            ApiConfig.path('/workout-sessions')
                .replace(queryParameters: {'status': status, 'limit': '1'}),
            headers: {'Authorization': 'Bearer $token'},
          ));
      final items = (_decode(response) as Map<String, dynamic>)['items']
          as List<dynamic>;
      if (items.isNotEmpty) {
        return getSession(
            (items.first as Map<String, dynamic>)['session_id'] as int);
      }
    }
    return null;
  }

  /// GET /workout-history - completed sessions over a period, with totals.
  ///
  /// Only completed sessions: one abandoned halfway is not a workout, and
  /// counting it would understate every average on the screen.
  Future<WorkoutHistory> history({DateTime? from, DateTime? to}) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/workout-history').replace(queryParameters: {
            if (from != null) 'from': apiDate(from),
            if (to != null) 'to': apiDate(to),
            'limit': '50',
          }),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return WorkoutHistory.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /workout-sessions - start training.
  ///
  /// Passing the day copies its exercises and target sets in, so the screen
  /// opens with the whole workout laid out and every set waiting for a number.
  Future<WorkoutSession> startSession({
    int? workoutDayId,
    DateTime? scheduledDate,
  }) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/workout-sessions')
              .replace(queryParameters: {'language': _language}),
          headers: _authJson(token),
          body: jsonEncode({
            if (workoutDayId != null) 'workout_day_id': workoutDayId,
            if (scheduledDate != null) 'scheduled_date': apiDate(scheduledDate),
          }),
        ));
    return WorkoutSession.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /session-sets/{id} - record or correct what was lifted.
  ///
  /// Sending null clears a value; omitting the key keeps it. The target
  /// numbers are not settable here - they are the plan's snapshot.
  /// The `clear*` flags exist because omitting a key and sending null mean
  /// different things: omit keeps the current value, null wipes it. Clearing
  /// matters when a user corrects a set down to nothing on one axis.
  Future<SessionSet> recordSet(
    int setId, {
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceM,
    bool? completed,
    bool clearReps = false,
    bool clearWeight = false,
    bool clearDuration = false,
    bool clearDistance = false,
  }) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/session-sets/$setId'),
          headers: _authJson(token),
          body: jsonEncode({
            if (clearReps) 'reps': null else if (reps != null) 'reps': reps,
            if (clearWeight)
              'weight_kg': null
            else if (weightKg != null)
              'weight_kg': weightKg,
            if (clearDuration)
              'duration_seconds': null
            else if (durationSeconds != null)
              'duration_seconds': durationSeconds,
            if (clearDistance)
              'distance_m': null
            else if (distanceM != null)
              'distance_m': distanceM,
            if (completed != null) 'completed': completed,
          }),
        ));
    return SessionSet.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /workout-sessions/{id}/sync-plan - make the session's exercises
  /// match the plan for its date.
  ///
  /// Called whenever the workout screen is opened. Starting a workout copies
  /// the day in, and that copy went stale the moment the user edited the day
  /// and came back: the open session still offered only the old exercises.
  ///
  /// Exercises dropped from the plan are removed even if sets were logged
  /// against them - taking an exercise off today's plan is the user saying
  /// they are not doing it. Exercises still planned keep their logged sets.
  Future<WorkoutSession> syncSessionWithPlan(int sessionId) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/workout-sessions/$sessionId/sync-plan')
              .replace(queryParameters: {'language': _language}),
          headers: _authJson(token),
        ));
    return WorkoutSession.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /session-exercises/{id}/sets - an extra set beyond the plan.
  Future<SessionSet> addSet(
    int sessionExerciseId, {
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceM,
  }) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/session-exercises/$sessionExerciseId/sets'),
          headers: _authJson(token),
          body: jsonEncode({
            if (reps != null) 'reps': reps,
            if (weightKg != null) 'weight_kg': weightKg,
            if (durationSeconds != null) 'duration_seconds': durationSeconds,
            if (distanceM != null) 'distance_m': distanceM,
          }),
        ));
    return SessionSet.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /session-sets/{id}
  Future<void> deleteSet(int setId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/session-sets/$setId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _decode(response);
  }

  /// POST /workout-sessions/{id}/pause - stop the clock, keep the workout.
  Future<WorkoutSession> pauseSession(int sessionId) => _post('$sessionId/pause');

  /// POST /workout-sessions/{id}/resume
  Future<WorkoutSession> resumeSession(int sessionId) =>
      _post('$sessionId/resume');

  /// POST /workout-sessions/{id}/reopen - put a finished session back in
  /// progress. The server banks the stretch since it was finished into
  /// `paused_seconds`, so reopening does not inflate the duration.
  Future<WorkoutSession> reopenSession(int sessionId) =>
      _post('$sessionId/reopen');

  Future<WorkoutSession> _post(String suffix) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/workout-sessions/$suffix'),
          headers: _authJson(token),
        ));
    return WorkoutSession.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /workout-sessions/{id}/finish
  Future<WorkoutSession> finishSession(int sessionId,
      {bool abandoned = false}) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/workout-sessions/$sessionId/finish'),
          headers: _authJson(token),
          body: jsonEncode({'abandoned': abandoned}),
        ));
    return WorkoutSession.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /workout-sessions/{id} - for one started by mistake.
  Future<void> deleteSession(int sessionId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/workout-sessions/$sessionId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _decode(response);
  }
}
