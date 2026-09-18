import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'skeleton_animator.dart';

/// Which landmarks to join up. Face landmarks are left out on purpose: ML Kit
/// returns eleven of them and they add nothing to judging a push-up, but they
/// do turn the head into a scribble.
const List<List<PoseLandmarkType>> _bones = [
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
  [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
  [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
  [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
  [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
  [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
];

/// Every landmark some bone touches, once each.
final List<PoseLandmarkType> _joints = {
  for (final bone in _bones) ...bone,
}.toList();

/// Draws the skeleton over the camera preview.
///
/// Positions come from a [SkeletonAnimator], not straight from ML Kit, and
/// the painter repaints when the animator says so rather than when the screen
/// rebuilds. That second part matters as much as the first: the camera screen
/// used to call setState for every detection, rebuilding the whole HUD just to
/// move a few lines.
///
/// ## Why the coordinate maths is not just a scale factor
///
/// ML Kit reports landmarks in the *image's* pixel space, and the preview is
/// drawn with BoxFit.cover - the image is scaled up until it fills the widget
/// and the overflow is cropped off each side. Scaling x and y independently by
/// the widget's dimensions therefore skews the skeleton away from the body it
/// is tracing. Using one scale (the larger of the two) and centring the
/// leftover is what keeps the wrist dot on the wrist.
///
/// The front camera adds a second correction: its preview is mirrored, so the
/// landmarks have to be mirrored too or the skeleton reaches out with the
/// wrong arm.
class PoseOverlayPainter extends CustomPainter {
  final SkeletonAnimator skeleton;
  final bool mirror;
  final Color color;

  PoseOverlayPainter({
    required this.skeleton,
    required this.mirror,
    this.color = const Color(0xFF9B8CFF),
  }) : super(repaint: skeleton);

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = skeleton.imageSize;
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final scale = math.max(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    Offset project(Offset point) {
      final x = mirror ? imageSize.width - point.dx : point.dx;
      return Offset(x * scale + dx, point.dy * scale + dy);
    }

    final bonePaint = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final jointPaint = Paint();

    for (final bone in _bones) {
      final from = skeleton.position(bone[0]);
      final to = skeleton.position(bone[1]);
      if (from == null || to == null) continue;

      // A bone is as visible as its fainter end, so it fades out with the
      // joint rather than hanging on to a point that is no longer there.
      final opacity = math.min(
        skeleton.opacity(bone[0]),
        skeleton.opacity(bone[1]),
      );
      if (opacity < 0.02) continue;

      // A bone is only as sure as its less sure end. Drawn dashed rather than
      // hidden: the joint is still roughly there, and a dashed line says so
      // instead of either lying with full confidence or vanishing outright.
      final solid = skeleton.isSolid(bone[0]) && skeleton.isSolid(bone[1]);

      bonePaint.color = color.withValues(alpha: color.a * opacity);
      final start = project(from);
      final end = project(to);
      if (solid) {
        canvas.drawLine(start, end, bonePaint);
      } else {
        _drawDashedLine(canvas, start, end, bonePaint);
      }
    }

    for (final type in _joints) {
      final point = skeleton.position(type);
      final opacity = skeleton.opacity(type);
      if (point == null || opacity < 0.02) continue;

      jointPaint.color = Colors.white.withValues(alpha: 0.9 * opacity);
      canvas.drawCircle(project(point), 5, jointPaint);
    }
  }

  /// Draws [from]-[to] as alternating dashes, for a bone whose ends are seen
  /// but not confidently. Manual, because Canvas has no dashed stroke - only
  /// `dart:ui`'s solid [Canvas.drawLine].
  static void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double dashLength = 10,
    double gapLength = 7,
  }) {
    final total = (to - from).distance;
    if (total < 1) return;

    final direction = (to - from) / total;
    var drawn = 0.0;
    var dash = true;
    while (drawn < total) {
      final step = math.min(dash ? dashLength : gapLength, total - drawn);
      if (dash) {
        canvas.drawLine(
          from + direction * drawn,
          from + direction * (drawn + step),
          paint,
        );
      }
      drawn += step;
      dash = !dash;
    }
  }

  @override
  bool shouldRepaint(PoseOverlayPainter old) =>
      old.skeleton != skeleton || old.mirror != mirror || old.color != color;
}
