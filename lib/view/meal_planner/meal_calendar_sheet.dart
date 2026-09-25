import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';

// The planned/actual pair the workout screens use: orange for what was
// planned, green for what happened. Local to each screen that shows the pair,
// as there (see the workout calendar).
const _kPlannedColor = Color(0xFFF2994A);
const _kActualColor = Color(0xFF27AE60);

/// A month of the diary at a glance, opened by tapping the date.
///
/// Stepping day by day with the arrows is fine for yesterday and tomorrow and
/// tedious for anything further. Each date shows what it came to - green for
/// eaten, orange for a plan not eaten yet - so the user can see which days
/// they logged before choosing one. Tapping a date returns it.
class MealCalendarSheet extends StatefulWidget {
  final DateTime selected;

  const MealCalendarSheet({super.key, required this.selected});

  @override
  State<MealCalendarSheet> createState() => _MealCalendarSheetState();
}

class _MealCalendarSheetState extends State<MealCalendarSheet> {
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Monday-first, matching how Vietnamese calendars are written.
  static const _dayHeaderKeys = [
    'dow_mon', 'dow_tue', 'dow_wed', 'dow_thu', 'dow_fri', 'dow_sat', 'dow_sun',
  ];

  late final DateTime _today = _dateOnly(DateTime.now());
  late final DateTime _selected = _dateOnly(widget.selected);
  late DateTime _month = DateTime(_selected.year, _selected.month);

  /// Months already fetched, so going back and forth costs nothing.
  final Map<DateTime, Map<DateTime, CalendarDay>> _byMonth = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    if (_byMonth.containsKey(month)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await MealService.instance.calendar(
        from: month,
        to: DateTime(month.year, month.month + 1, 0),
      );
      if (!mounted) return;
      setState(() {
        _byMonth[month] = days;
        if (month == _month) _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || month != _month) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _loading = false;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: Icon(Icons.chevron_left, color: colors.textPrimary),
                ),
                Expanded(
                  child: Text(
                    '${tr('month_${_month.month}')} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: Icon(Icons.chevron_right, color: colors.textPrimary),
                ),
              ],
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      tr(_dayHeaderKeys[i]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: i >= 5
                            ? const Color(0xFFE74C3C)
                            : colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ..._weekRows(),
            SizedBox(
              height: 3,
              child: _loading
                  ? LinearProgressIndicator(
                      color: colors.primary1,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 8),
                _legend(_kActualColor, tr('label_eaten')),
                const SizedBox(width: 16),
                _legend(_kPlannedColor, tr('label_status_planned')),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _today),
                  child: Text(tr('title_today')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
          ),
        ],
      );

  List<Widget> _weekRows() {
    final first = _month;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Dart's weekday is Mon=1..Sun=7, so Monday-first needs no wrap-around.
    final cells = <int?>[
      ...List<int?>.filled(first.weekday - 1, null),
      ...List<int?>.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return [
      for (var i = 0; i < cells.length; i += 7)
        Row(
          children: [
            for (final day in cells.sublist(i, i + 7))
              Expanded(
                child: day == null ? const SizedBox(height: 56) : _dayCell(day),
              ),
          ],
        ),
    ];
  }

  Widget _dayCell(int day) {
    final colors = context.colors;
    final date = DateTime(_month.year, _month.month, day);
    final isToday = date == _today;
    final isSelected = date == _selected;
    final entry = _byMonth[_month]?[date];

    // Eaten wins when there is some: it is what happened. A plan still
    // waiting shows in orange, so a future week reads as "already planned".
    String? kcal;
    Color? kcalColor;
    if (entry != null && entry.eatenCount > 0) {
      kcal = entry.eatenKcal.round().toString();
      kcalColor = _kActualColor;
    } else if (entry != null && entry.plannedCount > 0) {
      kcal = entry.plannedKcal.round().toString();
      kcalColor = _kPlannedColor;
    }

    return GestureDetector(
      onTap: () => Navigator.pop(context, date),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isToday
                    ? LinearGradient(colors: colors.primaryGradient)
                    : null,
                shape: BoxShape.circle,
                border: isSelected && !isToday
                    ? Border.all(color: colors.primary1, width: 1.5)
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  color: isToday ? colors.onPrimary : colors.textPrimary,
                  fontSize: 13,
                  fontWeight:
                      isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 14,
              child: kcal == null
                  ? null
                  : Text(
                      kcal,
                      style: TextStyle(
                        color: kcalColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
