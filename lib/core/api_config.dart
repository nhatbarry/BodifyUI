/// Where the Bodify backend lives.
///
/// Both halves are hosted now - Postgres on Supabase, the API on Railway - so
/// that is the default every build gets with zero configuration: a real
/// device, a fresh `flutter run`, an Android Studio config with no extra
/// args, a build someone else runs after cloning the repo. Nobody has to
/// remember a LAN IP or an emulator-only alias just to get the app talking to
/// something.
///
/// Point at a local backend instead when actually developing against one:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000       (emulator)
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000  (real device, same LAN)
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String _productionUrl =
      'https://bodifybackend-production.up.railway.app';

  static String get baseUrl =>
      _override.isNotEmpty ? _override : _productionUrl;

  static String get apiV1 => '$baseUrl/api/v1';

  static Uri path(String p) => Uri.parse('$apiV1$p');
}
