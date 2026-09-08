import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Below this a joint is a guess, and drawing it makes the skeleton twitch.
const double _kDrawConfidence = 0.5;

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

/// Draws the detected skeleton over the camera preview.
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
  final List<Pose> poses;
  final Size imageSize;
  final bool mirror;
  final Color color;

  const PoseOverlayPainter({
    required this.poses,
    required this.imageSize,
    required this.mirror,
    this.color = const Color(0xFF9B8CFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || imageSize.width == 0 || imageSize.height == 0) return;

    final scale = (size.width / imageSize.width)
        .clamp(size.height / imageSize.height, double.infinity);
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    Offset project(PoseLandmark landmark) {
      final x = mirror ? imageSize.width - landmark.x : landmark.x;
      return Offset(x * scale + dx, landmark.y * scale + dy);
    }

    final bonePaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);

    for (final pose in poses) {
      for (final bone in _bones) {
        final from = pose.landmarks[bone[0]];
        final to = pose.landmarks[bone[1]];
        if (from == null || to == null) continue;
        if (from.likelihood < _kDrawConfidence ||
            to.likelihood < _kDrawConfidence) {
          continue;
        }
        canvas.drawLine(project(from), project(to), bonePaint);
      }

      for (final bone in _bones) {
        for (final type in bone) {
          final landmark = pose.landmarks[type];
          if (landmark == null || landmark.likelihood < _kDrawConfidence) {
            continue;
          }
          canvas.drawCircle(project(landmark), 5, jointPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(PoseOverlayPainter old) =>
      old.poses != poses ||
      old.imageSize != imageSize ||
      old.mirror != mirror ||
      old.color != color;
}
