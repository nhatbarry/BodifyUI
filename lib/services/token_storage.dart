import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

/// Keeps the Supabase session on the device between app launches.
///
/// Backed by the platform keystore - Android EncryptedSharedPreferences, iOS
/// Keychain - not plain preferences. The refresh token is a long-lived
/// credential: anything holding it can mint access tokens until Supabase
/// expires it, and plain preferences are readable on a rooted phone and can
/// come out in an `adb backup`.
class TokenStorage {
  static const _accessKey = 'bodify.access_token';
  static const _refreshKey = 'bodify.refresh_token';

  const TokenStorage();

  /// Per-launch guard so the sweep below runs once, not on every read.
  static bool _migrated = false;

  // Android's defaults in this version are already KeyStore-backed - AES-GCM
  // data encryption under an RSA-wrapped key - so they are left alone.
  //
  // iOS is not left alone: the Keychain default refuses to hand anything back
  // while the device is locked, which would break a token refresh that fires
  // in the background. first_unlock keeps the item readable after the first
  // unlock since boot, without ever leaving the Keychain.
  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> save(AuthSession session) async {
    await _secure.write(key: _accessKey, value: session.accessToken);
    await _secure.write(key: _refreshKey, value: session.refreshToken);
  }

  Future<String?> readAccessToken() async {
    await _migrateLegacy();
    return _secure.read(key: _accessKey);
  }

  Future<String?> readRefreshToken() async {
    await _migrateLegacy();
    return _secure.read(key: _refreshKey);
  }

  /// Moves tokens out of the old plain storage, both at once.
  ///
  /// Existing installs keep their session in SharedPreferences; without this
  /// they would all be silently signed out on upgrade. It moves **both** keys
  /// on the first read of either, deliberately: migrating only the key being
  /// read would leave the refresh token - the long-lived one, the one worth
  /// stealing - sitting in plaintext until something happened to refresh the
  /// session, which might be days.
  ///
  /// Runs once per launch. A failure is swallowed: the tokens are still
  /// readable from the old place, so the user stays signed in and the sweep
  /// retries next launch.
  Future<void> _migrateLegacy() async {
    if (_migrated) return;
    _migrated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in const [_accessKey, _refreshKey]) {
        final legacy = prefs.getString(key);
        if (legacy == null) continue;
        await _secure.write(key: key, value: legacy);
        await prefs.remove(key);
      }
    } catch (_) {
      _migrated = false;
    }
  }

  Future<void> clear() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);

    // Belt and braces: an install that never got as far as a migrating read
    // would otherwise keep its plaintext tokens after signing out.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}
