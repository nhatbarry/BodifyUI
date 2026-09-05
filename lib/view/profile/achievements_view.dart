import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/progress_models.dart';
import '../../services/progress_service.dart';

/// The badge wall.
///
/// Locked badges are shown too, greyed out and with a progress bar. A badge
/// you can see yourself approaching is the reason to come back; hiding it
/// until it unlocks throws that away.
class AchievementsView extends StatefulWidget {
  const AchievementsView({super.key});

  @override
  State<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<AchievementsView> {
  List<Achievement>? _achievements;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ProgressService.instance.achievements();
      if (mounted) setState(() => _achievements = list);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '$e');
      }
    }
  }

  /// Formats a figure without a trailing `.0` - "7 workouts", not "7.0".
  static String _num(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  void _showDetail(Achievement achievement) {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              // The Bodymovin export only plays for something actually earned.
              // Animating a locked badge would celebrate nothing.
              child: achievement.unlocked
                  ? Lottie.asset(
                      'assets/img/achievements/Trophy.json',
                      repeat: false,
                    )
                  : Image.asset(
                      achievement.iconAsset,
                      // The source art is a solid black silhouette on
                      // transparency - drawn untinted it vanishes into a dark
                      // background. Tinting is what these icons are for.
                      color: colors.textSecondary.withValues(alpha: 0.45),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
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
            const SizedBox(height: 12),
            Text(
              achievement.unlocked
                  ? tr('msg_achievement_unlocked')
                  : '${_num(achievement.currentValue ?? 0)} / '
                      '${_num(achievement.requirementValue)} '
                      '${translateUnit(achievement.requirementUnit)}',
              style: TextStyle(
                color: achievement.unlocked
                    ? const Color(0xFF27AE60)
                    : colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('btn_nice'),
                style: TextStyle(color: colors.primary1)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final list = _achievements;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          tr('title_achievements'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: _error != null
          ? _buildError(colors)
          : list == null
              ? Center(
                  child: CircularProgressIndicator(color: colors.primary1))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildGrid(colors, list),
                ),
    );
  }

  Widget _buildError(BodifyColors colors) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: Text(tr('btn_retry'))),
          ],
        ),
      );

  Widget _buildGrid(BodifyColors colors, List<Achievement> list) {
    final unlockedCount = list.where((a) => a.unlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          tr('label_unlocked_count')
              .replaceFirst('{done}', '$unlockedCount')
              .replaceFirst('{total}', '${list.length}'),
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) =>
              _badge(colors, list[index]),
        ),
      ],
    );
  }

  Widget _badge(BodifyColors colors, Achievement achievement) {
    return InkWell(
      onTap: () => _showDetail(achievement),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: achievement.unlocked
              ? Border.all(color: colors.primary1, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Locked badges keep their shape and lose their colour, so the
            // wall reads as "not yet" rather than "empty".
            Image.asset(
              achievement.iconAsset,
              height: 46,
              width: 46,
              // Pure black artwork: it has to be tinted or it disappears in
              // dark mode. Earned badges take the brand colour, locked ones
              // the muted one, so the wall reads as "not yet" at a glance.
              color: achievement.unlocked
                  ? colors.primary1
                  : colors.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: achievement.unlocked
                    ? colors.textPrimary
                    : colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            if (!achievement.unlocked)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.progress,
                  minHeight: 4,
                  backgroundColor: colors.surface,
                  valueColor: AlwaysStoppedAnimation(colors.primary1),
                ),
              )
            else
              Icon(Icons.check_circle,
                  size: 14, color: colors.primary1),
          ],
        ),
      ),
    );
  }
}
