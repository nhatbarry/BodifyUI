import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/profile.dart';
import 'auth_service.dart';

/// Reads and updates the signed-in user's profile.
class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

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

    // Refresh once on an expired access token rather than bouncing the user
    // out to the login screen.
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

  Map<String, dynamic> _decode(http.Response response) {
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

  /// GET /profile
  Future<Profile> get() async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/profile'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return Profile.fromJson(_decode(response));
  }

  /// PUT /profile - partial update; omitted fields keep their value.
  ///
  /// `clearDateOfBirth` / `clearGender` exist because sending null and omitting
  /// the key mean different things to the backend: omit keeps, null clears.
  Future<Profile> update({
    String? name,
    String? avatarUrl,
    DateTime? dateOfBirth,
    String? gender,
    bool clearDateOfBirth = false,
    bool clearGender = false,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (clearDateOfBirth)
        'date_of_birth': null
      else if (dateOfBirth != null)
        // The column is a DATE, so send only the day part.
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      if (clearGender)
        'gender': null
      else if (gender != null)
        'gender': gender,
    };

    final response = await _send((token) => _client.put(
          ApiConfig.path('/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ));

    final profile = Profile.fromJson(_decode(response));
    // Keep the header on the profile tab and anything else reading the cached
    // user in step with what was just saved.
    await AuthService.instance.reloadCurrentUser();
    return profile;
  }
}
