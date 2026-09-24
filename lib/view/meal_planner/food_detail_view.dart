import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';

/// The full recipe behind a catalog row.
///
/// The picker list shows only the first 6 ingredient names, with no weights -
/// `GET /foods/{id}` is the one call that returns [FoodComponent.grams], so
/// this is the only screen that can show them.
class FoodDetailView extends StatefulWidget {
  final int foodId;
  final String? initialName;

  const FoodDetailView({super.key, required this.foodId, this.initialName});

  @override
  State<FoodDetailView> createState() => _FoodDetailViewState();
}

class _FoodDetailViewState extends State<FoodDetailView> {
  FoodDetail? _detail;
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
    try {
      final detail = await MealService.instance.foodDetail(widget.foodId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          widget.initialName ?? _detail?.summary.name ?? '',
          style: TextStyle(
              color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _body(_detail!),
    );
  }

  Widget _body(FoodDetail detail) {
    final colors = context.colors;
    final food = detail.summary;
    final per = food.isPerServing ? tr('msg_per_serving') : tr('msg_per_100g');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: ExerciseThumbnail(
              url: food.imageUrl,
              cacheKey: 'food-${food.foodId}',
              size: 120,
              placeholderIcon: Icons.restaurant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            food.name,
            style: TextStyle(
                color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${food.energyKcal.round()} ${tr('unit_kcal')} · $per'
            '${food.servingGrams != null ? ' · ${food.servingGrams!.round()}${tr('unit_gram')}' : ''}',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Macro(label: tr('label_protein'), grams: food.proteinG),
              _Macro(label: tr('label_fat'), grams: food.fatG),
              _Macro(label: tr('label_carb'), grams: food.carbG),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr('label_ingredients'),
            style: TextStyle(
                color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (detail.components.isEmpty)
            Text(
              tr('msg_no_components'),
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            )
          else
            for (final component in detail.components)
              _ComponentRow(component: component),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final double? grams;

  const _Macro({required this.label, required this.grams});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              grams == null ? '—' : '${grams!.round()}${tr('unit_gram')}',
              style: TextStyle(
                  color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final FoodComponent component;

  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              component.nameVi,
              style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
            ),
          ),
          if (component.grams != null)
            Text(
              '${component.grams!.round()}${tr('unit_gram')}',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 38, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: Text(tr('btn_retry'))),
          ],
        ),
      ),
    );
  }
}
