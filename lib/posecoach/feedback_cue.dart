import '../core/app_strings.dart';

/// Something the coach says about the user's form.
///
/// An enum rather than a string so the processor - which knows about angles,
/// not about language - never has to build a sentence. The wording is looked
/// up here, from the same table the rest of the app uses, so the spoken cue
/// follows the app's language setting rather than the phone's.
enum FeedbackCue {
  /// Dipped, but not far enough for the rep to count.
  goDeeper('msg_cue_go_deeper'),

  /// Hips sagging below the shoulder-ankle line - the banana plank.
  raiseHips('msg_cue_raise_hips'),

  /// Hips riding above the line - piking, which shortens the movement.
  lowerHips('msg_cue_lower_hips');

  const FeedbackCue(this.stringKey);

  final String stringKey;

  /// What to show on the banner and speak aloud.
  String get text => tr(stringKey);
}
