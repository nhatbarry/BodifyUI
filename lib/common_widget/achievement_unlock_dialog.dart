import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../models/progress_models.dart';
import '../services/progress_service.dart';

/// Celebrates badges the moment they are earned.
///
/// The backend decides unlocks when a session is finished, so the app cannot
/// know one happened without asking. `showNewUnlocks` compares the catalog
/// before and after and shows only what actually changed - the alternative,
/// firing on "the count went up", would celebrate again every time the screen
/// reloaded.
class AchievementUnlockDialog extends StatelessWidget {
  final Achievement achievement;

  const AchievementUnlockDialog({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      backgroundColor: colors.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            child: Lottie.asset(
              'assets/img/achievements/Trophy.json',
              repeat: false,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('msg_achievement_unlocked'),
            style: const TextStyle(
              color: Color(0xFF27AE60),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (achievement.description != null) ...[
            const SizedBox(height: 6),
            Text(
              achievement.description!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text(tr('btn_nice'), style: TextStyle(color: colors.primary1)),
        ),
      ],
    );
  }
}

/// A snapshot of which badges were already earned, taken before an action that
/// might earn more.
Future<Set<int>> unlockedAchievementIds() async {
  try {
    final list = await ProgressService.instance.achievements();
    return list.where((a) => a.unlocked).map((a) => a.achievementId).toSet();
  } catch (_) {
    // A failure here must not stop the workout being finished. The cost is a
    // celebration the user misses, not a lost record.
    return const {};
  }
}

/// Shows one dialog per badge earned since [before] was taken.
///
/// Awaited one at a time so two unlocks in the same session are two moments
/// rather than one dialog stacked on another.
Future<void> showNewUnlocks(BuildContext context, Set<int> before) async {
  List<Achievement> now;
  try {
    now = await ProgressService.instance.achievements();
  } catch (_) {
    return;
  }

  final earned = now
      .where((a) => a.unlocked && !before.contains(a.achievementId))
      .toList();

  for (final achievement in earned) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AchievementUnlockDialog(achievement: achievement),
    );
  }
}
