import 'package:flutter_tts/flutter_tts.dart';

import '../core/app_locale.dart';
import 'feedback_cue.dart';

/// Speaks form cues while the user is training.
///
/// Mid-set the user is face-down on the floor and not reading anything, which
/// is the whole reason this exists rather than only a banner.
///
/// Two rules keep it from becoming a nuisance:
///
///   * **One cue at a time.** `awaitSpeakCompletion` is off - waiting would
///     queue cues behind each other and deliver them a rep late - so a new cue
///     stops whatever is being said.
///   * **A cooldown per cue.** Sagging hips are detected on frame after frame;
///     without this the phone repeats "raise your hips" several times a
///     second. The same cue stays quiet for [_cooldown] after it is spoken,
///     while a *different* cue can still interrupt immediately.
///
/// Language follows the app's own setting rather than the phone's, the same
/// rule the workout data uses - a user reading Vietnamese in the app should
/// not be coached in English.
class TtsCoach {
  static const Duration _cooldown = Duration(milliseconds: 2500);

  final FlutterTts _tts = FlutterTts();
  final Map<FeedbackCue, DateTime> _lastSpoken = {};
  bool _ready = false;

  Future<void> init() async {
    final language =
        LocaleController.instance.language == AppLanguage.vietnamese
            ? 'vi-VN'
            : 'en-US';
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (_) {
      // A device with no voice for this language should not take the camera
      // screen down with it: the banner still shows every cue.
      _ready = false;
    }
  }

  Future<void> say(FeedbackCue cue) async {
    if (!_ready) return;

    final now = DateTime.now();
    final last = _lastSpoken[cue];
    if (last != null && now.difference(last) < _cooldown) return;
    _lastSpoken[cue] = now;

    try {
      await _tts.stop();
      await _tts.speak(cue.text);
    } catch (_) {
      // Speech failing mid-set is not worth interrupting the workout for.
    }
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
