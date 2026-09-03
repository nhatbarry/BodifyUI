import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/workout_plan_models.dart';
import '../../models/workout_session_models.dart';
import '../../services/workout_plan_service.dart';
import '../../services/workout_session_service.dart';
import '../exercise/exercise_detail_view.dart';
import 'exercise_picker_sheet.dart';
import 'active_workout_view.dart';
import 'session_log_view.dart';
import 'workout_sets_view.dart';

/// One schedule's calendar: pick a date, see what is on it, edit it.
///
/// Opens on today and browses freely in both directions - a past date is as
/// editable as a future one, because a plan is a plan, not a log of what was
/// performed.
class ScheduleCalendarView extends StatefulWidget {
  final WorkoutPlan plan;

  const ScheduleCalendarView({super.key, required this.plan});

  @override
  State<ScheduleCalendarView> createState() => _ScheduleCalendarViewState();
}

class _ScheduleCalendarViewState extends State<ScheduleCalendarView> {
  // Monday-first, matching how Vietnamese calendars are written.
  List<String> get _dayHeaders =>
      List.generate(7, (i) => tr('dow${i + 1}'));

  late final DateTime _today = dateOnly(DateTime.now());
  late DateTime _selectedDate = _today;
  late DateTime _displayMonth = DateTime(_today.year, _today.month);

  /// Dates in the visible month that have something planned.
  Map<DateTime, CalendarEntry> _monthEntries = {};
  WorkoutDayDetail? _selectedDay;

  /// What was actually recorded on the selected date, if anything. Held
  /// separately from the plan rather than merged into it: the plan says what
  /// was meant to happen and the session says what did, and the row shows both.
  WorkoutSession? _selectedSession;

  bool _loadingMonth = true;
  bool _loadingDay = false;
  bool _busySession = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonth();
    _loadDay();
  }

  DateTime get _monthStart => DateTime(_displayMonth.year, _displayMonth.month, 1);

  DateTime get _monthEnd =>
      DateTime(_displayMonth.year, _displayMonth.month + 1, 0);

  Future<void> _loadMonth() async {
    setState(() {
      _loadingMonth = true;
      _error = null;
    });
    try {
      final entries = await WorkoutPlanService.instance.calendar(
        planId: widget.plan.planId,
        from: _monthStart,
        to: _monthEnd,
      );
      if (!mounted) return;
      setState(() {
        _monthEntries = {for (final e in entries) dateOnly(e.date): e};
        _loadingMonth = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingMonth = false;
      });
    }
  }

  Future<void> _loadDay() async {
    setState(() => _loadingDay = true);
    try {
      // Both at once: the plan and the record of it are independent reads, and
      // waiting for one before starting the other would double the latency of
      // every date tap.
      final results = await Future.wait([
        WorkoutPlanService.instance.dayForDate(widget.plan.planId, _selectedDate),
        WorkoutSessionService.instance.sessionForDate(_selectedDate),
      ]);
      if (!mounted) return;
      setState(() {
        _selectedDay = results[0] as WorkoutDayDetail?;
        _selectedSession = results[1] as WorkoutSession?;
        _loadingDay = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingDay = false);
      _showError(e);
    }
  }

  /// Which of the three things this date is. The row shows planned numbers,
  /// planned-versus-actual, or live progress depending on the answer.
  _DayPhase get _phase {
    if (_selectedDate.isBefore(_today)) return _DayPhase.past;
    if (_selectedDate.isAfter(_today)) return _DayPhase.future;
    return _DayPhase.today;
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException ? error.message : '$error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _shiftMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
    _loadMonth();
  }

  void _selectDate(DateTime date) {
    if (date == _selectedDate) return;
    setState(() {
      _selectedDate = date;
      _selectedDay = null;
      _selectedSession = null;
    });
    // Jumping across a month boundary is possible from the "today" shortcut.
    if (date.year != _displayMonth.year || date.month != _displayMonth.month) {
      _displayMonth = DateTime(date.year, date.month);
      _loadMonth();
    }
    _loadDay();
  }

  /// Opens the picker pre-ticked with what is already on this date, then saves
  /// whatever comes back as the date's complete list. Unticking is therefore
  /// how an exercise is removed - the same gesture, in the same place.
  Future<void> _editExercises() async {
    final current =
        _selectedDay?.exercises.map((e) => e.exerciseId).toList() ?? <int>[];

    final chosen = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExercisePickerSheet(initialSelection: current),
    );
    if (chosen == null) return;

    setState(() => _loadingDay = true);
    try {
      final day = await WorkoutPlanService.instance
          .setDateExercises(widget.plan.planId, _selectedDate, chosen);
      if (!mounted) return;
      setState(() {
        _selectedDay = day;
        _loadingDay = false;
      });
      // The month grid's dot for this date may have just appeared or gone.
      _loadMonth();
    } catch (e) {
      if (mounted) setState(() => _loadingDay = false);
      _showError(e);
    }
  }

  Future<void> _openSets(PlannedExercise exercise) async {
    // Two different screens behind the same row, because the row means two
    // different things: with a session open the user is recording what they
    // just lifted, without one they are still editing the plan.
    final performed = _selectedSession?.forExercise(exercise.exerciseId);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => performed != null
            ? SessionLogView(exercise: performed)
            : WorkoutSetsView(exercise: exercise),
      ),
    );
    // Only re-read when something was actually edited; the set summary on the
    // row is the only thing that can have changed.
    if (changed == true && mounted) _loadDay();
  }

  Future<void> _reorderExercises(int oldIndex, int newIndex) async {
    final day = _selectedDay;
    if (day == null) return;

    final previous = List<PlannedExercise>.from(day.exercises);
    final moved = List<PlannedExercise>.from(day.exercises);
    moved.insert(newIndex, moved.removeAt(oldIndex));
    setState(() {
      _selectedDay = _withExercises(day, moved);
      _loadingDay = true;
    });

    try {
      final refreshed = await WorkoutPlanService.instance.reorderDayExercises(
        day.workoutDayId,
        moved.map((e) => e.workoutExerciseId).toList(),
      );
      if (!mounted) return;
      setState(() {
        _selectedDay = refreshed;
        _loadingDay = false;
      });
    } catch (e) {
      // The drag already moved the row on screen; put it back rather than
      // leave an order the server does not have.
      if (mounted) {
        setState(() {
          _selectedDay = _withExercises(day, previous);
          _loadingDay = false;
        });
      }
      _showError(e);
    }
  }

  WorkoutDayDetail _withExercises(
          WorkoutDayDetail day, List<PlannedExercise> exercises) =>
      WorkoutDayDetail(
        workoutDayId: day.workoutDayId,
        name: day.name,
        dayOrder: day.dayOrder,
        isRestDay: day.isRestDay,
        description: day.description,
        exercises: exercises,
      );

  Future<void> _removeExercise(PlannedExercise exercise) async {
    final remaining = (_selectedDay?.exercises ?? [])
        .where((e) => e.workoutExerciseId != exercise.workoutExerciseId)
        .map((e) => e.exerciseId)
        .toList();

    setState(() => _loadingDay = true);
    try {
      final day = await WorkoutPlanService.instance
          .setDateExercises(widget.plan.planId, _selectedDate, remaining);
      if (!mounted) return;
      setState(() {
        _selectedDay = day;
        _loadingDay = false;
      });
      _loadMonth();
    } catch (e) {
      if (mounted) setState(() => _loadingDay = false);
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          widget.plan.name,
          style: TextStyle(
              color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_selectedDate != _today)
            TextButton(
              onPressed: () => _selectDate(_today),
              child: Text(tr('today'),
                  style: TextStyle(color: colors.primary1, fontSize: 13)),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          children: [
            _buildCalendarCard(),
            const SizedBox(height: 18),
            _buildDaySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: Icon(Icons.chevron_left, color: colors.textPrimary),
              ),
              Expanded(
                child: Text(
                  "${tr('month${_displayMonth.month}')} ${_displayMonth.year}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
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
              for (var i = 0; i < _dayHeaders.length; i++)
                Expanded(
                  child: Text(
                    _dayHeaders[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // Weekend columns stand out, as on a printed calendar.
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
          ..._buildWeekRows(),
          if (_loadingMonth)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  color: colors.primary1,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildWeekRows() {
    final firstOfMonth = _monthStart;
    // Dart's weekday is Mon=1..Sun=7, so Monday-first needs no wrap-around.
    final leadingBlanks = firstOfMonth.weekday - 1;
    final daysInMonth = _monthEnd.day;

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
            Expanded(
                child: day == null
                    ? const SizedBox(height: 46)
                    : _buildDayCell(day)),
        ],
      ));
    }
    return rows;
  }

  Widget _buildDayCell(int day) {
    final colors = context.colors;
    final date = DateTime(_displayMonth.year, _displayMonth.month, day);
    final isToday = date == _today;
    final isSelected = date == _selectedDate;
    final entry = _monthEntries[date];
    final isPast = date.isBefore(_today);

    return GestureDetector(
      onTap: () => _selectDate(date),
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
                gradient: isToday
                    ? LinearGradient(colors: colors.primaryGradient)
                    : null,
                color: !isToday && isSelected ? colors.surface : null,
                shape: BoxShape.circle,
                border: isSelected && !isToday
                    ? Border.all(color: colors.primary1, width: 1.5)
                    : null,
              ),
              child: Text(
                "$day",
                style: TextStyle(
                  color: isToday ? colors.onPrimary : colors.textPrimary,
                  fontSize: 13,
                  fontWeight:
                      isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // A dot marks training; a tick marks a planned rest. A date with
            // neither has nothing scheduled - three states, three marks.
            SizedBox(
              height: 10,
              child: entry == null
                  ? null
                  : entry.isRestDay
                      ? Icon(Icons.check,
                          size: 10,
                          color: colors.textSecondary
                              .withValues(alpha: isPast ? 0.5 : 1))
                      : Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPast
                                ? colors.textSecondary.withValues(alpha: 0.5)
                                : colors.primary1,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Start / finish, shown on today only.
  ///
  /// A workout is something you do now: there is no sense in "starting" a
  /// session for next Tuesday, and yesterday's is either recorded or missed.
  Widget _buildSessionBar() {
    final colors = context.colors;
    final session = _selectedSession;

    if (session == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busySession ? null : _startWorkout,
          icon: const Icon(Icons.play_arrow, size: 18),
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary1,
            foregroundColor: colors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          ),
          label: Text(tr('startWorkout'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }

    final done = session.summary.completedSetCount;
    final total = session.summary.setCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            session.isPaused
                ? Icons.pause_circle
                : session.isInProgress
                    ? Icons.timer
                    : Icons.check_circle,
            size: 18,
            color: session.isActive
                ? colors.primary1
                : const Color(0xFF27AE60),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.isActive
                  ? '${session.isPaused ? tr("workoutPaused") : tr("workoutInProgress")} · $done/$total'
                  : tr("setProgress")
                      .replaceFirst("{done}", "$done")
                      .replaceFirst("{total}", "$total"),
              style: TextStyle(color: colors.textPrimary, fontSize: 12),
            ),
          ),
          if (session.isActive)
            TextButton(
              onPressed: _busySession ? null : () => _openWorkout(session),
              child: Text(tr('continueWorkout'),
                  style: TextStyle(color: colors.primary1, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Future<void> _startWorkout() async {
    final day = _selectedDay;
    if (day == null) return;
    setState(() => _busySession = true);
    try {
      // The backend copies the day's exercises and target sets in, so the
      // workout screen opens with every set laid out and waiting for a number.
      final session = await WorkoutSessionService.instance.startSession(
        workoutDayId: day.workoutDayId,
        scheduledDate: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _selectedSession = session;
        _busySession = false;
      });
      await _openWorkout(session);
    } catch (e) {
      if (mounted) setState(() => _busySession = false);
      _showError(e);
    }
  }

  /// Hands the session over to the workout screen, then re-reads the day.
  ///
  /// The calendar is the wrong place to train from - it is a month grid with a
  /// list under it - so starting or resuming a workout leaves it entirely.
  Future<void> _openWorkout(WorkoutSession session) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ActiveWorkoutView(session: session)),
    );
    // Always reload: the screen can pause, log, finish or abandon, and the
    // calendar has no way to guess which happened.
    if (mounted) _loadDay();
  }

  Widget _buildDaySection() {
    final colors = context.colors;
    final isToday = _selectedDate == _today;
    final label = isToday
        ? tr('today')
        : "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";
    final exercises = _selectedDay?.exercises ?? const <PlannedExercise>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: _loadingDay ? null : _editExercises,
              icon: Icon(Icons.add, size: 18, color: colors.primary1),
              label: Text(
                exercises.isEmpty ? tr('addExercises') : tr('editExercises'),
                style: TextStyle(color: colors.primary1, fontSize: 13),
              ),
            ),
          ],
        ),
        if (_phase == _DayPhase.today && exercises.isNotEmpty) _buildSessionBar(),
        const SizedBox(height: 6),
        if (_loadingDay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
                child: CircularProgressIndicator(color: colors.primary1)),
          )
        else if (_error != null && _monthEntries.isEmpty)
          Text(_error!,
              style: TextStyle(color: colors.textSecondary, fontSize: 13))
        else if (exercises.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.event_note, color: colors.textSecondary, size: 32),
                const SizedBox(height: 10),
                Text(tr('noScheduleForDay'),
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 13)),
              ],
            ),
          )
        else
          // Drag reorders the day; the whole list is sent in one request,
          // which is the only shape the server accepts.
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: exercises.length,
            onReorderItem: _reorderExercises,
            itemBuilder: (_, i) => _ExerciseRow(
              key: ValueKey(exercises[i].workoutExerciseId),
              index: i,
              exercise: exercises[i],
              phase: _phase,
              performed: _selectedSession?.forExercise(exercises[i].exerciseId),
              onTap: () => _openSets(exercises[i]),
              onRemove: () => _removeExercise(exercises[i]),
            ),
          ),
      ],
    );
  }
}

/// What a date is relative to today, which decides what the rows show.
enum _DayPhase { past, today, future }

class _ExerciseRow extends StatelessWidget {
  final int index;
  final PlannedExercise exercise;

  /// What was recorded against this exercise, if the user trained. Null on a
  /// future date, and on a past date they skipped.
  final SessionExercise? performed;
  final _DayPhase phase;

  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ExerciseRow({
    super.key,
    required this.index,
    required this.exercise,
    required this.phase,
    required this.onTap,
    required this.onRemove,
    this.performed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sets = exercise.sets;

    // "3 × 10" when every set asks for the same reps, otherwise the reps
    // spelled out: "10 / 10 / 8" is a real and common shape.
    String setSummary() {
      if (sets.isEmpty) return tr('noTargetSets');
      final reps = sets.map((s) => s.targetReps).toList();
      if (reps.every((r) => r != null && r == reps.first)) {
        return '${sets.length} × ${reps.first}';
      }
      return reps.map((r) => r?.toString() ?? '-').join(' / ');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
        children: [
          ExerciseThumbnail(
            url: exercise.listImageUrl,
            cacheKey: exercise.listImageCacheKey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The one catalog row with no translation has no name at all.
                  exercise.name ?? '#${exercise.exerciseId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                _SetLine(
                  planned: setSummary(),
                  performed: performed,
                  plannedSetCount: sets.length,
                  phase: phase,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('exerciseDetail'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ExerciseDetailView(exerciseId: exercise.exerciseId),
              ),
            ),
            icon: Icon(Icons.info_outline,
                color: colors.textSecondary, size: 19),
          ),
          IconButton(
            tooltip: tr('remove'),
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: Color(0xFFE74C3C), size: 19),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, right: 4),
              child: Icon(Icons.drag_handle,
                  color: colors.textSecondary, size: 20),
            ),
          ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// The line under an exercise name, which says a different thing on each side
/// of today.
///
/// * **future** - the plan only. Nothing has happened yet, and showing an
///   empty "actual" column would just be noise.
/// * **today** - progress. Mid-workout the useful number is how much is left,
///   not a comparison against a target that is still being worked towards.
/// * **past** - planned against actual, because that is the only question
///   worth asking about a workout that is over. A past date with no session
///   says so plainly rather than pretending the plan was the outcome.
class _SetLine extends StatelessWidget {
  final String planned;
  final SessionExercise? performed;
  final int plannedSetCount;
  final _DayPhase phase;

  const _SetLine({
    required this.planned,
    required this.performed,
    required this.plannedSetCount,
    required this.phase,
  });

  /// The reps actually put in, in order: "10 / 9 / 8". Sets left blank show as
  /// a dash so the two lines stay readable side by side. An exercise that was
  /// carried into the session but never touched has nothing to list, and an
  /// empty string beside "TT" reads as a rendering bug rather than as "none".
  static String _actualReps(SessionExercise done) {
    if (done.sets.isEmpty) return tr('notLogged');
    return done.sets
        .map((s) => s.isLogged ? (s.reps?.toString() ?? '-') : '-')
        .join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = performed;

    Widget label(String text, Color color, {FontWeight? weight}) => Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: weight),
        );

    if (phase == _DayPhase.future || done == null) {
      // A past date with no session gets the plan plus a quiet note that it
      // did not happen; a future one just gets the plan.
      if (phase == _DayPhase.past) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label(planned, colors.textSecondary),
            const SizedBox(height: 2),
            label(tr('notTrained'), colors.textSecondary),
          ],
        );
      }
      return label(planned, colors.primary1);
    }

    if (phase == _DayPhase.today) {
      final logged = done.loggedSetCount;
      final total = done.sets.isEmpty ? plannedSetCount : done.sets.length;
      final ratio = total == 0 ? 0.0 : logged / total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              label(
                tr('setProgress')
                    .replaceFirst('{done}', '$logged')
                    .replaceFirst('{total}', '$total'),
                logged == total && total > 0
                    ? const Color(0xFF27AE60)
                    : colors.primary1,
                weight: FontWeight.w600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: colors.surface,
                    color: logged == total && total > 0
                        ? const Color(0xFF27AE60)
                        : colors.primary1,
                  ),
                ),
              ),
            ],
          ),
          if (logged > 0) ...[
            const SizedBox(height: 3),
            label('${tr("actualShort")} ${_actualReps(done)}',
                colors.textSecondary),
          ],
        ],
      );
    }

    // Past, with a session: both numbers, planned first. The prefix is
    // dropped when there is no plan to label - "KH Chưa đặt set mục tiêu"
    // reads as a mistake.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(
          plannedSetCount == 0 ? planned : '${tr("plannedShort")} $planned',
          colors.textSecondary,
        ),
        const SizedBox(height: 2),
        label('${tr("actualShort")} ${_actualReps(done)}',
            const Color(0xFF27AE60), weight: FontWeight.w600),
      ],
    );
  }
}
