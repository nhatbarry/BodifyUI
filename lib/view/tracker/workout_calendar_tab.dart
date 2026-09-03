import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/app_strings.dart';

/// One day that has training on it. Comes from the schedule API once that
/// exists; the calendar only needs the date and a label to show.
class WorkoutDayEntry {
  final DateTime date;
  final String title;
  final bool isRestDay;
  final bool isCompleted;

  const WorkoutDayEntry({
    required this.date,
    required this.title,
    this.isRestDay = false,
    this.isCompleted = false,
  });
}

/// Strips the time so two DateTimes on the same day compare equal.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

class WorkoutCalendarTab extends StatefulWidget {
  const WorkoutCalendarTab({super.key});

  @override
  State<WorkoutCalendarTab> createState() => _WorkoutCalendarTabState();
}

class _WorkoutCalendarTabState extends State<WorkoutCalendarTab> {
  // Monday-first, matching how Vietnamese calendars are written.
  List<String> get _dayHeaders =>
      List.generate(7, (i) => tr('dow${i + 1}'));

  late DateTime _today;
  late DateTime _selectedDate;
  late DateTime _displayMonth;

  // TODO(schedule-api): fill from GET /users/me/schedules once that endpoint
  // exists. Until then the calendar renders with no training days marked.
  final List<WorkoutDayEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _today = dateOnly(DateTime.now());
    _selectedDate = _today;
    _displayMonth = DateTime(_today.year, _today.month);
  }

  Set<DateTime> get _markedDates => _entries.map((e) => dateOnly(e.date)).toSet();

  List<WorkoutDayEntry> get _selectedDayEntries =>
      _entries.where((e) => dateOnly(e.date) == _selectedDate).toList();

  void _shiftMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarCard(),
          const SizedBox(height: 18),
          _buildSelectedDaySection(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: Icon(Icons.chevron_left, color: context.colors.textPrimary),
              ),
              Expanded(
                child: Text(
                  "${tr('month${_displayMonth.month}')} ${_displayMonth.year}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => _shiftMonth(1),
                icon: Icon(Icons.chevron_right, color: context.colors.textPrimary),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < _dayHeaders.length; i++)
                Expanded(
                  child: Text(
                    _dayHeaders[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // Weekend columns stand out, as on a printed calendar.
                      color: i >= 5 ? const Color(0xFFE74C3C) : context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ..._buildWeekRows(),
        ],
      ),
    );
  }

  List<Widget> _buildWeekRows() {
    final firstOfMonth = DateTime(_displayMonth.year, _displayMonth.month, 1);
    // Dart's weekday is Mon=1..Sun=7, so Monday-first needs no wrap-around.
    final leadingBlanks = firstOfMonth.weekday - 1;
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;

    final cells = <int?>[
      ...List<int?>.filled(leadingBlanks, null),
      ...List<int?>.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (final day in cells.sublist(i, i + 7))
            Expanded(child: day == null ? const SizedBox(height: 46) : _buildDayCell(day)),
        ],
      ));
    }
    return rows;
  }

  Widget _buildDayCell(int day) {
    final date = DateTime(_displayMonth.year, _displayMonth.month, day);
    final isToday = date == _today;
    final isSelected = date == _selectedDate;
    final isMarked = _markedDates.contains(date);
    final isPast = date.isBefore(_today);

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 46,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isToday ? LinearGradient(colors: context.colors.primaryGradient) : null,
                color: !isToday && isSelected ? context.colors.surfaceVariant : null,
                shape: BoxShape.circle,
                border: isSelected && !isToday
                    ? Border.all(color: context.colors.primary1, width: 1.5)
                    : null,
              ),
              child: Text(
                "$day",
                style: TextStyle(
                  color: isToday ? context.colors.surface : context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight:
                      isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // A dot marks a training day; past days are dimmed so history reads
            // differently from what is still ahead.
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !isMarked
                    ? Colors.transparent
                    : isPast
                        ? context.colors.textSecondary.withOpacity(0.5)
                        : context.colors.primary1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDaySection() {
    final entries = _selectedDayEntries;
    final isToday = _selectedDate == _today;
    final label = isToday
        ? tr('today')
        : "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.event_note, color: context.colors.textSecondary, size: 32),
                const SizedBox(height: 10),
                Text(
                  tr('noScheduleForDay'),
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('scheduleApiPending'),
                  style: TextStyle(
                      color: context.colors.textSecondary.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          )
        else
          for (final entry in entries) _buildEntryCard(entry),
      ],
    );
  }

  Widget _buildEntryCard(WorkoutDayEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              entry.isRestDay ? Icons.self_improvement : Icons.fitness_center,
              color: context.colors.primary1,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (entry.isCompleted)
            Icon(Icons.check_circle, color: context.colors.primary1, size: 20),
        ],
      ),
    );
  }
}
