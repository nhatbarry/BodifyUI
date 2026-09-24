import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';
import 'food_detail_view.dart';

/// Picks one food and the amount of it, and logs it.
///
/// The amount step is not optional and not a guess. The catalog holds two
/// kinds of row that scale differently - a dish per serving, an ingredient per
/// 100 g - so the sheet reads [FoodSummary.allowedUnits] and offers only the
/// units that food can actually be logged in. A dish whose serving weight was
/// never published offers servings alone, because grams genuinely cannot be
/// converted for it.
class FoodPickerSheet extends StatefulWidget {
  final DateTime date;
  final MealType mealType;

  const FoodPickerSheet({super.key, required this.date, required this.mealType});

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<FoodSummary> _results = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // 400 ms, the same as the exercise explorer: long enough not to fire on
    // every keystroke, short enough that the list feels live.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searched = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await MealService.instance.searchFoods(search: query);
      if (!mounted) return;
      setState(() {
        _results = found;
        _searched = true;
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

  Future<void> _pick(FoodSummary food) async {
    final amount = await showModalBottomSheet<_Amount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmountSheet(food: food),
    );
    if (amount == null || !mounted) return;

    try {
      await MealService.instance.logItem(
        date: widget.date,
        mealType: widget.mealType,
        foodId: food.foodId,
        quantity: amount.quantity,
        unit: amount.unit,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // The server refuses a unit the food cannot be measured in and says
      // which one to use instead; showing that verbatim is more useful than a
      // generic failure.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.of('title_add_food'),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                autofocus: true,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: AppStrings.of('hint_search_foods'),
                  hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(scrollController)),
          ],
        ),
      ),
    );
  }

  Widget _body(ScrollController controller) {
    final colors = context.colors;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _hint(_error!, Icons.cloud_off);
    }
    if (!_searched) {
      return _hint(AppStrings.of('msg_search_foods_prompt'), Icons.search);
    }
    if (_results.isEmpty) {
      return _hint(AppStrings.of('msg_no_foods_found'), Icons.no_food);
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: colors.textSecondary.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final food = _results[index];
        return _FoodRow(food: food, onTap: () => _pick(food));
      },
    );
  }

  Widget _hint(String text, IconData icon) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodSummary food;
  final VoidCallback onTap;

  const _FoodRow({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Per serving or per 100 g - the number means different things and the row
    // has to say which, or a 640 kcal bowl reads like a 640 kcal spoonful.
    final per = food.isPerServing
        ? AppStrings.of('msg_per_serving')
        : AppStrings.of('msg_per_100g');

    // 289 dish names repeat across the catalog - the Institute surveyed
    // "Cháo lòng" in nine places and got 258 to 500 kcal. The serving weight
    // is what makes those rows tell each other apart on screen.
    final weight = food.servingGrams;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ExerciseThumbnail(
              url: food.imageUrl,
              // Keyed on the food, not the signed URL: the signature rotates
              // daily and the picture behind it never changes.
              cacheKey: 'food-${food.foodId}',
              size: 46,
              placeholderIcon: Icons.restaurant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${food.energyKcal.round()} ${AppStrings.of('unit_kcal')} · $per'
                    '${weight != null ? ' · ${weight.round()}${AppStrings.of('unit_gram')}' : ''}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  // What is actually in the bowl. Two rows can carry the same
                  // name and the same "per serving" and still be a different
                  // meal; this line is what says so.
                  if (food.componentNames.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      food.componentNames.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.72),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FoodDetailView(
                    foodId: food.foodId,
                    initialName: food.name,
                  ),
                ),
              ),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.info_outline, color: colors.textSecondary, size: 20),
            ),
            Icon(Icons.add_circle_outline, color: colors.primary1, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Amount {
  const _Amount(this.quantity, this.unit);

  final double quantity;
  final MealUnit unit;
}

/// How much of it. Opens on a sensible default - one serving, or 100 g - so
/// the common case is one tap.
class _AmountSheet extends StatefulWidget {
  final FoodSummary food;

  const _AmountSheet({required this.food});

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late MealUnit _unit = widget.food.defaultUnit;
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.food.defaultQuantity),
  );

  String _format(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _quantity {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// What this amount works out to, recomputed as the user types.
  ///
  /// A preview only - the figure that gets stored is the server's, computed
  /// from the same catalog row. Showing it here just means nobody has to log
  /// something to find out it was the wrong amount.
  double? get _previewKcal {
    final quantity = _quantity;
    if (quantity == null) return null;
    final food = widget.food;
    if (food.isPerServing) {
      if (_unit == MealUnit.serving) return food.energyKcal * quantity;
      final grams = food.servingGrams;
      if (grams == null || grams == 0) return null;
      return food.energyKcal * (quantity / grams);
    }
    return food.energyKcal * (quantity / 100);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final food = widget.food;
    final units = food.allowedUnits;
    final preview = _previewKcal;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              food.name,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              food.isPerServing && food.servingGrams == null
                  // Worth saying plainly: this is why grams is not on offer.
                  ? AppStrings.of('msg_serving_unknown')
                  : '${food.energyKcal.round()} ${AppStrings.of('unit_kcal')} · '
                      '${food.isPerServing ? AppStrings.of('msg_per_serving') : AppStrings.of('msg_per_100g')}',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      labelText: AppStrings.of('label_amount'),
                      labelStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Only the units this food can actually be measured in. A
                // single-option toggle is rendered as a plain label rather
                // than a control that cannot change anything.
                if (units.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      AppStrings.of('unit_${units.first.name}'),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ToggleButtons(
                    isSelected: units.map((u) => u == _unit).toList(),
                    onPressed: (index) =>
                        setState(() => _unit = units[index]),
                    borderRadius: BorderRadius.circular(12),
                    constraints:
                        const BoxConstraints(minHeight: 44, minWidth: 62),
                    children: units
                        .map((u) => Text(AppStrings.of('unit_${u.name}')))
                        .toList(),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (preview != null)
              Text(
                '≈ ${preview.round()} ${AppStrings.of('unit_kcal')}',
                style: TextStyle(
                  color: colors.primary1,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _quantity == null
                    ? null
                    : () => Navigator.pop(
                        context, _Amount(_quantity!, _unit)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(AppStrings.of('btn_add_food')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
