import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_processor.dart';
import 'feedback_cue.dart';
import 'pose_geometry.dart';

/// Push-ups, counted from the elbow.
///
/// ## The angles
///
/// The elbow opens to nearly straight at the top and closes as the chest
/// drops, which makes shoulder-elbow-wrist the one angle that tracks the whole
/// movement. Hip or shoulder height would seem more direct, but both move with
/// the camera: a phone propped at a slightly different angle changes them
/// completely, while a joint angle is the same from anywhere.
///
/// The three thresholds below are a starting point tuned by eye, not a
/// measured constant - they are meant to be adjusted while watching the depth
/// bar on a real set. Push-up depth is more sensitive to camera placement than
/// a squat's leg swing (an elbow seen end-on foreshortens badly), so they are
/// deliberately more forgiving than the geometry alone would suggest.
///
/// ## The form check
///
/// The failure that matters in a push-up is the body bending: hips sagging
/// towards the floor, or riding up into a pike. Both shorten the movement and
/// take the work off the chest. Measured as the hip's offset from the straight
/// line between shoulder and ankle, normalised by body length so it reads the
/// same at any distance from the camera.
class PushUpProcessor extends ExerciseProcessor {
  @override
  String get algorithm => 'pushup_v1';

  /// Arms near lockout. Not 180: nobody holds a perfectly straight elbow, and
  /// demanding it means the rep never closes.
  @override
  double get restAngle => 155;

  /// Halfway down. A rep that reaches here counts, at half marks.
  @override
  double get milestone1Angle => 120;

  /// Chest low, elbow well past a right angle - full marks.
  @override
  double get milestone2Angle => 95;

  /// How far the hip may stray from the shoulder-ankle line before it is worth
  /// mentioning, as a fraction of body length. Small enough to catch a real
  /// sag, wide enough that ordinary wobble does not trigger it every set.
  static const double _bodyLineTolerance = 0.13;

  /// A sag has to persist to be real: one frame of a mislocated hip is noise,
  /// and being told to fix a hip that is already fine is worse than silence.
  static const int _formDebounceFrames = 3;

  int _sagFrames = 0;
  int _pikeFrames = 0;

  @override
  double? primaryAngle(Pose pose) {
    final side = clearestSide(
      pose,
      leftFirst: PoseLandmarkType.leftShoulder,
      leftVertex: PoseLandmarkType.leftElbow,
      leftLast: PoseLandmarkType.leftWrist,
      rightFirst: PoseLandmarkType.rightShoulder,
      rightVertex: PoseLandmarkType.rightElbow,
      rightLast: PoseLandmarkType.rightWrist,
    );
    return side?.angle;
  }

  @override
  FeedbackCue? checkForm(Pose pose, double angle, RepStage stage) {
    final body = clearestSide(
      pose,
      leftFirst: PoseLandmarkType.leftShoulder,
      leftVertex: PoseLandmarkType.leftHip,
      leftLast: PoseLandmarkType.leftAnkle,
      rightFirst: PoseLandmarkType.rightShoulder,
      rightVertex: PoseLandmarkType.rightHip,
      rightLast: PoseLandmarkType.rightAnkle,
    );
    if (body == null) {
      _sagFrames = 0;
      _pikeFrames = 0;
      return null;
    }

    final offset = offsetFromLine(body.first, body.vertex, body.last);

    if (offset > _bodyLineTolerance) {
      _pikeFrames = 0;
      _sagFrames += 1;
      if (_sagFrames >= _formDebounceFrames) {
        _sagFrames = 0;
        return FeedbackCue.raiseHips;
      }
    } else if (offset < -_bodyLineTolerance) {
      _sagFrames = 0;
      _pikeFrames += 1;
      if (_pikeFrames >= _formDebounceFrames) {
        _pikeFrames = 0;
        return FeedbackCue.lowerHips;
      }
    } else {
      _sagFrames = 0;
      _pikeFrames = 0;
    }

    return null;
  }

  @override
  void reset() {
    super.reset();
    _sagFrames = 0;
    _pikeFrames = 0;
  }
}
