import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../models/progress_models.dart';
import '../services/progress_service.dart';
import '../view/profile/achievements_view.dart';

/// The badge wall on the profile screen: up to nine responsive tiles.
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
    final type = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            Text(
              tr('title_achievements'),
              style: type.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              tr('label_unlocked_count')
                  .replaceFirst('{done}', '${unlocked.length}')
                  .replaceFirst('{total}', '${all.length}'),
              style: type.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            final scale = scaler.scale(12) / 12;
            const gap = 10.0;
            final minimumWidth = 104 + math.max(0, scale - 1) * 44;
            final columns =
                ((constraints.maxWidth + gap) / (minimumWidth + gap))
                    .floor()
                    .clamp(1, 3);
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final labelStyle = _badgeLabelStyle(colors, true);
            var labelHeight = 0.0;
            for (final achievement in shown) {
              final painter = TextPainter(
                text: TextSpan(text: achievement.name, style: labelStyle),
                textScaler: scaler,
                textDirection: Directionality.of(context),
                maxLines: 2,
                ellipsis: '…',
              )..layout(maxWidth: math.max(1.0, tileWidth - 24 - 2.4));
              labelHeight = math.max(labelHeight, painter.height);
              painter.dispose();
            }
            // Reserve the actual scaled two-line label height instead of a
            // square ratio that overflows when the Android font size grows.
            // Container borders add padding too: reserve both 1.2 dp edges.
            final tileHeight = math.max(
              112.0,
              (40 + 8 + 24 + 2.4 + labelHeight).ceilToDouble(),
            );
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                mainAxisExtent: tileHeight,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) => _badge(colors, shown[i]),
            );
          },
        ),
        // Only offered when it leads somewhere: with nine or fewer badges the
        // grid already is the whole wall.
        if (hidden > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openWall,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              child: Text(
                tr('btn_see_more'),
                style: type.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
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
    if (mounted) reload();
  }

  TextStyle _badgeLabelStyle(BodifyColors colors, bool unlocked) =>
      (Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12))
          .copyWith(
        color: unlocked ? colors.textPrimary : colors.textSecondary,
        height: 1.25,
        fontWeight: FontWeight.w600,
      );

  Widget _badge(BodifyColors colors, Achievement achievement) {
    return InkWell(
      onTap: _openWall,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 8),
            Text(
              achievement.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _badgeLabelStyle(colors, achievement.unlocked),
            ),
          ],
        ),
      ),
    );
  }
}
