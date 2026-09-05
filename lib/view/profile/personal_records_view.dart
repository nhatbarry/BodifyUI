import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/progress_models.dart';
import '../../services/progress_service.dart';

/// Every record the user currently holds, grouped by exercise.
///
/// Reads `/personal-records`, which is the current-best table rather than a
/// scan of the whole history - one row per record instead of a DISTINCT ON.
class PersonalRecordsView extends StatefulWidget {
  const PersonalRecordsView({super.key});

  @override
  State<PersonalRecordsView> createState() => _PersonalRecordsViewState();
}

class _PersonalRecordsViewState extends State<PersonalRecordsView> {
  List<PersonalBest>? _bests;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ProgressService.instance.personalBests();
      if (mounted) setState(() => _bests = list);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '$e');
      }
    }
  }

  /// The translated label for a record type.
  ///
  /// Falls back to the raw key rather than hiding the row: a record type the
  /// app does not know about is still a record the user earned.
  static String _label(String recordType) {
    const keys = {
      'max_weight': 'label_pr_max_weight',
      'max_reps': 'label_pr_max_reps',
      'max_volume': 'label_pr_max_volume',
      'max_duration': 'label_pr_max_duration',
      'max_distance': 'label_pr_max_distance',
      'estimated_1rm': 'label_pr_estimated_1rm',
    };
    final key = keys[recordType];
    return key == null ? recordType : tr(key);
  }

  static String _num(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bests = _bests;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          tr('title_personal_records'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: _load, child: Text(tr('btn_retry'))),
                ],
              ),
            )
          : bests == null
              ? Center(
                  child: CircularProgressIndicator(color: colors.primary1))
              : bests.isEmpty
                  ? _emptyState(colors)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildList(colors, bests),
                    ),
    );
  }

  Widget _emptyState(BodifyColors colors) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/img/achievements/trophy.png',
                height: 56,
                width: 56,
                color: colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(tr('msg_no_records_yet'),
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(tr('msg_no_records_hint'),
                style:
                    TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
        ),
      );

  Widget _buildList(BodifyColors colors, List<PersonalBest> bests) {
    // Grouped by exercise: five record types for one lift belong together,
    // and a flat list would read as five unrelated achievements.
    final grouped = <int, List<PersonalBest>>{};
    for (final best in bests) {
      grouped.putIfAbsent(best.exerciseId, () => []).add(best);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        for (final entry in grouped.entries) ...[
          _exerciseCard(colors, entry.value),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _exerciseCard(BodifyColors colors, List<PersonalBest> records) {
    final name = records.first.name ?? '#${records.first.exerciseId}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_label(record.recordType),
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                  ),
                  Text(
                    '${_num(record.value)} ${translateUnit(record.unit)}',
                    style: TextStyle(
                        color: colors.primary1,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Text(_date(record.achievedAt),
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
