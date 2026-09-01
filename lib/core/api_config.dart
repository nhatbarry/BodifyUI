import 'package:flutter/foundation.dart';

/// Where the Bodify backend lives.
///
/// Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// The Android emulator reaches the host machine at 10.0.2.2, not localhost.
  /// A real phone needs the host's LAN IP, passed via --dart-define.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get apiV1 => '$baseUrl/api/v1';

  static Uri path(String p) => Uri.parse('$apiV1$p');
}
