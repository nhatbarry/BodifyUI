/// What the camera screen hands back when the user finishes a set.
///
/// Deliberately just the numbers: the screen counts and scores, and the caller
/// decides what to do with the result - which set it belongs to, whether to
/// record it at all. The camera screen writes nothing itself, so backing out
/// of it cannot leave a half-written set behind.
class AiSetResult {
  /// Reps that actually counted - ones that reached at least the first depth
  /// milestone. A dip that never got there is not in here.
  final int reps;

  /// One score per rep, in order: 50 or 100 by depth reached.
  final List<int> repScores;

  /// The algorithm that did the counting, stored with the set so the history
  /// records how it was judged.
  final String algorithm;

  const AiSetResult({
    required this.reps,
    required this.repScores,
    required this.algorithm,
  });

  int get score => repScores.fold(0, (sum, value) => sum + value);

  double get scorePercent => reps == 0 ? 0 : score / (reps * 100) * 100;
}
