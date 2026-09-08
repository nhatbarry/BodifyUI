import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../posecoach/exercise_processor_factory.dart';

/// Marks an exercise the camera can count and score.
///
/// Driven by whether a processor actually exists for the algorithm, not by the
/// column being non-null: the catalog can name an algorithm this build does
/// not ship yet, and promising AI on an exercise that then falls back to the
/// manual dialog is worse than not offering it.
///
/// Returns an empty box for everything else, so callers can drop it into a Row
/// unconditionally instead of writing the same `if` at every call site.
class AiBadge extends StatelessWidget {
  final String? algorithm;
  final double fontSize;

  const AiBadge({super.key, required this.algorithm, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    if (!supportsAiCoach(algorithm)) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primary1.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.primary1.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, size: fontSize + 2, color: colors.primary1),
          const SizedBox(width: 2),
          Text(
            tr('label_ai_tag'),
            style: TextStyle(
              color: colors.primary1,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
