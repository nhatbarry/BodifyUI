import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_processor.dart';
import 'feedback_cue.dart';
import 'pose_geometry.dart';

/// Squats, counted from the knee.
///
/// ## The angles
///
/// Hip-knee-ankle opens to nearly straight standing and closes as the hips
/// drop, so it tracks the whole movement the way the elbow does for a push-up.
/// It is read **side-on**: from the front, a squat bends the knee towards the
/// camera, the three landmarks stay almost in a vertical line, and the angle
/// barely moves from 180 however deep the user goes. That is why this
/// processor has its own [setupHintKey] - "film me from the front" is the
/// natural thing to try, and it counts nothing.
///
/// What the numbers mean, worked out from the geometry rather than guessed:
/// with the thigh level (parallel) the knee reads 90 with an upright shin and
/// about 60-70 with the shin leaning forward over the toes, which is how most
/// people squat. A half squat - thigh about 45 degrees down - reads 115-135.
/// So [milestone2Angle] at 100 gives full marks at parallel with some room for
/// a camera that is not quite side-on, and [milestone1Angle] at 130 counts a
/// half squat at half marks. Like the push-up's, they are a starting point to
/// be checked against the tuning readout on a real set.
///
/// ## The form checks
///
/// Both are things a side-on camera can actually see:
///
///   * **Chest dropping.** The torso leaning so far forward that the squat
///     turns into a good-morning. Some lean is correct - more with a bar on
///     the back - so only past [_maxTorsoLean] from vertical, and only near the
///     bottom, where it matters.
///   * **Heels lifting.** Weight rolling onto the toes. Measured against how
///     the foot looked while standing at the top, not against the image's
///     horizontal: a phone propped a few degrees off level would otherwise
///     read every foot as a lifted heel.
///
/// Knees caving inwards is the other classic squat fault, and it is not here
/// on purpose: it happens across the camera's line of sight from the side,
/// and needs a front view this processor cannot count from.
class SquatProcessor extends ExerciseProcessor {
  @override
  String get algorithm => 'squat_v1';

  /// Standing. Not 180: a knee held perfectly straight is a locked knee, and
  /// plenty of people finish a rep just short of it.
  @override
  double get restAngle => 160;

  /// A half squat - counts, at half marks.
  @override
  double get milestone1Angle => 130;

  /// Thigh at or near parallel - full marks.
  @override
  double get milestone2Angle => 100;

  /// A squat is a bigger movement than a push-up: a bodyweight rep down to
  /// parallel and back takes a second or more. Under 600 ms top to top is a
  /// bounce or a glitch.
  @override
  Duration get minRepDuration => const Duration(milliseconds: 600);

  @override
  String get setupHintKey => 'msg_ai_squat_setup';

  /// Torso lean from vertical, in degrees, past which the chest is said to be
  /// dropping. A good back squat leans 30-45; past 55 the hips are rising
  /// faster than the shoulders.
  static const double _maxTorsoLean = 55;

  /// How far the heel may rise towards the toes' level, as a fraction of shin
  /// length, beyond what it was while standing. Small - a lifted heel is a few
  /// centimetres - but above the landmark jitter of a still foot.
  static const double _heelLiftTolerance = 0.08;

  /// A fault has to persist to be said out loud - one misplaced landmark is
  /// noise, and correcting a form that is already fine is worse than silence.
  static const int _formDebounceFrames = 3;

  int _leanFrames = 0;
  int _heelFrames = 0;

  /// Heel height relative to the toes while standing, per side. The
  /// reference [_heelLiftTolerance] is measured from.
  final Map<BodySideId, double> _standingHeel = {};

  BodySideId? _side;
  double? _confidence;

  @override
  String? get activeSide => switch (_side) {
        BodySideId.left => 'L',
        BodySideId.right => 'R',
        null => null,
      };

  @override
  double? get activeConfidence => _confidence;

  @override
  double? primaryAngle(Pose pose) {
    final side = clearestSide(
      pose,
      leftFirst: PoseLandmarkType.leftHip,
      leftVertex: PoseLandmarkType.leftKnee,
      leftLast: PoseLandmarkType.leftAnkle,
      rightFirst: PoseLandmarkType.rightHip,
      rightVertex: PoseLandmarkType.rightKnee,
      rightLast: PoseLandmarkType.rightAnkle,
      current: _side,
    );
    _side = side?.id;
    _confidence = side?.confidence;
    return side?.angle;
  }

  @override
  FeedbackCue? checkForm(Pose pose, double angle, RepStage stage) {
    final side = _side;
    if (side == null) return null;

    final standing = angle >= restAngle;
    if (standing) {
      _rememberStandingFoot(pose, side);
      _leanFrames = 0;
      _heelFrames = 0;
      return null;
    }

    // Lean is only judged near the bottom: on the way down everybody passes
    // through a forward angle on their way to a good one.
    final nearBottom = angle <= milestone1Angle;
    final lean = nearBottom ? torsoLean(pose, side) : null;
    if (lean != null && lean > _maxTorsoLean) {
      _leanFrames += 1;
      if (_leanFrames >= _formDebounceFrames) {
        _leanFrames = 0;
        return FeedbackCue.chestUp;
      }
    } else {
      _leanFrames = 0;
    }

    final lift = _heelLift(pose, side);
    if (lift != null && lift > _heelLiftTolerance) {
      _heelFrames += 1;
      if (_heelFrames >= _formDebounceFrames) {
        _heelFrames = 0;
        return FeedbackCue.heelsDown;
      }
    } else {
      _heelFrames = 0;
    }

    return null;
  }

  /// Degrees the shoulder-hip line leans away from vertical, 0 upright.
  ///
  /// Image y grows downwards, so "up" is negative y. Null when either joint
  /// is not seen well enough to trust.
  static double? torsoLean(Pose pose, BodySideId side) {
    final shoulder = pose.landmarks[side == BodySideId.left
        ? PoseLandmarkType.leftShoulder
        : PoseLandmarkType.rightShoulder];
    final hip = pose.landmarks[side == BodySideId.left
        ? PoseLandmarkType.leftHip
        : PoseLandmarkType.rightHip];
    if (!allConfident([shoulder, hip])) return null;

    final dx = (shoulder!.x - hip!.x).abs();
    final up = hip.y - shoulder.y;
    if (dx == 0 && up == 0) return null;
    return math.atan2(dx, up) * 180 / math.pi;
  }

  /// Heel height above the toes, as a fraction of shin length - positive
  /// when the heel is higher. Null when the foot is not seen.
  static double? heelAboveToes(Pose pose, BodySideId side) {
    final left = side == BodySideId.left;
    final heel = pose.landmarks[
        left ? PoseLandmarkType.leftHeel : PoseLandmarkType.rightHeel];
    final toes = pose.landmarks[left
        ? PoseLandmarkType.leftFootIndex
        : PoseLandmarkType.rightFootIndex];
    final knee = pose.landmarks[
        left ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee];
    final ankle = pose.landmarks[
        left ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle];
    if (!allConfident([heel, toes, knee, ankle])) return null;

    final shin = math.sqrt(math.pow(knee!.x - ankle!.x, 2) +
        math.pow(knee.y - ankle.y, 2));
    if (shin < 1) return null;
    return (toes!.y - heel!.y) / shin;
  }

  void _rememberStandingFoot(Pose pose, BodySideId side) {
    final now = heelAboveToes(pose, side);
    if (now == null) return;
    final before = _standingHeel[side];
    // Averaged, so one jittery standing frame does not become the reference
    // every later frame is judged against.
    _standingHeel[side] = before == null ? now : before + 0.3 * (now - before);
  }

  /// How much higher the heel is now than it was while standing. Null until
  /// the user has been seen standing with their foot visible - with no
  /// reference there is nothing to compare against, and guessing would cue
  /// a fault that is not there.
  double? _heelLift(Pose pose, BodySideId side) {
    final reference = _standingHeel[side];
    final now = heelAboveToes(pose, side);
    if (reference == null || now == null) return null;
    return now - reference;
  }

  @override
  void reset() {
    super.reset();
    _leanFrames = 0;
    _heelFrames = 0;
    _standingHeel.clear();
    _side = null;
    _confidence = null;
  }
}
