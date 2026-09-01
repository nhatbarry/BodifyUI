import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

/// Keeps the Supabase session on the device between app launches.
///
/// SharedPreferences is plain storage, not a keychain - fine for development,
/// but move to flutter_secure_storage before shipping real accounts.
class TokenStorage {
  static const _accessKey = 'bodify.access_token';
  static const _refreshKey = 'bodify.refresh_token';

  const TokenStorage();

  Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, session.accessToken);
    await prefs.setString(_refreshKey, session.refreshToken);
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}
