import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'feedback_cue.dart';

/// Where in a rep the user currently is.
enum RepStage {
  /// At the top: standing, or arms locked out. Where a rep starts and ends.
  up,

  /// Past the first depth milestone, on the way down or back up.
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

  const ProcessorResult({
    required this.repCount,
    required this.score,
    required this.stage,
    required this.depth,
    this.repJustScored,
    this.cue,
  });

  /// The most this set could have scored, given the reps actually counted.
  int get maxScore => repCount * 100;

  /// Score as a percentage of what was possible, 0 when nothing counted yet.
  double get scorePercent => repCount == 0 ? 0 : score / maxScore * 100;
}

/// One exercise's rules for counting and scoring reps from a pose.
///
/// A rep is a round trip: from the top position, down past a depth milestone,
/// and back to the top. Every exercise gets its own subclass because the joint
/// that measures the movement differs - an elbow for a push-up, a knee for a
/// squat - and so do the angles that count as deep.
///
/// ## Scoring
///
/// Depth is the thing being judged, so it is the thing scored. Each rep is
/// worth:
///
///   * **100** if it passed [milestone2Angle] - full depth.
///   * **50**  if it passed [milestone1Angle] but not [milestone2Angle].
///   * **nothing at all** if it never reached [milestone1Angle] - it is not
///     counted as a rep either, only cued. Counting a dip of five degrees as a
///     zero-scoring rep would let someone twitch their way to twenty reps, and
///     the number of reps is what the set records.
///
/// ## Why consecutive frames rather than a smoothed angle
///
/// A single frame where ML Kit misplaces an elbow can swing the angle by
/// thirty degrees. Averaging over a window would hide that, but it also lags -
/// and lag on a fast set means missed reps. Requiring the same reading on
/// [debounceFrames] frames in a row rejects the spike without delaying anyone
/// who is actually moving.
abstract class ExerciseProcessor {
  /// Identifies this algorithm to the backend, e.g. 'pushup_v1'. Stored with
  /// every set it scores, so a later change of thresholds cannot rewrite how
  /// an old set was judged.
  String get algorithm;

  /// Angle at the top of the movement. Above it, the user is at rest.
  double get restAngle;

  /// First depth milestone - a rep that gets here is worth 50.
  double get milestone1Angle;

  /// Full depth - a rep that gets here is worth 100.
  double get milestone2Angle;

  /// How many frames in a row must agree before a stage change is believed.
  int get debounceFrames => 2;

  /// The angle this exercise counts from, or null when the camera cannot see
  /// the joints well enough to say. A null frame is skipped, not scored.
  double? primaryAngle(Pose pose);

  /// Anything worth telling the user about their form on this frame.
  FeedbackCue? checkForm(Pose pose, double angle, RepStage stage);

  // ---- state ----

  RepStage _stage = RepStage.up;
  int _reps = 0;
  int _score = 0;
  int _framesAgreeing = 0;
  RepStage? _pendingStage;
  double _depth = 0;

  /// Deepest point reached since leaving the top, as an angle. Reset at the
  /// top of every rep; this is what the rep is scored on, not the angle at the
  /// moment the user happens to come back up.
  double _deepestAngle = double.infinity;

  /// True once the user has gone deep enough on this rep for it to count.
  bool _passedFirstMilestone = false;

  int get repCount => _reps;
  int get score => _score;
  RepStage get stage => _stage;

  /// Per-rep scores in order, which is what the set stores.
  final List<int> repScores = [];

  /// Feed one detected pose in and get back what to draw.
  ProcessorResult process(Pose pose) {
    final angle = primaryAngle(pose);
    if (angle == null) {
      // Nothing legible this frame. Hold everything where it was rather than
      // guessing - a dropped frame is not a rep, and it is not a miss either.
      return ProcessorResult(
        repCount: _reps,
        score: _score,
        stage: _stage,
        depth: _depth,
      );
    }

    _depth = _depthFraction(angle);
    if (angle < _deepestAngle) _deepestAngle = angle;

    int? justScored;

    final observed = angle <= milestone1Angle
        ? RepStage.down
        : (angle >= restAngle ? RepStage.up : _stage);

    if (observed != _stage) {
      // Same reading as last frame, or start counting again from one.
      _framesAgreeing = observed == _pendingStage ? _framesAgreeing + 1 : 1;
      _pendingStage = observed;

      if (_framesAgreeing >= debounceFrames) {
        if (observed == RepStage.down) {
          _passedFirstMilestone = true;
        } else {
          justScored = _completeRep();
        }
        _stage = observed;
        _framesAgreeing = 0;
        _pendingStage = null;
      }
    } else {
      _framesAgreeing = 0;
      _pendingStage = null;

      // Back at the top without ever having gone deep: the user dipped and
      // came back. Not a rep, but worth saying something about.
      if (_stage == RepStage.up &&
          angle >= restAngle &&
          !_passedFirstMilestone &&
          _deepestAngle < restAngle - 15 &&
          _deepestAngle != double.infinity) {
        _deepestAngle = double.infinity;
        return ProcessorResult(
          repCount: _reps,
          score: _score,
          stage: _stage,
          depth: _depth,
          cue: FeedbackCue.goDeeper,
        );
      }
    }

    return ProcessorResult(
      repCount: _reps,
      score: _score,
      stage: _stage,
      depth: _depth,
      repJustScored: justScored,
      cue: justScored == null ? checkForm(pose, angle, _stage) : null,
    );
  }

  /// Scores the rep that just ended and resets for the next one.
  int _completeRep() {
    final earned = _deepestAngle <= milestone2Angle ? 100 : 50;
    _reps += 1;
    _score += earned;
    repScores.add(earned);

    _deepestAngle = double.infinity;
    _passedFirstMilestone = false;
    return earned;
  }

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
    _framesAgreeing = 0;
    _pendingStage = null;
    _depth = 0;
    _deepestAngle = double.infinity;
    _passedFirstMilestone = false;
    repScores.clear();
  }
}
