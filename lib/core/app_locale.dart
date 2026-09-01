import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  vietnamese('vi', 'Tiếng Việt'),
  english('en', 'English');

  const AppLanguage(this.code, this.label);

  /// Also the value sent as `language` to the exercise endpoints, so the UI
  /// language and the workout data language never drift apart.
  final String code;
  final String label;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (lang) => lang.code == code,
        orElse: () => AppLanguage.vietnamese,
      );
}

/// Holds the chosen language and remembers it across launches.
class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const _storageKey = 'bodify.language';

  AppLanguage _language = AppLanguage.vietnamese;

  AppLanguage get language => _language;

  String get apiLanguage => _language.code;

  Locale get locale => Locale(_language.code);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = AppLanguage.fromCode(prefs.getString(_storageKey));
      notifyListeners();
    } catch (_) {
      // A missing/unreadable preference just means the default language.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, language.code);
    } catch (_) {
      // Failing to persist should not undo the switch the user just made.
    }
  }
}
