import 'dart:math' as math;

import 'package:bodify/posecoach/exercise_processor.dart';
import 'package:bodify/posecoach/exercise_processor_factory.dart';
import 'package:bodify/posecoach/feedback_cue.dart';
import 'package:bodify/posecoach/squat_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// One frame of a squat seen side-on, built from the three things the
/// processor judges: the knee angle, how far the torso leans from vertical,
/// and how far the heel has risen (as a fraction of shin length).
///
/// Only the left side is visible, as it would be for someone standing with
/// their left side to the phone. The shin is vertical, so the knee angle is
/// exactly the angle between thigh and shin.
Pose _frame(
  double kneeAngle, {
  double lean = 20,
  double heelLift = 0,
  double footTilt = 0,
}) {
  const shin = 200.0;
  const knee = (x: 300.0, y: 600.0);
  const ankle = (x: 300.0, y: 800.0);
  final k = kneeAngle * math.pi / 180;
  // Rotating the shin's direction (straight down) by the knee angle puts the
  // hip behind the knee: straight above it at 180, level with it at 90.
  final hip = (x: knee.x - 200 * math.sin(k), y: knee.y + 200 * math.cos(k));
  final l = lean * math.pi / 180;
  final shoulder = (x: hip.x + 250 * math.sin(l), y: hip.y - 250 * math.cos(l));
  // footTilt shifts the toes, standing in for a phone propped off level:
  // the foot looks sloped even when it is flat.
  final heel = (x: ankle.x - 20, y: ankle.y + 10 - heelLift * shin);
  final toes = (x: ankle.x + 60, y: ankle.y + 10 + footTilt * shin);

  PoseLandmark at(PoseLandmarkType type, ({double x, double y}) p) =>
      PoseLandmark(type: type, x: p.x, y: p.y, z: 0, likelihood: 0.99);

  return Pose(landmarks: {
    PoseLandmarkType.leftShoulder: at(PoseLandmarkType.leftShoulder, shoulder),
    PoseLandmarkType.leftHip: at(PoseLandmarkType.leftHip, hip),
    PoseLandmarkType.leftKnee: at(PoseLandmarkType.leftKnee, knee),
    PoseLandmarkType.leftAnkle: at(PoseLandmarkType.leftAnkle, ankle),
    PoseLandmarkType.leftHeel: at(PoseLandmarkType.leftHeel, heel),
    PoseLandmarkType.leftFootIndex: at(PoseLandmarkType.leftFootIndex, toes),
  });
}

/// Feeds [frames] at [fps] and returns every result.
List<ProcessorResult> _play(
  SquatProcessor processor,
  List<Pose> frames, {
  int fps = 15,
}) {
  final t0 = DateTime(2026, 1, 1);
  final step = Duration(microseconds: 1000000 ~/ fps);
  return [
    for (var i = 0; i < frames.length; i++)
      processor.process(frames[i], at: t0.add(step * i)),
  ];
}

/// Standing, down to [bottom] and held, back up - about 1.6 s at 15 fps,
/// an ordinary bodyweight squat.
List<Pose> _squat(
  double bottom, {
  double bottomLean = 30,
  double bottomHeelLift = 0,
  double footTilt = 0,
}) {
  // The way down passes only through angles above the bottom - a quarter
  // squat never goes through 115 on its way to 142.
  final down = <double>[
    170,
    ...<double>[160, 145, 130, 115].where((a) => a > bottom),
    bottom,
  ];
  return [
    for (var i = 0; i < 3; i++) _frame(172, footTilt: footTilt),
    for (final a in down.skip(1)) _frame(a, lean: 25, footTilt: footTilt),
    for (var i = 0; i < 4; i++)
      _frame(bottom,
          lean: bottomLean, heelLift: bottomHeelLift, footTilt: footTilt),
    for (final a in down.reversed.skip(1)) _frame(a, lean: 25, footTilt: footTilt),
    for (var i = 0; i < 3; i++) _frame(172, footTilt: footTilt),
  ];
}

Iterable<FeedbackCue> _cues(List<ProcessorResult> results) =>
    results.map((r) => r.cue).whereType<FeedbackCue>();

void main() {
  test('the synthetic frame measures the knee angle it was built with', () {
    final processor = SquatProcessor();
    for (final angle in <double>[170, 130, 90, 70]) {
      expect(processor.primaryAngle(_frame(angle)), closeTo(angle, 0.01));
    }
  });

  test('a squat to parallel scores 100', () {
    final processor = SquatProcessor();
    final results = _play(processor, _squat(90));
    expect(processor.repCount, 1);
    expect(processor.repScores, [100]);
    expect(results.where((r) => r.repJustScored != null).single.repJustScored,
        100);
  });

  test('a half squat scores 50', () {
    final processor = SquatProcessor();
    _play(processor, _squat(120));
    expect(processor.repScores, [50]);
  });

  test('a quarter squat is cued, not counted', () {
    final processor = SquatProcessor();
    final results = _play(processor, _squat(142));
    expect(processor.repCount, 0);
    expect(_cues(results), contains(FeedbackCue.goDeeper));
  });

  test('filmed from the front the knee barely bends, so nothing counts', () {
    // What a squat looks like head-on: the knee comes towards the camera and
    // the three landmarks stay nearly in line.
    final processor = SquatProcessor();
    final frames = [
      for (var rep = 0; rep < 5; rep++)
        for (final a in <double>[176, 172, 168, 165, 168, 172, 176]) _frame(a),
    ];
    _play(processor, frames);
    expect(processor.repCount, 0);
  });

  test('a bounce faster than 600 ms is refused and the user told why', () {
    final processor = SquatProcessor();
    final frames = [
      for (var i = 0; i < 3; i++) _frame(172),
      _frame(130), _frame(95), _frame(95), _frame(130),
      // Enough standing frames for the smoothed angle to settle back above
      // 160 twice in a row, which is when a rep is closed and judged.
      for (var i = 0; i < 5; i++) _frame(172),
    ];
    final results = _play(processor, frames, fps: 15);
    expect(processor.repCount, 0);
    expect(_cues(results), contains(FeedbackCue.slowDown));
  });

  test('ten squats count ten', () {
    final processor = SquatProcessor();
    _play(processor, [for (var i = 0; i < 10; i++) ..._squat(85)]);
    expect(processor.repCount, 10);
    expect(processor.score, 1000);
  });

  group('form', () {
    test('folding forward at the bottom is cued', () {
      final processor = SquatProcessor();
      final results = _play(processor, _squat(90, bottomLean: 65));
      expect(_cues(results), contains(FeedbackCue.chestUp));
      // Still a rep - the cue corrects form, it does not void the squat.
      expect(processor.repCount, 1);
    });

    test('an ordinary forward lean says nothing', () {
      final processor = SquatProcessor();
      final results = _play(processor, _squat(90, bottomLean: 40));
      expect(_cues(results), isEmpty);
    });

    test('leaning on the way down, above half depth, says nothing', () {
      final processor = SquatProcessor();
      final frames = [
        for (var i = 0; i < 3; i++) _frame(172),
        for (var i = 0; i < 5; i++) _frame(145, lean: 70),
        for (var i = 0; i < 3; i++) _frame(172),
      ];
      expect(_cues(_play(processor, frames)), isNot(contains(FeedbackCue.chestUp)));
    });

    test('heels leaving the floor are cued', () {
      final processor = SquatProcessor();
      final results = _play(processor, _squat(90, bottomHeelLift: 0.15));
      expect(_cues(results), contains(FeedbackCue.heelsDown));
    });

    test('a phone propped off level is not mistaken for lifted heels', () {
      // The foot slopes in the image the whole time, standing included, so
      // relative to standing nothing has changed.
      final processor = SquatProcessor();
      final results = _play(processor, _squat(90, footTilt: -0.2));
      expect(_cues(results), isNot(contains(FeedbackCue.heelsDown)));
    });

    test('with no standing reference, heels are not judged at all', () {
      final processor = SquatProcessor();
      // Starts already crouched with the heel up: there is nothing to compare
      // against, and guessing would cue a fault that may not be there.
      final frames = [
        for (var i = 0; i < 6; i++) _frame(100, heelLift: 0.3),
      ];
      expect(_cues(_play(processor, frames)), isNot(contains(FeedbackCue.heelsDown)));
    });
  });

  test('reset forgets the standing foot along with the count', () {
    final processor = SquatProcessor();
    _play(processor, _squat(90));
    processor.reset();
    expect(processor.repCount, 0);
    final frames = [for (var i = 0; i < 6; i++) _frame(100, heelLift: 0.3)];
    expect(_cues(_play(processor, frames)), isNot(contains(FeedbackCue.heelsDown)));
  });

  test('the catalog name squat_v1 builds this processor', () {
    expect(processorFor('squat_v1'), isA<SquatProcessor>());
    expect(supportsAiCoach('squat_v1'), isTrue);
    expect(processorFor('squat_v1')!.setupHintKey, 'msg_ai_squat_setup');
  });
}
