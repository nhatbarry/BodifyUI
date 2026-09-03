import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/api_exception.dart';
import '../core/app_strings.dart';
import '../models/workout_session_models.dart';
import '../services/workout_session_service.dart';

/// How far back "latest" reaches.
enum HistoryRange {
  week(7),
  month(30),
  year(365);

  const HistoryRange(this.days);

  final int days;

  String get label => switch (this) {
        HistoryRange.week => tr('range7Days'),
        HistoryRange.month => tr('range1Month'),
        HistoryRange.year => tr('range1Year'),
      };
}

/// Recent workouts on the home screen.
///
/// Self-contained: it owns its own range filter and its own loading, so the
/// home screen does not have to thread state through for a card it only
/// displays. Totals come from the server rather than being summed here - the
/// alternative is pulling every set of every session to render one line.
class LatestWorkoutSection extends StatefulWidget {
  const LatestWorkoutSection({super.key});

  @override
  State<LatestWorkoutSection> createState() => _LatestWorkoutSectionState();
}

class _LatestWorkoutSectionState extends State<LatestWorkoutSection> {
  HistoryRange _range = HistoryRange.week;
  WorkoutHistory? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final today = DateTime.now();
    try {
      final history = await WorkoutSessionService.instance.history(
        from: today.subtract(Duration(days: _range.days - 1)),
        to: today,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '$e';
        _loading = false;
      });
    }
  }

  void _select(HistoryRange range) {
    if (range == _range) return;
    setState(() => _range = range);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('latestWorkout'),
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
            for (final range in HistoryRange.values) _rangeChip(range),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
                child: CircularProgressIndicator(color: colors.primary1)),
          )
        else if (_error != null)
          _message(_error!)
        else if ((_history?.items ?? const []).isEmpty)
          _message(tr('noWorkoutsInRange'))
        else ...[
          _totalsLine(_history!.totals),
          const SizedBox(height: 8),
          for (final session in _history!.items) _SessionRow(session: session),
        ],
      ],
    );
  }

  Widget _rangeChip(HistoryRange range) {
    final colors = context.colors;
    final selected = range == _range;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: () => _select(range),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? colors.primary1 : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            range.label,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.textSecondary,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      );

  Widget _totalsLine(HistoryTotals totals) {
    final colors = context.colors;
    return Text(
      '${totals.sessionCount} ${tr("sessionsLabel")}'
      ' · ${formatDuration(totals.totalDurationSeconds)}'
      ' · ${totals.totalSets} ${tr("setsLabel")}'
      ' · ${formatVolume(totals.totalVolumeKg)}',
      style: TextStyle(color: colors.textSecondary, fontSize: 12),
    );
  }
}

/// "1h 20m", or "45m" when there is no hour to show.
String formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// Tonnes once the number stops being readable in kilograms.
String formatVolume(double kg) =>
    kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)}t' : '${kg.round()}kg';

class _SessionRow extends StatelessWidget {
  final WorkoutSession session;

  const _SessionRow({required this.session});

  /// Days created from the calendar are named with their ISO date, which is an
  /// identifier rather than a label. Showing "2026-09-03" as a workout title
  /// leaks that; the formatted date is what the user means by it.
  String _title() {
    final name = session.dayName;
    final date = session.scheduledDate;
    final isIsoDate =
        name != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(name);

    if (name != null && !isIsoDate) return name;
    if (date != null) return '${date.day}/${date.month}/${date.year}';
    return session.planName ?? tr('workout');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = session.summary;
    final ratio = summary.setCount == 0
        ? 0.0
        : summary.completedSetCount / summary.setCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fitness_center, color: colors.primary1, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  // The kit showed calories here; nothing measures those, and
                  // an invented number is worse than a real one.
                  '${formatDuration(session.durationSeconds ?? 0)}'
                  ' · ${summary.setCount} ${tr("setsLabel")}'
                  ' · ${formatVolume(summary.totalVolumeKg)}',
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: colors.surface,
                    color: colors.primary1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
