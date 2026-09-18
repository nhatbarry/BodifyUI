import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/auth_models.dart';
import 'token_storage.dart';

/// Talks to the Bodify backend's /api/v1/auth endpoints.
///
/// Auth itself lives in Supabase; this app only ever sees the tokens the
/// backend hands back, and never the user's password after login.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final TokenStorage _storage = const TokenStorage();
  final http.Client _client = http.Client();

  /// Who is signed in right now; null when signed out. Widgets can listen.
  final ValueNotifier<CurrentUser?> currentUser =
      ValueNotifier<CurrentUser?>(null);

  bool get isSignedIn => currentUser.value != null;

  // ---------------------------------------------------------------- requests

  /// Runs a request, turning transport failures into a readable ApiException.
  ///
  /// Deliberately avoids dart:io (SocketException) so the app still builds for
  /// web; package:http reports connection failures as ClientException there.
  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function() request) async {
    late http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException(
          'Cannot reach the server. Is the backend running?');
    }

    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) {
    return _send(() => _client.post(
          ApiConfig.path(path),
          headers: {
            'Content-Type': 'application/json',
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> _get(String path,
      {required String bearerToken}) {
    return _send(() => _client.get(
          ApiConfig.path(path),
          headers: {'Authorization': 'Bearer $bearerToken'},
        ));
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      // 204 and friends succeed with nothing to say. Treating an empty body as
      // a failure made a *successful* password change throw: the server had
      // already revoked every session, the app never cleared its own, and the
      // next request died on a token that no longer existed.
      if (response.body.isEmpty) return const {};
      throw const ApiException('Unexpected response from the server.');
    }

    throw ApiException(
      parseErrorMessage(decoded,
          fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  // ------------------------------------------------------------------- flows

  /// POST /auth/register - creates the Supabase account and its profile row.
  Future<RegisterResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final json = await _post('/auth/register', {
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
    });

    final result = RegisterResult.fromJson(json);

    // The project may require email confirmation, in which case there is no
    // session yet and the user still has to log in later.
    if (result.session != null) {
      await _storage.save(result.session!);
      currentUser.value = CurrentUser(
        user: result.user,
        profile: result.profile,
        role: result.profile.role,
      );
    }

    return result;
  }

  /// POST /auth/login
  Future<CurrentUser> login(
      {required String email, required String password}) async {
    final json = await _post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });

    final session = AuthSession.fromJson(json);
    await _storage.save(session);

    final user = await _fetchMe(session.accessToken);
    currentUser.value = user;
    return user;
  }

  /// Takes over a session obtained elsewhere - a Google or Facebook sign-in.
  ///
  /// Those flows end with Supabase tokens rather than with a /auth/login
  /// response, but everything downstream (stored tokens, currentUser, the
  /// screens listening to it) has to end up in exactly the same state as an
  /// email login, so they hand the session here instead of duplicating it.
  Future<CurrentUser> adoptSession(AuthSession session) async {
    await _storage.save(session);
    final user = await _fetchMe(session.accessToken);
    currentUser.value = user;
    return user;
  }

  /// POST /auth/refresh - swaps the refresh token for a fresh session.
  Future<AuthSession?> refreshSession() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final json =
          await _post('/auth/refresh', {'refresh_token': refreshToken});
      final session = AuthSession.fromJson(json);
      await _storage.save(session);
      return session;
    } on ApiException catch (e) {
      // A rejected refresh token means the session is gone for good.
      if (e.statusCode == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  /// GET /auth/me
  Future<CurrentUser> _fetchMe(String accessToken) async {
    final json = await _get('/auth/me', bearerToken: accessToken);
    return CurrentUser.fromJson(json);
  }

  /// Restores a stored session on app start, refreshing it once if expired.
  ///
  /// Returns null when there is nothing valid to restore, which sends the user
  /// back to onboarding.
  Future<CurrentUser?> restoreSession() async {
    final accessToken = await _storage.readAccessToken();
    if (accessToken == null) return null;

    try {
      final user = await _fetchMe(accessToken);
      currentUser.value = user;
      return user;
    } on ApiException catch (e) {
      if (e.statusCode != 401) {
        // Server down or offline: keep the stored tokens so the user is not
        // silently signed out over a temporary network problem.
        rethrow;
      }
    }

    final session = await refreshSession();
    if (session == null) return null;

    try {
      final user = await _fetchMe(session.accessToken);
      currentUser.value = user;
      return user;
    } on ApiException {
      await logout();
      return null;
    }
  }

  /// Re-reads the profile of the signed-in user.
  Future<CurrentUser?> reloadCurrentUser() async {
    final accessToken = await _storage.readAccessToken();
    if (accessToken == null) return null;
    final user = await _fetchMe(accessToken);
    currentUser.value = user;
    return user;
  }

  /// Signs out, revoking the session on the server as well as locally.
  ///
  /// The stored tokens are cleared **whatever happens** to the network call.
  /// Refusing to sign someone out because the server is unreachable would
  /// leave their account open on a shared phone, which is the one situation
  /// where signing out matters most. The revoke is best-effort on top of that:
  /// without it the refresh token stays usable until Supabase expires it, so
  /// anyone who lifted it off the device keeps access.
  Future<void> logout() async {
    final token = await _storage.readAccessToken();

    if (token != null) {
      try {
        await _client.post(
          ApiConfig.path('/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Offline, or the session was already dead. Either way the local
        // clear below is what the user asked for.
      }
    }

    await _storage.clear();
    currentUser.value = null;
  }

  /// Asks the backend to email a reset link.
  ///
  /// Succeeds whether or not the address is registered - the backend answers
  /// identically on purpose, so that this cannot be used to find out which
  /// emails have accounts, and the UI must not undo that by reporting
  /// anything more specific.
  Future<void> requestPasswordReset(String email) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
    String bearerToken,
  ) {
    return _send(() => _client.put(
          ApiConfig.path(path),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $bearerToken',
          },
          body: jsonEncode(body),
        ));
  }

  /// PUT /auth/password - the current password is re-checked server-side.
  ///
  /// Every session is signed out afterwards, this one included: a password
  /// change is usually somebody ending access they no longer want, and leaving
  /// the other devices signed in would defeat it. The caller is expected to
  /// send the user back to the login screen.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _storage.readAccessToken();
    if (token == null) {
      throw const ApiException('Not signed in', statusCode: 401);
    }
    await _put(
        '/auth/password',
        {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        token);
    // The backend has already revoked the sessions; clearing locally keeps
    // the app from holding a token it knows is dead.
    await _storage.clear();
    currentUser.value = null;
  }

  /// PUT /auth/email - also gated on the current password.
  ///
  /// Whether the new address needs confirming before it works is a Supabase
  /// project setting, so this promises nothing about when the change lands.
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final token = await _storage.readAccessToken();
    if (token == null) {
      throw const ApiException('Not signed in', statusCode: 401);
    }
    await _put(
        '/auth/email',
        {
          'current_password': currentPassword,
          'new_email': newEmail,
        },
        token);
  }

  /// Access token for calling other protected endpoints, refreshed if needed.
  Future<String?> validAccessToken() async => _storage.readAccessToken();
}
