import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/body_metric.dart';
import 'auth_service.dart';

/// Reads and writes the signed-in user's body measurements.
///
/// Every endpoint here is behind auth; user_id is taken from the token by the
/// backend, never sent by the app.
class BodyMetricService {
  BodyMetricService._();

  static final BodyMetricService instance = BodyMetricService._();

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

    // An expired access token is the common case here; refresh once and retry
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

  /// GET /body-metrics/latest - null when nothing has been recorded yet.
  Future<BodyMetric?> latest() async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/body-metrics/latest'),
          headers: {'Authorization': 'Bearer $token'},
        ));

    // 404 here means "no measurements", which is a normal empty state.
    if (response.statusCode == 404) return null;

    return BodyMetric.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// GET /body-metrics - history, newest first.
  Future<List<BodyMetric>> history({int page = 1, int limit = 50}) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/body-metrics')
              .replace(queryParameters: {'page': '$page', 'limit': '$limit'}),
          headers: {'Authorization': 'Bearer $token'},
        ));

    final json = _decode(response) as Map<String, dynamic>;
    return (json['items'] as List<dynamic>)
        .map((e) => BodyMetric.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /body-metrics
  Future<BodyMetric> record({double? heightCm, double? weightKg}) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/body-metrics'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            if (heightCm != null) 'height_cm': heightCm,
            if (weightKg != null) 'weight_kg': weightKg,
          }),
        ));

    return BodyMetric.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /body-metrics/{id}
  Future<void> delete(int metricId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/body-metrics/$metricId'),
          headers: {'Authorization': 'Bearer $token'},
        ));

    if (response.statusCode != 204) _decode(response);
  }
}
