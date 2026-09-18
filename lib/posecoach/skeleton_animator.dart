import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Below this a joint is a guess, and drawing it makes the skeleton twitch.
const double kDrawConfidence = 0.5;

/// Above this, a joint is confident enough to draw as a solid bone.
///
/// Between [kDrawConfidence] and this, ML Kit has *a* guess but not a good
/// one - an arm crossing the body, someone side-on to the camera. Drawing
/// those as confidently as a clean detection is what read as "loạn": a solid
/// purple line snapping around like it knew where the elbow was. Drawn dashed
/// instead, the same way the reference app hides its own occluded joints -
/// it reads as "roughly here" rather than as a wrong answer.
const double kSolidConfidence = 0.75;

/// Once dashed, confidence has to climb back past [kSolidConfidence] plus
/// this margin's absence - i.e. it falls back to solid only below this,
/// lower than the threshold that made it dashed in the first place. Without
/// the gap, a reading hovering right at the line flips solid/dashed every
/// couple of frames, which is its own kind of chaos.
const double kSolidExitConfidence = 0.55;

class _Joint {
  double x;
  double y;
  double targetX;
  double targetY;
  double opacity = 0;
  double targetOpacity = 0;

  /// Eased confidence, driving the solid/dashed decision below.
  double confidence = 0;
  double targetConfidence = 0;

  /// Whether this joint currently draws as confidently placed. Hysteresis
  /// between [kSolidConfidence] and [kSolidExitConfidence] - see there.
  bool solid = false;

  _Joint(this.x, this.y)
      : targetX = x,
        targetY = y;
}

/// Where the skeleton is *drawn*, as opposed to where ML Kit last saw it.
///
/// ## Why the skeleton looked choppy
///
/// ML Kit answers 10-20 times a second on a phone, and fewer on the emulator.
/// The screen refreshes 60 times a second. Drawing each detection as it
/// arrived meant the skeleton sat still for several screen frames and then
/// jumped - and on top of that every landmark jitters by a few pixels between
/// detections even when the user is motionless, so a still body shimmered.
///
/// This sits between the two rates. Each detection sets a *target*; every
/// screen frame moves the drawn joints part of the way towards it. The result
/// is a skeleton that glides between detections instead of stepping.
///
/// ## Why the follow speed depends on the distance
///
/// One fixed speed forces a bad trade: slow enough to swallow jitter is too
/// slow to keep up with a push-up, and fast enough to keep up passes the
/// jitter straight through. So the speed adapts. A joint a few pixels from its
/// target is almost certainly jitter and eases in slowly; a joint far from its
/// target is a body moving and catches up fast. It is the same idea as the
/// One Euro filter, keyed on distance rather than velocity because distance
/// needs no extra state.
///
/// **Counting never reads from here.** The rep counter gets the raw landmarks:
/// this adds a few tens of milliseconds of lag, which is invisible on screen
/// and would be a real error in a depth measurement.
class SkeletonAnimator extends ChangeNotifier {
  /// Time constant while the joint is close to its target - jitter.
  static const double _slowTau = 0.10;

  /// Time constant while the joint is far from its target - real movement.
  static const double _fastTau = 0.03;

  /// Distance, as a fraction of image height, at which a joint counts as
  /// fully "moving" and gets [_fastTau].
  static const double _fastDistance = 0.04;

  /// How quickly a joint fades in or out when ML Kit gains or loses it.
  /// Popping in and out on a single frame of low confidence was the other
  /// half of the twitching.
  static const double _fadeTau = 0.08;

  final Map<PoseLandmarkType, _Joint> _joints = {};
  Size _imageSize = Size.zero;

  /// The image the landmarks are measured in - the painter needs it to map
  /// them onto the screen.
  Size get imageSize => _imageSize;

  /// Feeds in a new detection, or null when nobody was found.
  void update(Pose? pose, Size imageSize) {
    if (imageSize != _imageSize) {
      // A different frame geometry - a camera flip, a rotation. Positions from
      // the old one mean nothing in the new one, so nothing glides across.
      _joints.clear();
      _imageSize = imageSize;
    }

    if (pose == null) {
      for (final joint in _joints.values) {
        joint.targetOpacity = 0;
      }
      return;
    }

    for (final landmark in pose.landmarks.values) {
      final visible = landmark.likelihood >= kDrawConfidence;
      final joint = _joints.putIfAbsent(
        landmark.type,
        () => _Joint(landmark.x, landmark.y),
      );

      if (visible && joint.opacity < 0.05) {
        // Reappearing: start where it is now, not where it was when it
        // vanished, or it would sweep across the screen to get here.
        joint.x = landmark.x;
        joint.y = landmark.y;
      }
      joint.targetX = landmark.x;
      joint.targetY = landmark.y;
      joint.targetOpacity = visible ? 1 : 0;
      joint.targetConfidence = landmark.likelihood;
    }
  }

  /// Advances every joint by [elapsed] of screen time. Repaints only when
  /// something actually moved, so a settled skeleton costs nothing.
  void advance(Duration elapsed) {
    if (_joints.isEmpty || _imageSize.height <= 0) return;

    // A long gap - the app was backgrounded, a frame was dropped - would
    // otherwise produce one enormous step. Capping it just finishes the move.
    final dt = math.min(elapsed.inMicroseconds / 1e6, 0.1);
    if (dt <= 0) return;

    final fade = 1 - math.exp(-dt / _fadeTau);
    var changed = false;

    for (final joint in _joints.values) {
      final dx = joint.targetX - joint.x;
      final dy = joint.targetY - joint.y;
      final distance = math.sqrt(dx * dx + dy * dy) / _imageSize.height;

      if (distance > 1e-4) {
        final t = (distance / _fastDistance).clamp(0.0, 1.0);
        final tau = _slowTau + (_fastTau - _slowTau) * t;
        final follow = 1 - math.exp(-dt / tau);
        joint.x += dx * follow;
        joint.y += dy * follow;
        changed = true;
      }

      final dOpacity = joint.targetOpacity - joint.opacity;
      if (dOpacity.abs() > 1e-3) {
        joint.opacity += dOpacity * fade;
        changed = true;
      } else {
        joint.opacity = joint.targetOpacity;
      }

      final dConfidence = joint.targetConfidence - joint.confidence;
      if (dConfidence.abs() > 1e-3) {
        // Eased on the same clock as opacity: a confidence reading that
        // spikes for one frame should not be enough to flip a bone solid.
        joint.confidence += dConfidence * fade;
        changed = true;
      } else {
        joint.confidence = joint.targetConfidence;
      }

      if (!joint.solid && joint.confidence >= kSolidConfidence) {
        joint.solid = true;
      } else if (joint.solid && joint.confidence < kSolidExitConfidence) {
        joint.solid = false;
      }
    }

    if (changed) notifyListeners();
  }

  /// Drawn position of [type] in image space, or null if it was never seen.
  Offset? position(PoseLandmarkType type) {
    final joint = _joints[type];
    return joint == null ? null : Offset(joint.x, joint.y);
  }

  /// How opaque to draw [type], 0 (hidden) to 1.
  double opacity(PoseLandmarkType type) => _joints[type]?.opacity ?? 0;

  /// Whether [type] is confident enough to draw as a solid bone, rather than
  /// the dashed "roughly here" of an uncertain one. See [kSolidConfidence].
  bool isSolid(PoseLandmarkType type) => _joints[type]?.solid ?? false;

  /// Drops everything, e.g. when switching lenses.
  void clear() {
    _joints.clear();
    notifyListeners();
  }
}
