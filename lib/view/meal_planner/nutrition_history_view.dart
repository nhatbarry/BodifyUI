import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/latest_workout_section.dart' show HistoryRange;
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';

/// Totals per day across a range - the gap `GET /nutrition/summary` was built
/// for and nothing called yet.
///
/// Days with nothing logged are simply absent from the list, matching the
/// API: a day the user did not track is not a day they ate nothing.
class NutritionHistoryView extends StatefulWidget {
  const NutritionHistoryView({super.key});

  @override
  State<NutritionHistoryView> createState() => _NutritionHistoryViewState();
}

class _NutritionHistoryViewState extends State<NutritionHistoryView> {
  HistoryRange _range = HistoryRange.week;
  List<DaySummary> _days = const [];
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
      final days = await MealService.instance.summary(
        from: today.subtract(Duration(days: _range.days - 1)),
        to: today,
      );
      if (!mounted) return;
      setState(() {
        _days = days.reversed.toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
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
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          tr('title_nutrition_history'),
          style: TextStyle(
              color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [for (final range in HistoryRange.values) _rangeChip(range)],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
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

  Widget _body() {
    final colors = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _message(_error!);
    if (_days.isEmpty) return _message(tr('msg_no_nutrition_in_range'));

    final avgKcal =
        _days.map((d) => d.energyKcal).reduce((a, b) => a + b) / _days.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          '${tr('label_average')}: ${avgKcal.round()} ${tr('unit_kcal')}/${tr('label_day')}',
          style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        for (final day in _days) _DayRow(day: day),
      ],
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ),
      );
}

class _DayRow extends StatelessWidget {
  final DaySummary day;

  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = day.loggedDate;
    final label =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.proteinG.round()}${tr('unit_gram')} ${tr('label_protein').toLowerCase()} · '
                  '${day.fatG.round()}${tr('unit_gram')} ${tr('label_fat').toLowerCase()} · '
                  '${day.carbG.round()}${tr('unit_gram')} ${tr('label_carb').toLowerCase()}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '${day.energyKcal.round()} ${tr('unit_kcal')}',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
