import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/progress_models.dart';
import '../../services/progress_service.dart';
import 'personal_records_view.dart';

/// Completion, performance, volume and frequency over a period.
///
/// The period buttons reuse the ranges the home screen's history card already
/// offers, so "7 days" means the same thing in both places.
class ProgressView extends StatefulWidget {
  const ProgressView({super.key});

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  static const _ranges = [7, 30, 365];
  int _days = 30;

  ProgressSummary? _summary;
  List<PersonalBest> _bests = const [];
  String? _error;
  bool _loading = true;

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
    try {
      final from = DateTime.now().subtract(Duration(days: _days - 1));
      final results = await Future.wait([
        ProgressService.instance.summary(from: from),
        ProgressService.instance.personalBests(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as ProgressSummary;
        _bests = results[1] as List<PersonalBest>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '$e';
      });
    }
  }

  void _selectRange(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  static String _num(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  /// A percentage, or a dash when the question does not apply.
  ///
  /// Null is not zero here: nobody completed 0% of a plan they never had, and
  /// a 0 on screen reads as failure instead of absence.
  static String _percent(double? value) =>
      value == null ? '--' : '${value.round()}%';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          tr('title_progress'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _rangePicker(colors),
            const SizedBox(height: 18),
            if (_error != null)
              _errorBox(colors)
            else if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                    child:
                        CircularProgressIndicator(color: colors.primary1)),
              )
            else if ((_summary?.sessionCount ?? 0) == 0)
              _emptyState(colors)
            else ...[
              _statGrid(colors, _summary!),
              const SizedBox(height: 22),
              _recordsCard(colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangePicker(BodifyColors colors) {
    const labels = {
      7: 'label_range_7_days',
      30: 'label_range_1_month',
      365: 'label_range_1_year',
    };
    return Row(
      children: [
        for (final days in _ranges) ...[
          GestureDetector(
            onTap: () => _selectRange(days),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _days == days ? colors.primary1 : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tr(labels[days]!),
                style: TextStyle(
                  color: _days == days ? colors.onPrimary : colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _errorBox(BodifyColors colors) => Column(
        children: [
          const SizedBox(height: 40),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: Text(tr('btn_retry'))),
        ],
      );

  Widget _emptyState(BodifyColors colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(Icons.insights_outlined,
                size: 48, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text(tr('msg_no_progress_yet'),
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(tr('msg_no_progress_hint'),
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
        ),
      );

  Widget _statGrid(BodifyColors colors, ProgressSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                colors,
                title: tr('label_completion'),
                value: _percent(summary.completionPercent),
                caption:
                    '${summary.completedPlannedSets}/${summary.plannedSets} set',
                hint: tr('hint_completion'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                colors,
                title: tr('label_performance'),
                value: _percent(summary.performancePercent),
                caption: tr('hint_performance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                colors,
                title: tr('label_total_volume'),
                value: '${_num(summary.totalVolumeKg)}kg',
                caption:
                    '${summary.sessionCount} ${tr('label_sessions')}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                colors,
                title: tr('label_frequency'),
                value: summary.workoutsPerWeek == null
                    ? '--'
                    : summary.workoutsPerWeek!.toStringAsFixed(1),
                caption: tr('label_per_week'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    BodifyColors colors, {
    required String title,
    required String value,
    required String caption,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: colors.primary1,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: colors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _recordsCard(BodifyColors colors) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PersonalRecordsView()),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Image.asset('assets/img/achievements/trophy.png',
                height: 32, width: 32, color: colors.primary1),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('title_personal_records'),
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    _bests.isEmpty
                        ? tr('msg_no_records_yet')
                        : tr('label_record_count')
                            .replaceFirst('{n}', '${_bests.length}'),
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
