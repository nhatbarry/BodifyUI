import 'package:bodify/posecoach/exercise_processor.dart';
import 'package:bodify/posecoach/feedback_cue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// A processor whose "camera" is a list of angles, so a rep can be written
/// down as numbers and replayed frame by frame.
///
/// Thresholds are the push-up's (155 / 120 / 95). Smoothing is switched off
/// so each test reads as the angles it lists - the smoothing has its own test.
class _ScriptedProcessor extends ExerciseProcessor {
  double? next;
  final double _smoothing;

  _ScriptedProcessor({double smoothing = 1.0}) : _smoothing = smoothing;

  @override
  String get algorithm => 'test_v1';
  @override
  double get restAngle => 155;
  @override
  double get milestone1Angle => 120;
  @override
  double get milestone2Angle => 95;
  @override
  double get smoothing => _smoothing;

  @override
  double? primaryAngle(Pose pose) => next;

  @override
  FeedbackCue? checkForm(Pose pose, double angle, RepStage stage) => null;
}

final _pose = Pose(landmarks: const {});

/// Replays [angles] at [fps], starting at [start], and returns every result.
List<ProcessorResult> _play(
  _ScriptedProcessor processor,
  List<double?> angles, {
  int fps = 15,
  DateTime? start,
}) {
  final t0 = start ?? DateTime(2026, 1, 1);
  final frame = Duration(microseconds: 1000000 ~/ fps);
  return [
    for (var i = 0; i < angles.length; i++)
      (() {
        processor.next = angles[i];
        return processor.process(_pose, at: t0.add(frame * i));
      })(),
  ];
}

/// Top, down to [bottom] held for [hold] frames, back to top - at 15 fps
/// about a second, a normal push-up.
List<double> _rep(double bottom, {int hold = 3}) => [
      170,
      170,
      170,
      150,
      135,
      120,
      for (var i = 0; i < hold; i++) bottom,
      120,
      135,
      150,
      170,
      170,
      170,
    ];

void main() {
  test('a full-depth rep scores 100', () {
    final p = _ScriptedProcessor();
    _play(p, _rep(85));
    expect(p.repCount, 1);
    expect(p.repScores, [100]);
  });

  test('a rep that only holds the first milestone scores 50', () {
    final p = _ScriptedProcessor();
    _play(p, _rep(110));
    expect(p.repScores, [50]);
  });

  test('one frame of a misplaced elbow cannot turn a 50 into a 100', () {
    final p = _ScriptedProcessor();
    // Held 110, with a single spike to 70 in the middle.
    _play(p, [170, 170, 150, 130, 110, 70, 110, 110, 130, 150, 170, 170]);
    expect(p.repScores, [50]);
  });

  test('touching the milestone for one frame is not a rep', () {
    final p = _ScriptedProcessor();
    final results = _play(p, [170, 170, 150, 130, 115, 130, 150, 170, 170]);
    expect(p.repCount, 0);
    expect(results.map((r) => r.cue), contains(FeedbackCue.goDeeper));
  });

  test('a shallow dip is cued, not counted', () {
    final p = _ScriptedProcessor();
    final results = _play(p, _rep(135));
    expect(p.repCount, 0);
    expect(results.map((r) => r.cue), contains(FeedbackCue.goDeeper));
  });

  test('flexing slightly at the top says nothing', () {
    final p = _ScriptedProcessor();
    final results = _play(p, [170, 170, 150, 148, 150, 170, 170]);
    expect(p.repCount, 0);
    expect(results.every((r) => r.cue == null), isTrue);
  });

  test('getting into position from the floor is not a rep', () {
    final p = _ScriptedProcessor();
    // Starts bent - kneeling, hands down - and pushes up into a plank.
    _play(p, [80, 80, 80, 100, 130, 160, 170, 170]);
    expect(p.repCount, 0);

    // The first real rep after that still counts.
    _play(p, _rep(85), start: DateTime(2026, 1, 1, 0, 1));
    expect(p.repCount, 1);
  });

  test('a rep faster than 400ms is refused and the user told why', () {
    final p = _ScriptedProcessor();
    // At 30 fps: 170 -> 90 held two frames -> 170, 5 frames below rest.
    final results = _play(
      p,
      [170, 170, 170, 130, 90, 90, 130, 170, 170],
      fps: 30,
    );
    expect(p.repCount, 0);
    expect(results.map((r) => r.cue), contains(FeedbackCue.slowDown));
  });

  test('resting on the floor and getting up is not a rep', () {
    final p = _ScriptedProcessor();
    // Down, then ten seconds at the bottom at 15 fps, then up.
    _play(p, [
      170,
      170,
      150,
      120,
      90,
      for (var i = 0; i < 150; i++) 90,
      130,
      170,
      170
    ]);
    expect(p.repCount, 0);
  });

  test('hovering half-bent before starting does not use up the rep', () {
    final p = _ScriptedProcessor();
    // Eight seconds at 145 - below rest, above any milestone - then a rep.
    _play(p, [
      170,
      170,
      for (var i = 0; i < 120; i++) 145,
      120,
      90,
      90,
      90,
      120,
      150,
      170,
      170,
    ]);
    expect(p.repScores, [100]);
  });

  test('frames with no pose are skipped, not treated as a return to the top',
      () {
    final p = _ScriptedProcessor();
    _play(p, [170, 170, 150, 120, 90, null, null, 90, 90, 120, 150, 170, 170]);
    expect(p.repScores, [100]);
  });

  test('ten reps in a row count ten', () {
    final p = _ScriptedProcessor();
    _play(p, [for (var i = 0; i < 10; i++) ..._rep(i.isEven ? 85 : 110)]);
    expect(p.repCount, 10);
    expect(p.score, 5 * 100 + 5 * 50);
  });

  test('with smoothing on, a brisk rep at 15 fps still reaches full depth', () {
    final p = _ScriptedProcessor(smoothing: 0.5);
    // Bottom of 75 lasting three frames - roughly 200ms.
    _play(p, _rep(75));
    expect(p.repScores, [100]);
  });

  test('reset starts a fresh set', () {
    final p = _ScriptedProcessor();
    _play(p, _rep(85));
    p.reset();
    expect(p.repCount, 0);
    expect(p.repScores, isEmpty);
    // And the "start at the top" rule applies again.
    _play(p, [80, 80, 130, 170, 170]);
    expect(p.repCount, 0);
  });
}
