import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../models/progress_models.dart';
import '../services/progress_service.dart';
import '../view/profile/achievements_view.dart';

/// The badge wall on the profile screen: nine tiles, three by three.
///
/// Earned ones come first, then the closest locked ones, so the grid reads as
/// "what you have, and what is nearly yours" rather than a list of failures.
/// Anything past the ninth lives behind "xem thêm", which opens the full
/// screen - a profile that scrolls through every badge buries the rest of the
/// page.
class AchievementStrip extends StatefulWidget {
  const AchievementStrip({super.key});

  @override
  State<AchievementStrip> createState() => AchievementStripState();
}

class AchievementStripState extends State<AchievementStrip> {
  List<Achievement>? _achievements;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Public so the profile screen can refresh the strip after a workout.
  Future<void> reload() async {
    try {
      final list = await ProgressService.instance.achievements();
      if (mounted) setState(() => _achievements = list);
    } catch (_) {
      // The rest of the profile works without the strip.
    }
  }

  /// The catalog is bigger than the grid, so a slice is chosen rather than
  /// truncated arbitrarily: everything earned, then whatever is closest.
  static const _tileCount = 9;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final all = _achievements;
    if (all == null || all.isEmpty) return const SizedBox.shrink();

    final unlocked = all.where((a) => a.unlocked).toList();
    final locked = all.where((a) => !a.unlocked).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final shown = [...unlocked, ...locked].take(_tileCount).toList();
    final hidden = all.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('title_achievements'),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              tr('label_unlocked_count')
                  .replaceFirst('{done}', '${unlocked.length}')
                  .replaceFirst('{total}', '${all.length}'),
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: shown.length,
          itemBuilder: (_, i) => _badge(colors, shown[i]),
        ),
        // Only offered when it leads somewhere: with nine or fewer badges the
        // grid already is the whole wall.
        if (hidden > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openWall,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                tr('btn_see_more'),
                style: TextStyle(
                    color: colors.primary1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openWall() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsView()),
    );
    reload();
  }

  Widget _badge(BodifyColors colors, Achievement achievement) {
    return InkWell(
      onTap: _openWall,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: achievement.unlocked
              ? Border.all(color: colors.primary1, width: 1.2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Pure black artwork: tinted, or it disappears in dark mode.
          Image.asset(
            achievement.iconAsset,
            height: 40,
            width: 40,
            color: achievement.unlocked
                ? colors.primary1
                : colors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 5),
          Text(
            achievement.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: achievement.unlocked
                  ? colors.textPrimary
                  : colors.textSecondary,
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          ],
        ),
      ),
    );
  }
}
