import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../models/progress_models.dart';
import '../services/progress_service.dart';
import '../view/exercise/exercise_detail_view.dart';
import 'exercise_thumbnail.dart';

/// The last few exercises the user actually trained, with that day's numbers.
///
/// Replaces the session-by-session history on the profile. "Bench Press, 3 sets,
/// 1.2 tấn, hôm qua" is what somebody wants to see at a glance; a row saying
/// "Buổi tập · 42 phút" made them open it to find out what was in it.
///
/// The list is grouped per exercise server-side, so an exercise trained four
/// times this week appears once, at its latest date.
class RecentExercisesSection extends StatefulWidget {
  const RecentExercisesSection({super.key});

  @override
  State<RecentExercisesSection> createState() => RecentExercisesSectionState();
}

class RecentExercisesSectionState extends State<RecentExercisesSection> {
  List<RecentExercise>? _items;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Public so the profile can refresh it after a workout finishes.
  Future<void> reload() async {
    try {
      final items = await ProgressService.instance.recentExercises();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // The rest of the profile stands without this section.
      if (mounted) setState(() => _items = const []);
    }
  }

  /// "Hôm nay" / "Hôm qua" / a date. A bare date for yesterday makes the
  /// reader do arithmetic to answer "was that recent?".
  String _when(DateTime day) {
    final today = DateTime.now();
    final justDate = DateTime(day.year, day.month, day.day);
    final justToday = DateTime(today.year, today.month, today.day);
    final difference = justToday.difference(justDate).inDays;

    if (difference == 0) return tr('label_today');
    if (difference == 1) return tr('label_yesterday');
    return '${day.day}/${day.month}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('title_recent_exercises'),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (items == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colors.primary1),
            ),
          )
        else if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tr('msg_no_recent_exercises'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          )
        else
          for (final item in items) ...[
            _row(colors, item),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _row(BodifyColors colors, RecentExercise item) {
    final type = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseDetailView(exerciseId: item.exerciseId),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackedDate = constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(12) > 16.8;
            final date = Text(
              _when(item.day),
              style: type.bodySmall?.copyWith(color: colors.textSecondary),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Preserve the explorer/calendar thumbnail cache identity.
                ExerciseThumbnail(
                  url: item.thumbnailUrl,
                  cacheKey: 'thumb-${item.exerciseId}',
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name ?? '#${item.exerciseId}',
                        maxLines: stackedDate ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.summary,
                        style: type.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                      if (stackedDate) ...[const SizedBox(height: 6), date],
                    ],
                  ),
                ),
                if (!stackedDate) ...[const SizedBox(width: 12), date],
              ],
            );
          },
        ),
      ),
    );
  }
}
