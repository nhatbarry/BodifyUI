import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'feedback_cue.dart';

/// Where in a rep the user currently is.
enum RepStage {
  /// At the top: standing, or arms locked out. Where a rep starts and ends.
  up,

  /// Has held a real bottom on this rep, on the way down or back up.
  down,
}

/// What one frame told us. The camera screen draws from this and nothing else.
class ProcessorResult {
  /// Reps counted so far in this set.
  final int repCount;

  /// Total points scored so far - 50 or 100 per rep.
  final int score;

  final RepStage stage;

  /// How deep the user is right now, 0 (at the top) to 1 (at full depth).
  /// Drives the depth bar, and is why the bar moves smoothly rather than
  /// jumping when a rep completes.
  final double depth;

  /// A rep just completed on this frame, and what it scored. Null otherwise -
  /// the screen uses it to flash the counter, so it must fire once, not for
  /// every frame that follows.
  final int? repJustScored;

  /// Something to say about the user's form, at most one per frame.
  final FeedbackCue? cue;

  /// The smoothed joint angle this frame was judged on, null when the camera
  /// could not see the joints. Shown on screen while tuning: the thresholds
  /// are only guesses until somebody can read what a real rep actually
  /// measures at the top and the bottom.
  final double? angle;

  /// The depth the rep in progress will be scored on - the deepest angle
  /// *held*, not the deepest touched. See [ExerciseProcessor.dwellFrames].
  final double? deepest;

  /// 'L' or 'R' - which arm or leg the angle came from.
  final String? side;

  /// How well the camera saw those joints, 0-1.
  final double? confidence;

  const ProcessorResult({
    required this.repCount,
    required this.score,
    required this.stage,
    required this.depth,
    this.repJustScored,
    this.cue,
    this.angle,
    this.deepest,
    this.side,
    this.confidence,
  });

  /// The most this set could have scored, given the reps actually counted.
  int get maxScore => repCount * 100;

  /// Score as a percentage of what was possible, 0 when nothing counted yet.
  double get scorePercent => repCount == 0 ? 0 : score / maxScore * 100;
}

/// One exercise's rules for counting and scoring reps from a pose.
///
/// A rep is a round trip: from the top position, down to a depth milestone,
/// and back to the top. Every exercise gets its own subclass because the joint
/// that measures the movement differs - an elbow for a push-up, a knee for a
/// squat - and so do the angles that count as deep.
///
/// ## Scoring
///
/// Depth is the thing being judged, so it is the thing scored. Each rep is
/// worth:
///
///   * **100** if it held [milestone2Angle] - full depth.
///   * **50**  if it held [milestone1Angle] but not [milestone2Angle].
///   * **nothing at all** if it never held [milestone1Angle] - it is not
///     counted as a rep either, only cued. Counting a dip of five degrees as a
///     zero-scoring rep would let someone twitch their way to twenty reps, and
///     the number of reps is what the set records.
///
/// ## What stops a rep that did not happen
///
/// Every rule below closes a way the first version counted reps nobody did:
///
///   * **A rep starts at the top.** Nothing is counted until the user has been
///     seen at [restAngle]. Getting into position - kneeling with bent arms,
///     then pushing up into a plank - is half a rep, and used to score as one.
///   * **A bottom has to be held, not touched.** Depth is the deepest angle
///     the arm stayed at for [dwellFrames] frames in a row. One frame of a
///     misplaced elbow cannot lower that, so it can neither turn a 50 into a
///     100 nor make a dip count.
///   * **Too fast is not a rep.** Top to top in under [minRepDuration] is a
///     glitch or a bounce, and the user is told so.
///   * **Stopping at the bottom ends the attempt.** Down for longer than
///     [maxBottomDuration] is someone resting on the floor, and pushing back
///     up afterwards is getting up, not finishing a rep.
abstract class ExerciseProcessor {
  /// Identifies this algorithm to the backend, e.g. 'pushup_v1'. Stored with
  /// every set it scores, so a later change of thresholds cannot rewrite how
  /// an old set was judged.
  String get algorithm;

  /// Angle at the top of the movement. Above it, the user is at rest.
  double get restAngle;

  /// First depth milestone - a rep that holds this is worth 50.
  double get milestone1Angle;

  /// Full depth - a rep that holds this is worth 100.
  double get milestone2Angle;

  /// How many frames in a row must read "at the top" before a rep is closed.
  int get debounceFrames => 2;

  /// How many frames in a row an angle must be held to count as reached.
  ///
  /// Two, not more, because the angle is already smoothed (see [smoothing]):
  /// the average carries the previous frame in it, so a one-frame spike is
  /// halved before this even sees it and holding two frames removes most of
  /// what is left. Asking for more starts costing honest reps instead - on a
  /// phone detecting at 10-15 frames a second, the bottom of a brisk push-up
  /// only lasts two or three frames.
  int get dwellFrames => 2;

  /// The fastest a real repetition can be, top to top.
  ///
  /// Below this it is noise, a camera glitch, or somebody bouncing their
  /// elbows without moving their chest.
  Duration get minRepDuration => const Duration(milliseconds: 400);

  /// The longest the user can stay down before the attempt is abandoned.
  ///
  /// Measured from the bottom, not from the top: hovering half-bent at the
  /// top while getting set is not a slow rep and must not use this up.
  Duration get maxBottomDuration => const Duration(seconds: 6);

  /// A dip shallower than this below [restAngle] is not worth a "go deeper" -
  /// arms flex a little at the top without anyone attempting a rep.
  double get noticeableDip => 15;

  /// The angle this exercise counts from, or null when the camera cannot see
  /// the joints well enough to say. A null frame is skipped, not scored.
  double? primaryAngle(Pose pose);

  /// Which side the last [primaryAngle] came from and how well it was seen -
  /// display only, so the tuning readout can say where the number came from.
  String? get activeSide => null;
  double? get activeConfidence => null;

  /// How much of each frame's reading to believe, against the running value.
  ///
  /// ML Kit can misplace an elbow by thirty degrees on a single frame, and the
  /// raw number jitters even when the arm is still. Averaging costs a little
  /// lag - at 0.5 roughly one frame's worth - and buys a number that only
  /// moves when the arm does.
  double get smoothing => 0.5;

  /// Anything worth telling the user about their form on this frame.
  FeedbackCue? checkForm(Pose pose, double angle, RepStage stage);

  // ---- state ----

  RepStage _stage = RepStage.up;
  int _reps = 0;
  int _score = 0;
  double _depth = 0;

  /// The running, smoothed angle - what every decision below is made on.
  double? _smoothed;

  /// Consecutive frames at or above [restAngle].
  int _framesUp = 0;

  /// Whether the user has been seen at the top yet. Nothing counts until then.
  bool _hasBeenAtTop = false;

  /// When the current attempt left the top. Null while resting at the top.
  DateTime? _repStartedAt;

  /// When the current attempt first held [milestone1Angle].
  DateTime? _bottomReachedAt;

  /// The last [dwellFrames] angles of this attempt, oldest first.
  final List<double> _recent = [];

  /// Deepest angle held for [dwellFrames] frames on this attempt.
  double _heldDeepest = double.infinity;

  /// Deepest single reading on this attempt - only used to tell a real dip
  /// from standing still, never to score.
  double _touchedDeepest = double.infinity;

  int get repCount => _reps;
  int get score => _score;
  RepStage get stage => _stage;

  /// Per-rep scores in order, which is what the set stores.
  final List<int> repScores = [];

  /// Feed one detected pose in and get back what to draw.
  ///
  /// [at] is the moment the frame was captured, and exists for tests; the
  /// camera leaves it out.
  ProcessorResult process(Pose pose, {DateTime? at}) {
    final raw = primaryAngle(pose);
    if (raw == null) {
      // Nothing legible this frame. Hold everything where it was rather than
      // guessing - a dropped frame is not a rep, and it is not a miss either.
      return ProcessorResult(
        repCount: _reps,
        score: _score,
        stage: _stage,
        depth: _depth,
        deepest: _heldOrNull,
      );
    }

    final now = at ?? DateTime.now();
    _smoothed =
        _smoothed == null ? raw : _smoothed! + smoothing * (raw - _smoothed!);
    final angle = _smoothed!;
    _depth = _depthFraction(angle);

    _framesUp = angle >= restAngle ? _framesUp + 1 : 0;
    if (_framesUp >= debounceFrames) _hasBeenAtTop = true;

    // Leaving the top starts an attempt.
    if (_hasBeenAtTop && _repStartedAt == null && angle < restAngle) {
      _repStartedAt = now;
    }

    if (_repStartedAt != null) _track(angle, now);

    int? justScored;
    FeedbackCue? cue;

    if (_repStartedAt != null && _framesUp >= debounceFrames) {
      (justScored, cue) = _closeAttempt(now);
    }

    return ProcessorResult(
      repCount: _reps,
      score: _score,
      stage: _stage,
      depth: _depth,
      repJustScored: justScored,
      cue: cue ?? (justScored == null ? checkForm(pose, angle, _stage) : null),
      angle: angle,
      deepest: _heldOrNull,
      side: activeSide,
      confidence: activeConfidence,
    );
  }

  /// Folds one frame into the attempt in progress.
  void _track(double angle, DateTime now) {
    if (angle < _touchedDeepest) _touchedDeepest = angle;

    _recent.add(angle);
    if (_recent.length > dwellFrames) _recent.removeAt(0);
    if (_recent.length < dwellFrames) return;

    // The shallowest of the last few frames is the depth all of them held.
    var held = _recent.first;
    for (final a in _recent) {
      if (a > held) held = a;
    }
    if (held < _heldDeepest) _heldDeepest = held;

    if (_stage == RepStage.up && _heldDeepest <= milestone1Angle) {
      _stage = RepStage.down;
      _bottomReachedAt = now;
    }
  }

  /// Back at the top: decides whether what just happened was a rep, and
  /// resets for the next attempt either way.
  (int?, FeedbackCue?) _closeAttempt(DateTime now) {
    final held = _heldDeepest;
    final dipped = _touchedDeepest <= restAngle - noticeableDip;
    final duration = now.difference(_repStartedAt!);
    final bottomAt = _bottomReachedAt;

    _repStartedAt = null;
    _bottomReachedAt = null;
    _recent.clear();
    _heldDeepest = double.infinity;
    _touchedDeepest = double.infinity;
    _stage = RepStage.up;

    if (held > milestone1Angle) {
      // Came back up without ever holding a real bottom. Not a rep, but a dip
      // the user clearly meant is worth a word.
      return (null, dipped ? FeedbackCue.goDeeper : null);
    }
    if (duration < minRepDuration) {
      return (null, FeedbackCue.slowDown);
    }
    if (bottomAt != null && now.difference(bottomAt) > maxBottomDuration) {
      // They stopped on the floor and got up. Saying nothing is right: there
      // is no form fault to correct in resting.
      return (null, null);
    }

    final earned = held <= milestone2Angle ? 100 : 50;
    _reps += 1;
    _score += earned;
    repScores.add(earned);
    return (earned, null);
  }

  double? get _heldOrNull =>
      _heldDeepest == double.infinity ? null : _heldDeepest;

  /// Current angle mapped onto 0..1 between the top position and full depth,
  /// so the bar fills as the user descends and the two milestones sit at fixed
  /// marks on it.
  double _depthFraction(double angle) {
    final span = restAngle - milestone2Angle;
    if (span <= 0) return 0;
    final fraction = (restAngle - angle) / span;
    return fraction.clamp(0.0, 1.0);
  }

  /// Where the milestones sit on that same 0..1 scale, for drawing the marks.
  double get milestone1Fraction =>
      ((restAngle - milestone1Angle) / (restAngle - milestone2Angle))
          .clamp(0.0, 1.0);

  /// Forget everything and start a fresh set.
  void reset() {
    _stage = RepStage.up;
    _reps = 0;
    _score = 0;
    _depth = 0;
    _smoothed = null;
    _framesUp = 0;
    _hasBeenAtTop = false;
    _repStartedAt = null;
    _bottomReachedAt = null;
    _recent.clear();
    _heldDeepest = double.infinity;
    _touchedDeepest = double.infinity;
    repScores.clear();
  }
}
