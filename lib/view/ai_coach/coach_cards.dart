import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/ai_badge.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../core/refresh_flags.dart';
import '../../models/chat_models.dart';
import '../../services/ai_coach_service.dart';
import '../../services/workout_plan_service.dart';
import '../exercise/exercise_detail_view.dart';
import '../tracker/schedule_calendar_view.dart';

/// The cards under a coach answer: exercises it suggests, a schedule it
/// proposes.
///
/// [onReplaced] hands back the message as the server now has it after Apply
/// or Dismiss, so the conversation shows the new status without reloading.
class CoachAttachmentCards extends StatelessWidget {
  final ChatMessage message;
  final BodifyColors colors;
  final ValueChanged<ChatMessage> onReplaced;

  const CoachAttachmentCards({
    super.key,
    required this.message,
    required this.colors,
    required this.onReplaced,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in message.attachments)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: switch (attachment) {
              ExerciseSuggestion() =>
                _ExerciseSuggestionCard(suggestion: attachment, colors: colors),
              ScheduleProposal() => _ScheduleProposalCard(
                  proposal: attachment,
                  messageId: message.id,
                  colors: colors,
                  onReplaced: onReplaced,
                ),
            },
          ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(BodifyColors colors) => BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.primary1.withValues(alpha: 0.25)),
    );

void _openExercise(BuildContext context, int exerciseId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ExerciseDetailView(exerciseId: exerciseId),
    ),
  );
}

class _ExerciseSuggestionCard extends StatelessWidget {
  final ExerciseSuggestion suggestion;
  final BodifyColors colors;

  const _ExerciseSuggestionCard({
    required this.suggestion,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(colors),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, size: 15, color: colors.primary1),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  suggestion.reason ?? tr('title_coach_suggested_exercises'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final exercise in suggestion.exercises)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openExercise(context, exercise.exerciseId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    ExerciseThumbnail(
                      url: exercise.listImageUrl,
                      cacheKey: exercise.listImageCacheKey,
                      size: 40,
                      radius: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        exercise.name ?? '#${exercise.exerciseId}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.textPrimary, fontSize: 13),
                      ),
                    ),
                    AiBadge(algorithm: exercise.aiAlgorithm),
                    Icon(Icons.chevron_right,
                        size: 18, color: colors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A drafted schedule, with Apply / Dismiss while it is still pending.
///
/// The warning about dates it will replace sits above the buttons, not in a
/// confirmation dialog after them: the user should know what Apply does
/// before reaching for it, and a dialog on every apply would be dismissed
/// unread.
class _ScheduleProposalCard extends StatefulWidget {
  final ScheduleProposal proposal;
  final int? messageId;
  final BodifyColors colors;
  final ValueChanged<ChatMessage> onReplaced;

  const _ScheduleProposalCard({
    required this.proposal,
    required this.messageId,
    required this.colors,
    required this.onReplaced,
  });

  @override
  State<_ScheduleProposalCard> createState() => _ScheduleProposalCardState();
}

class _ScheduleProposalCardState extends State<_ScheduleProposalCard> {
  bool _busy = false;

  static const _applied = Color(0xFF2ECC71);
  static const _warning = Color(0xFFF39C12);

  static const _weekdayKeys = [
    'dow_mon',
    'dow_tue',
    'dow_wed',
    'dow_thu',
    'dow_fri',
    'dow_sat',
    'dow_sun',
  ];

  ScheduleProposal get _proposal => widget.proposal;
  BodifyColors get _colors => widget.colors;

  static String _dateLabel(DateTime date) =>
      '${tr(_weekdayKeys[date.weekday - 1])} '
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  static String _num(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  /// "3×12 @ 40kg", "3×45 giây", "2×200m" - what one row of the card reads.
  static String _target(ProposedExercise e) {
    final String each;
    if (e.targetDurationSeconds != null && e.targetReps == null) {
      each = '${e.targetDurationSeconds} ${tr('unit_seconds')}';
    } else if (e.targetDistanceM != null) {
      each = '${_num(e.targetDistanceM!)}m';
    } else {
      each = '${e.targetReps ?? '-'}';
    }
    final weight = e.targetWeightKg;
    return '${e.sets}×$each${weight != null && weight > 0 ? ' @ ${_num(weight)}kg' : ''}';
  }

  Future<void> _apply() async {
    final id = widget.messageId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await AiCoachService.instance.applySchedule(id);
      RefreshFlags.markPlansChanged();
      widget.onReplaced(result.message);
      if (!mounted) return;
      final applied = result.message.attachments
          .whereType<ScheduleProposal>()
          .firstOrNull;
      final skipped = applied?.skippedDates.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(skipped == 0
            ? tr('msg_schedule_applied')
            : tr('msg_schedule_applied_skipped')
                .replaceAll('{n}', '$skipped')),
      ));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    final id = widget.messageId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      widget.onReplaced(await AiCoachService.instance.dismissSchedule(id));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCalendar() async {
    final planId = _proposal.planId;
    if (planId == null) return;
    try {
      final plans = await WorkoutPlanService.instance.listPlans();
      final plan = plans.where((p) => p.planId == planId).firstOrNull;
      if (!mounted) return;
      if (plan == null) {
        _showError(tr('msg_schedule_plan_gone'));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScheduleCalendarView(plan: plan)),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final proposal = _proposal;

    return Container(
      decoration: _cardDecoration(colors),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, size: 16, color: colors.primary1),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  proposal.summary ?? tr('title_schedule_proposal'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            (proposal.createsPlan
                    ? tr('label_schedule_new_plan')
                    : tr('label_schedule_into_plan'))
                .replaceAll('{name}', proposal.planName ?? ''),
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (final day in proposal.days) _buildDay(context, day),
          if (proposal.status == ProposalStatus.pending &&
              proposal.replacedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: _warning),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      tr('msg_schedule_replaces')
                          .replaceAll('{n}', '${proposal.replacedCount}'),
                      style: const TextStyle(color: _warning, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          _buildFooter(colors),
        ],
      ),
    );
  }

  Widget _buildDay(BuildContext context, ProposedDay day) {
    final colors = _colors;
    final skipped = _proposal.skippedDates.contains(day.date);

    return Opacity(
      opacity: skipped ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Text(
                _dateLabel(day.date),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: day.restDay
                  ? Text(
                      tr('label_rest_day'),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in day.exercises)
                          InkWell(
                            onTap: () => _openExercise(context, e.exerciseId),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      e.name ?? '#${e.exerciseId}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AiBadge(algorithm: e.aiAlgorithm),
                                  const SizedBox(width: 6),
                                  Text(
                                    _target(e),
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            if (day.replacesExisting &&
                _proposal.status == ProposalStatus.pending)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.swap_horiz, size: 14, color: _warning),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BodifyColors colors) {
    switch (_proposal.status) {
      case ProposalStatus.applied:
        return Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: _applied),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                tr('label_schedule_applied'),
                style: const TextStyle(
                  color: _applied,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _openCalendar,
              child: Text(tr('btn_open_calendar')),
            ),
          ],
        );
      case ProposalStatus.dismissed:
        return Text(
          tr('label_schedule_dismissed'),
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        );
      case ProposalStatus.pending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : _dismiss,
              child: Text(tr('btn_dismiss')),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: _busy || widget.messageId == null ? null : _apply,
              child: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : Text(tr('btn_apply')),
            ),
          ],
        );
    }
  }
}
