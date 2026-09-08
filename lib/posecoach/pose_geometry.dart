import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Below this, ML Kit is guessing where a joint is rather than seeing it.
///
/// Every angle here is computed from three landmarks, so one hallucinated
/// point is enough to invent a rep the user never did. Frames that cannot
/// clear this bar are skipped instead - a missed rep is a smaller lie than a
/// phantom one.
const double kMinLandmarkConfidence = 0.6;

/// The angle at [vertex], in degrees, between the two limbs meeting there.
///
/// 180 is a straight limb, 90 a right angle. Computed in image space: the
/// landmarks carry a z, but ML Kit's depth is a rough estimate and folding it
/// in made the reading noisier, not truer.
double jointAngle(PoseLandmark first, PoseLandmark vertex, PoseLandmark last) {
  final radians = math.atan2(last.y - vertex.y, last.x - vertex.x) -
      math.atan2(first.y - vertex.y, first.x - vertex.x);
  var degrees = radians * 180 / math.pi;
  degrees = degrees.abs();
  // atan2 spans a full turn, so the reflex reading has to be folded back:
  // an elbow at 350 degrees is the same bend as one at 10.
  return degrees > 180 ? 360 - degrees : degrees;
}

/// True when every landmark given is one ML Kit actually saw.
bool allConfident(Iterable<PoseLandmark?> landmarks) {
  for (final landmark in landmarks) {
    if (landmark == null || landmark.likelihood < kMinLandmarkConfidence) {
      return false;
    }
  }
  return true;
}

/// One side of the body: the three landmarks an exercise measures its angle
/// from, plus how well they were seen.
class BodySide {
  final PoseLandmark first;
  final PoseLandmark vertex;
  final PoseLandmark last;

  const BodySide(this.first, this.vertex, this.last);

  double get confidence =>
      math.min(first.likelihood, math.min(vertex.likelihood, last.likelihood));

  double get angle => jointAngle(first, vertex, last);
}

/// Picks whichever side of the body the camera can actually see.
///
/// A phone on the floor beside someone doing push-ups sees one arm clearly and
/// the other through their torso. Fixing on "the left elbow" therefore drops
/// half of all reps depending on which way the user happened to lie down; this
/// re-decides every frame and follows whichever side is currently legible.
///
/// Null when neither side clears the confidence bar - the caller skips the
/// frame rather than trusting a guess.
BodySide? clearestSide(
  Pose pose, {
  required PoseLandmarkType leftFirst,
  required PoseLandmarkType leftVertex,
  required PoseLandmarkType leftLast,
  required PoseLandmarkType rightFirst,
  required PoseLandmarkType rightVertex,
  required PoseLandmarkType rightLast,
}) {
  BodySide? build(PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType c) {
    final first = pose.landmarks[a];
    final vertex = pose.landmarks[b];
    final last = pose.landmarks[c];
    if (!allConfident([first, vertex, last])) return null;
    return BodySide(first!, vertex!, last!);
  }

  final left = build(leftFirst, leftVertex, leftLast);
  final right = build(rightFirst, rightVertex, rightLast);

  if (left == null) return right;
  if (right == null) return left;
  return left.confidence >= right.confidence ? left : right;
}

/// How far [point] sits off the straight line from [start] to [end], as a
/// fraction of that line's length.
///
/// Used for the "is the body a plank or a banana" check. Normalising by body
/// length is what makes the number comparable between a tall user filling the
/// frame and a short one two metres further back; a raw pixel offset is not.
///
/// The sign says which way: positive when the point sags below the line as
/// drawn on screen, negative when it rides above it.
double offsetFromLine(
  PoseLandmark start,
  PoseLandmark point,
  PoseLandmark end,
) {
  final dx = end.x - start.x;
  final dy = end.y - start.y;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length < 1) return 0;

  // Cross product of (end - start) with (point - start), divided by the
  // length: the perpendicular distance, keeping its sign.
  final cross = dx * (point.y - start.y) - dy * (point.x - start.x);
  return cross / (length * length);
}
