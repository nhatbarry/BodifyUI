import 'dart:async';
import 'dart:convert';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/app_strings.dart';
import '../models/auth_models.dart';

/// Signing in with Google or Facebook.
///
/// The two take different routes, and the reason is what each platform hands
/// back rather than a preference:
///
/// **Google** uses Android's own account picker, which returns a signed ID
/// token. That token goes to our backend, which exchanges it for a Supabase
/// session. No browser, and the app never learns the Supabase URL.
///
/// **Facebook** has no equivalent on Android - its SDK returns an access
/// token, not the OIDC ID token Supabase would accept - so it goes through a
/// Custom Tab onto Supabase's hosted sign-in page, which redirects back to
/// [_callbackScheme] carrying the session in the URL fragment.
///
/// Which of the two the server can actually complete is [SocialAuthConfig],
/// fetched before the buttons are drawn: a button that always fails is worse
/// than no button.
class SocialAuthService {
  SocialAuthService._();

  static final SocialAuthService instance = SocialAuthService._();

  /// The custom scheme Supabase redirects to at the end of a browser sign-in.
  /// Must match `OAUTH_REDIRECT_URL` on the server and the redirect allowlist
  /// in the Supabase dashboard, and the intent filter in AndroidManifest.xml.
  static const String _callbackScheme = 'bodify';

  final http.Client _client = http.Client();

  SocialAuthConfig? _config;
  bool _googleInitialised = false;

  /// What the server is set up for. Cached: it cannot change while the app is
  /// running, and both auth screens ask for it.
  Future<SocialAuthConfig> config() async {
    final cached = _config;
    if (cached != null) return cached;

    final response = await _client
        .get(ApiConfig.path('/auth/oauth/config'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      // Not an error worth showing: the screens treat an unknown config as
      // "no social sign-in", which is exactly what an old backend means.
      return _config = const SocialAuthConfig.none();
    }

    return _config = SocialAuthConfig.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  // ------------------------------------------------------------------ google

  /// Opens Android's account picker and signs in with what it returns.
  ///
  /// Returns null when the user backs out - a cancellation is not a failure
  /// and must not raise an error banner at them.
  Future<AuthSession?> signInWithGoogle() async {
    final settings = await config();
    final clientId = settings.googleClientId;
    if (!settings.google || clientId == null) {
      throw ApiException(tr('error_social_unavailable'));
    }

    final signIn = GoogleSignIn.instance;
    if (!_googleInitialised) {
      // serverClientId, not clientId: Android signs its ID token for the *web*
      // client, because that is the audience Supabase is configured to accept.
      await signIn.initialize(serverClientId: clientId);
      _googleInitialised = true;
    }

    if (!signIn.supportsAuthenticate()) {
      throw ApiException(tr('error_social_unavailable'));
    }

    final GoogleSignInAccount account;
    try {
      // Signed out first so the picker appears every time. Without it a second
      // sign-in silently reuses the previous account, which is wrong on a
      // shared phone and impossible to get out of.
      await signIn.signOut();
      account = await signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ApiException(tr('error_google_sign_in_failed'));
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Almost always a setup problem rather than a user one: no Android OAuth
      // client for this app's signing certificate, so Google signs the user in
      // but will not issue a token for our server.
      throw ApiException(tr('error_google_no_token'));
    }

    return _exchange('/auth/oauth/google', {'id_token': idToken});
  }

  // ---------------------------------------------------------------- facebook

  /// Runs the browser half of a Facebook sign-in and returns the session.
  ///
  /// Returns null when the user closes the tab without finishing.
  Future<AuthSession?> signInWithFacebook() async {
    final settings = await config();
    if (!settings.facebook) {
      throw ApiException(tr('error_social_unavailable'));
    }

    // The URL comes from our backend, so the Supabase project URL stays a
    // server-side detail and the redirect target is fixed by its config
    // rather than by anything on the device.
    final urlResponse = await _client
        .get(ApiConfig.path('/auth/oauth/facebook/url'))
        .timeout(const Duration(seconds: 10));
    if (urlResponse.statusCode != 200) {
      throw ApiException(tr('error_social_unavailable'));
    }
    final authorizeUrl = (jsonDecode(utf8.decode(urlResponse.bodyBytes))
        as Map)['url'] as String;

    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: authorizeUrl,
        callbackUrlScheme: _callbackScheme,
      );
    } catch (_) {
      // The package throws on cancellation as well as on failure, and the two
      // are not distinguishable here. Treated as a cancellation: an error
      // banner for someone who simply changed their mind is worse than
      // silence for someone who hit a real problem and can just try again.
      return null;
    }

    final session = _sessionFromCallback(callback);
    if (session == null) {
      throw ApiException(tr('error_facebook_sign_in_failed'));
    }

    // The account may have just been created by Supabase without this server
    // seeing any of it, so the profile row has to be asked for explicitly.
    await _client.post(
      ApiConfig.path('/auth/oauth/complete'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    ).timeout(const Duration(seconds: 15));

    return session;
  }

  /// Pulls the session out of `bodify://auth#access_token=...&refresh_token=...`.
  ///
  /// The tokens arrive in the URL *fragment*, which is why this cannot just
  /// read query parameters: everything after the `#` is one opaque string as
  /// far as [Uri] is concerned.
  AuthSession? _sessionFromCallback(String callback) {
    final uri = Uri.tryParse(callback);
    if (uri == null) return null;

    final fields = <String, String>{
      ...uri.queryParameters,
      if (uri.fragment.isNotEmpty) ...Uri.splitQueryString(uri.fragment),
    };

    final accessToken = fields['access_token'];
    final refreshToken = fields['refresh_token'];
    if (accessToken == null || refreshToken == null) return null;

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: int.tryParse(fields['expires_in'] ?? ''),
      expiresAt: int.tryParse(fields['expires_at'] ?? ''),
    );
  }

  // ------------------------------------------------------------------ shared

  Future<AuthSession> _exchange(String path, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            ApiConfig.path(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException(
          'Cannot reach the server. Is the backend running?');
    }

    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        parseErrorMessage(decoded, fallback: tr('error_google_sign_in_failed')),
        statusCode: response.statusCode,
      );
    }

    return AuthSession.fromJson(
      (decoded as Map<String, dynamic>)['session'] as Map<String, dynamic>,
    );
  }
}

/// Which social sign-ins the backend can complete, from GET /auth/oauth/config.
class SocialAuthConfig {
  final bool google;
  final bool facebook;

  /// The audience Android must sign its ID token for. Null when [google] is
  /// false.
  final String? googleClientId;

  const SocialAuthConfig({
    required this.google,
    required this.facebook,
    this.googleClientId,
  });

  /// Nothing configured - the buttons are hidden entirely.
  const SocialAuthConfig.none()
      : google = false,
        facebook = false,
        googleClientId = null;

  bool get any => google || facebook;

  factory SocialAuthConfig.fromJson(Map<String, dynamic> json) =>
      SocialAuthConfig(
        google: json['google'] == true,
        facebook: json['facebook'] == true,
        googleClientId: json['google_client_id'] as String?,
      );
}
