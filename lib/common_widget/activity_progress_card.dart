import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/api_exception.dart';
import '../core/app_strings.dart';
import '../models/progress_models.dart';
import '../services/progress_service.dart';

/// Training history as a grid: one column per week, one row per weekday.
///
/// The GitHub contribution graph. A week per column is what makes the shape
/// readable at a glance - Mondays line up under Mondays, so "I always skip
/// Thursdays" is visible without reading a single number, which a row of seven
/// bars could never show.
///
/// Measured in **completed sets**. Sets are the one unit every tracking type
/// produces: a day of planks and carries has no volume at all and would read
/// as a blank square on a volume map, which is the opposite of what happened.
///
/// Shade is relative to the user's own busiest day in the window, not to a
/// fixed target they never set. The trade-off is that the darkest square is
/// always "their best recently" rather than an absolute - this shows the shape
/// of a training habit, not a score.
class ActivityProgressCard extends StatefulWidget {
  const ActivityProgressCard({super.key});

  @override
  State<ActivityProgressCard> createState() => _ActivityProgressCardState();
}

class _ActivityProgressCardState extends State<ActivityProgressCard> {
  /// GitHub's square, near enough. Small squares are the whole point: they are
  /// what lets months of history sit in the corner of a screen instead of
  /// filling it, and a grid of five fat tiles is a calendar, not a graph.
  static const double _cellSize = 11;
  static const double _cellGap = 3;
  static const double _pitch = _cellSize + _cellGap;

  /// Width of the weekday gutter and the gap after it.
  static const double _gutter = 20;
  static const double _gutterGap = 6;

  /// The most the card will ever draw, and therefore the most it fetches.
  /// Half a year of columns is wider than any phone; the grid renders as many
  /// of them as actually fit and drops the oldest.
  static const int _maxWeeks = 26;

  List<ActivityDay>? _days;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final days = await ProgressService.instance.recentActivity(
        days: _maxWeeks * 7,
      );
      if (mounted) setState(() => _days = days);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr('error_save_failed'));
    }
  }

  /// Public so the home screen can refresh after a workout.
  Future<void> reload() => _load();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = _days;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // How many whole weeks the card can draw. Sized to the box rather
          // than fixed, so the grid fills a tablet and still fits a small
          // phone instead of overflowing it.
          final usable = constraints.maxWidth - _gutter - _gutterGap;
          final weeks = (usable / _pitch).floor().clamp(4, _maxWeeks);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(colors, days, weeks),
              const SizedBox(height: 14),
              if (_error != null)
                SizedBox(
                  height: 110,
                  child: Center(
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                  ),
                )
              else if (days == null)
                SizedBox(
                  height: 110,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.primary1)),
                )
              else
                _buildGrid(colors, days, weeks),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BodifyColors colors, List<ActivityDay>? days, int weeks) {
    // The count covers the squares actually on screen. Summing the whole
    // fetched half-year would report a number the grid does not show.
    int? total;
    if (days != null) {
      final from = _gridStart(weeks);
      total = days
          .where((d) => !d.day.isBefore(from))
          .fold<int>(0, (sum, d) => sum + d.completedSets);
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            tr('title_activity_progress'),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (total != null)
          Text(
            tr('label_sets_this_week').replaceFirst('{n}', '$total'),
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
      ],
    );
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The Monday the leftmost column starts on.
  ///
  /// The grid ends on the Sunday of the current week so every column is a full
  /// seven cells; a column cut short reads as a rendering fault rather than as
  /// a week that has not finished yet.
  DateTime _gridStart(int weeks) {
    final last = _today();
    final gridEnd = last.add(Duration(days: DateTime.sunday - last.weekday));
    return gridEnd.subtract(Duration(days: weeks * 7 - 1));
  }

  Widget _buildGrid(BodifyColors colors, List<ActivityDay> days, int weeks) {
    // Keyed by date so a column can ask for a day it may not have - the tail
    // of the current week is in the future and has no row at all.
    final byDate = {
      for (final day in days)
        DateTime(day.day.year, day.day.month, day.day.day): day,
    };

    final gridStart = _gridStart(weeks);
    final lastDay = _today();
    final peak = days
        .where((d) => !d.day.isBefore(gridStart))
        .map((d) => d.completedSets)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _monthLabels(colors, gridStart, weeks),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _weekdayLabels(colors),
            const SizedBox(width: _gutterGap),
            Column(
              children: [
                for (var row = 0; row < 7; row++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _cellGap),
                    child: Row(
                      children: [
                        for (var week = 0; week < weeks; week++)
                          _cell(
                            colors,
                            gridStart.add(Duration(days: week * 7 + row)),
                            byDate,
                            peak,
                            lastDay,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _legend(colors),
      ],
    );
  }

  /// A month name over the first column that falls in it, the way GitHub
  /// labels its graph. Repeating it every column would be noise.
  ///
  /// Positioned rather than laid out in a Row: a label is wider than the 14 px
  /// column it sits over, so a Row would either clip it or push the labels out
  /// of step with the squares below.
  Widget _monthLabels(BodifyColors colors, DateTime gridStart, int weeks) {
    int? previousMonth;
    final labels = <Widget>[];

    for (var week = 0; week < weeks; week++) {
      final columnStart = gridStart.add(Duration(days: week * 7));
      if (columnStart.month == previousMonth) continue;
      previousMonth = columnStart.month;
      // Nothing on the last column - the label is wider than it is and would
      // run off the edge of the card.
      if (week > weeks - 2) continue;
      labels.add(Positioned(
        left: _gutter + _gutterGap + week * _pitch,
        top: 0,
        child: Text(
          '${tr('label_month_short')}${columnStart.month}',
          style: TextStyle(color: colors.textSecondary, fontSize: 9),
        ),
      ));
    }

    return SizedBox(
      height: 11,
      width: _gutter + _gutterGap + weeks * _pitch,
      child: Stack(clipBehavior: Clip.none, children: labels),
    );
  }

  Widget _weekdayLabels(BodifyColors colors) {
    // Every other row, like GitHub: seven labels beside squares this small
    // would not fit without shrinking the text past reading size.
    const shown = {0: 'dow_mon', 2: 'dow_wed', 4: 'dow_fri'};
    return SizedBox(
      width: _gutter,
      child: Column(
        children: [
          for (var row = 0; row < 7; row++)
            SizedBox(
              height: _pitch,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  shown.containsKey(row) ? tr(shown[row]!) : '',
                  style: TextStyle(color: colors.textSecondary, fontSize: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BodifyColors colors,
    DateTime date,
    Map<DateTime, ActivityDay> byDate,
    int peak,
    DateTime lastDay,
  ) {
    // Days past today are not "no training", they have not happened. Drawn
    // blank so the last column does not read as a week of missed sessions.
    final future = date.isAfter(lastDay);
    final sets = byDate[date]?.completedSets ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: _cellGap),
      child: Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(
          color: future ? Colors.transparent : _shade(colors, sets, peak),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }

  /// Four steps plus empty, shaded against the busiest day in the window.
  ///
  /// Any training at all gets the first step rather than a fraction of it: one
  /// set is a day the user turned up, and a square too faint to see says the
  /// opposite.
  Color _shade(BodifyColors colors, int sets, int peak) {
    if (sets <= 0) return colors.textSecondary.withValues(alpha: 0.12);
    final ratio = peak <= 0 ? 1.0 : sets / peak;
    if (ratio <= 0.25) return colors.primary1.withValues(alpha: 0.3);
    if (ratio <= 0.5) return colors.primary1.withValues(alpha: 0.5);
    if (ratio <= 0.75) return colors.primary1.withValues(alpha: 0.75);
    return colors.primary1;
  }

  Widget _legend(BodifyColors colors) {
    Widget swatch(Color color) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(tr('label_less'),
            style: TextStyle(color: colors.textSecondary, fontSize: 9)),
        const SizedBox(width: 4),
        swatch(colors.textSecondary.withValues(alpha: 0.12)),
        swatch(colors.primary1.withValues(alpha: 0.3)),
        swatch(colors.primary1.withValues(alpha: 0.5)),
        swatch(colors.primary1.withValues(alpha: 0.75)),
        swatch(colors.primary1),
        const SizedBox(width: 4),
        Text(tr('label_more'),
            style: TextStyle(color: colors.textSecondary, fontSize: 9)),
      ],
    );
  }
}
