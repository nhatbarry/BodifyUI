import 'exercise_processor.dart';
import 'pushup_processor.dart';
import 'squat_processor.dart';

/// Builds the processor an exercise's `ai_algorithm` names.
///
/// The catalog stores the name, this decides what it means. Anything
/// unrecognised - including an algorithm shipped in a newer build than the one
/// running - returns null and the exercise is simply treated as one the camera
/// cannot score yet. That is the whole reason the column is free text: adding
/// a fourth algorithm should be a new branch here, not a database migration.
ExerciseProcessor? processorFor(String? algorithm) => switch (algorithm) {
      'pushup_v1' => PushUpProcessor(),
      'squat_v1' => SquatProcessor(),
      _ => null,
    };

/// Whether the camera can score this exercise at all. What the "AI" tag and
/// the "train with AI" button key off.
bool supportsAiCoach(String? algorithm) => processorFor(algorithm) != null;
