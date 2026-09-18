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
///
/// Dot product and acos rather than the difference of two atan2 calls. Both
/// give the same angle for sane input, but this one cannot produce a reflex
/// reading that has to be folded back, and the clamp means floating-point
/// drift just past ±1 returns 0 or 180 instead of NaN. A degenerate frame -
/// two landmarks on top of each other, which happens when ML Kit loses a limb
/// - returns 180 (a straight limb), the reading that counts no rep, rather
/// than a number that could.
double jointAngle(PoseLandmark first, PoseLandmark vertex, PoseLandmark last) {
  final ax = first.x - vertex.x;
  final ay = first.y - vertex.y;
  final bx = last.x - vertex.x;
  final by = last.y - vertex.y;

  final dot = ax * bx + ay * by;
  final magnitude = math.sqrt(ax * ax + ay * ay) * math.sqrt(bx * bx + by * by);
  if (magnitude <= 0) return 180;

  final cosine = (dot / magnitude).clamp(-1.0, 1.0);
  return math.acos(cosine) * 180 / math.pi;
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

/// Which side of the body an angle was read from.
enum BodySideId { left, right }

/// One side of the body: the three landmarks an exercise measures its angle
/// from, plus how well they were seen.
class BodySide {
  final BodySideId id;
  final PoseLandmark first;
  final PoseLandmark vertex;
  final PoseLandmark last;

  const BodySide(this.id, this.first, this.vertex, this.last);

  double get confidence =>
      math.min(first.likelihood, math.min(vertex.likelihood, last.likelihood));

  double get angle => jointAngle(first, vertex, last);
}

/// How much better the other side has to look before the reading switches to
/// it. Without this margin the choice flips back and forth between two arms
/// whose confidences are within noise of each other - and because a
/// foreshortened arm measures a different angle from a side-on one, every flip
/// is a step change in the number the rep counter is watching. That reads as
/// the counter inventing and dropping reps at random.
const double kSideSwitchMargin = 0.15;

/// Picks a side of the body to measure, preferring [current] once chosen.
///
/// A phone on the floor beside someone doing push-ups sees one arm clearly and
/// the other through their torso, and which arm that is depends on which way
/// the user lay down - so the side cannot be fixed at compile time. It can,
/// however, be sticky: [current] is kept until it stops being visible, or the
/// other side is better by [kSideSwitchMargin].
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
  BodySideId? current,
}) {
  BodySide? build(
    BodySideId id,
    PoseLandmarkType a,
    PoseLandmarkType b,
    PoseLandmarkType c,
  ) {
    final first = pose.landmarks[a];
    final vertex = pose.landmarks[b];
    final last = pose.landmarks[c];
    if (!allConfident([first, vertex, last])) return null;
    return BodySide(id, first!, vertex!, last!);
  }

  final left = build(BodySideId.left, leftFirst, leftVertex, leftLast);
  final right = build(BodySideId.right, rightFirst, rightVertex, rightLast);

  if (left == null) return right;
  if (right == null) return left;

  final held = current == BodySideId.left
      ? left
      : (current == BodySideId.right ? right : null);
  if (held != null) {
    final other = held.id == BodySideId.left ? right : left;
    return other.confidence > held.confidence + kSideSwitchMargin
        ? other
        : held;
  }

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
