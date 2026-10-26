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
///
/// A food goes into a meal the user already created, either as eaten or as
/// planned. [defaultStatus] is what the amount sheet opens on - planned for a
/// day that has not come yet, eaten otherwise - and the user can flip it.
class FoodPickerSheet extends StatefulWidget {
  final int mealId;
  final ItemStatus defaultStatus;

  /// Offered as a camera button in the header. The picker closes first and
  /// the caller runs the photo flow, which has a sheet of its own.
  final VoidCallback? onPhoto;

  const FoodPickerSheet({
    super.key,
    required this.mealId,
    this.defaultStatus = ItemStatus.eaten,
    this.onPhoto,
  });

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;

  /// What the user logged lately. Shown only while nothing is typed - most
  /// meals repeat, and the usual breakfast should not need a search.
  List<RecentFood> _recent = const [];

  /// The catalog, or the search hits once something is typed. Paged: the
  /// catalog is 2098 rows and a first screen needs 25 of them.
  List<FoodSummary> _results = const [];
  String _query = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final results = await Future.wait([
        MealService.instance.recentFoods(),
        MealService.instance.searchFoods(page: 1, limit: _pageSize),
      ]);
      if (!mounted) return;
      final page = results[1] as List<FoodSummary>;
      setState(() {
        _recent = results[0] as List<RecentFood>;
        _results = page;
        _page = 1;
        _hasMore = page.length == _pageSize;
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

  void _onQueryChanged(String value) {
    // 400 ms, the same as the exercise explorer: long enough not to fire on
    // every keystroke, short enough that the list feels live.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final term = query.trim();
    setState(() {
      _query = term;
      _loading = true;
      _error = null;
    });
    try {
      final page = await MealService.instance.searchFoods(
        search: term.isEmpty ? null : term,
        page: 1,
        limit: _pageSize,
      );
      // A slower, older request must not overwrite what the newer one found.
      if (!mounted || term != _query) return;
      setState(() {
        _results = page;
        _page = 1;
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || term != _query) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final term = _query;
    setState(() => _loadingMore = true);
    try {
      final page = await MealService.instance.searchFoods(
        search: term.isEmpty ? null : term,
        page: _page + 1,
        limit: _pageSize,
      );
      if (!mounted || term != _query) return;
      setState(() {
        _results = [..._results, ...page];
        _page += 1;
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
      });
    } on ApiException {
      // The rows already shown stay usable; the next scroll tries again.
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _pick(
    FoodSummary food, {
    double? quantity,
    MealUnit? unit,
  }) async {
    final amount = await showModalBottomSheet<_Amount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmountSheet(
        food: food,
        defaultStatus: widget.defaultStatus,
        // The amount had last time, when it can still be logged in that unit.
        initialQuantity:
            unit != null && food.allowedUnits.contains(unit) ? quantity : null,
        initialUnit:
            unit != null && food.allowedUnits.contains(unit) ? unit : null,
      ),
    );
    if (amount == null || !mounted) return;

    try {
      await MealService.instance.logItem(
        mealId: widget.mealId,
        foodId: food.foodId,
        quantity: amount.quantity,
        unit: amount.unit,
        status: amount.status,
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

  /// A food the catalog does not have. Opens on whatever was typed into the
  /// search box, since that is usually its name.
  Future<void> _enterManually({CustomFood? from, double? quantity}) async {
    final entry = await showModalBottomSheet<_CustomEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomFoodSheet(
        initialName: from?.name ?? _searchController.text.trim(),
        initial: from,
        initialQuantity: quantity,
        defaultStatus: widget.defaultStatus,
      ),
    );
    if (entry == null || !mounted) return;

    try {
      await MealService.instance.logCustomItem(
        mealId: widget.mealId,
        name: entry.name,
        energyKcal: entry.energyKcal,
        proteinG: entry.proteinG,
        fatG: entry.fatG,
        carbG: entry.carbG,
        quantity: entry.quantity,
        status: entry.status,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
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
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
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
                  if (widget.onPhoto != null)
                    IconButton(
                      tooltip: AppStrings.of('btn_meal_photo'),
                      onPressed: () {
                        Navigator.pop(context, false);
                        widget.onPhoto!();
                      },
                      icon: Icon(Icons.photo_camera_outlined,
                          color: colors.primary1),
                    ),
                  TextButton.icon(
                    onPressed: () => _enterManually(),
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: Text(AppStrings.of('btn_custom_food')),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _hint(_error!, Icons.cloud_off);
    }

    final showRecent = _query.isEmpty && _recent.isNotEmpty;
    final rows = <Widget>[
      if (showRecent) ...[
        _SectionHeader(AppStrings.of('label_recent_foods')),
        for (final recent in _recent)
          if (recent.food != null)
            FoodListRow(
              food: recent.food!,
              onTap: () => _pick(
                recent.food!,
                quantity: recent.lastQuantity,
                unit: recent.lastUnit,
              ),
            )
          else if (recent.custom != null)
            _CustomRow(
              food: recent.custom!,
              onTap: () => _enterManually(
                from: recent.custom,
                quantity: recent.lastQuantity,
              ),
            ),
        _SectionHeader(AppStrings.of('label_all_foods')),
      ],
      for (final food in _results)
        FoodListRow(food: food, onTap: () => _pick(food)),
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (_query.isNotEmpty && _results.isEmpty)
        _hint(AppStrings.of('msg_no_foods_found'), Icons.no_food),
      // Always within reach at the end of the list: whatever the catalog is
      // missing can still be logged.
      if (!_hasMore || _results.isEmpty)
        _ManualEntryTile(onTap: () => _enterManually()),
    ];

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _loadMore();
        return false;
      },
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: rows,
      ),
    );
  }

  Widget _hint(String text, IconData icon) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ManualEntryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _ManualEntryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_note),
        label: Text(AppStrings.of('msg_custom_food_hint')),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary1,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// A recent hand-typed food. No picture and no recipe - it is only what the
/// user said it was.
class _CustomRow extends StatelessWidget {
  final CustomFood food;
  final VoidCallback onTap;

  const _CustomRow({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_note, color: colors.textSecondary),
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
                    '${food.energyKcal.round()} ${AppStrings.of('unit_kcal')} · '
                    '${AppStrings.of('msg_per_serving')} · ${AppStrings.of('label_custom_tag')}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, color: colors.primary1, size: 22),
          ],
        ),
      ),
    );
  }
}

/// One catalog food: picture, name, what the figure is per, and the first
/// ingredients. Shared by the picker (tap to log; ⓘ opens the recipe) and the
/// catalog browser, which passes [browsing] - there a tap opens the recipe
/// and there is nothing to add to.
class FoodListRow extends StatelessWidget {
  final FoodSummary food;
  final VoidCallback onTap;
  final bool browsing;

  const FoodListRow({
    super.key,
    required this.food,
    required this.onTap,
    this.browsing = false,
  });

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
            if (browsing)
              Icon(Icons.chevron_right, color: colors.textSecondary)
            else ...[
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
                icon: Icon(Icons.info_outline,
                    color: colors.textSecondary, size: 20),
              ),
              Icon(Icons.add_circle_outline, color: colors.primary1, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _Amount {
  const _Amount(this.quantity, this.unit, this.status);

  final double quantity;
  final MealUnit unit;
  final ItemStatus status;
}

/// How much of it. Opens on a sensible default - one serving, or 100 g - so
/// the common case is one tap.
class _AmountSheet extends StatefulWidget {
  final FoodSummary food;
  final ItemStatus defaultStatus;
  final double? initialQuantity;
  final MealUnit? initialUnit;

  const _AmountSheet({
    required this.food,
    required this.defaultStatus,
    this.initialQuantity,
    this.initialUnit,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late MealUnit _unit = widget.initialUnit ?? widget.food.defaultUnit;
  late ItemStatus _status = widget.defaultStatus;
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.initialQuantity ?? widget.food.defaultQuantity),
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
            // Eaten or only planned. Defaults from the day being looked at, but
            // a plan for tonight can be made on today's screen, so it is a
            // choice rather than something inferred.
            SegmentedButton<ItemStatus>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ItemStatus.eaten,
                  label: Text(AppStrings.of('label_eaten')),
                ),
                ButtonSegment(
                  value: ItemStatus.planned,
                  label: Text(AppStrings.of('label_status_planned')),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (value) =>
                  setState(() => _status = value.first),
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
                        context, _Amount(_quantity!, _unit, _status)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_status == ItemStatus.planned
                    ? AppStrings.of('btn_plan_food')
                    : AppStrings.of('btn_add_food')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomEntry {
  const _CustomEntry({
    required this.name,
    required this.energyKcal,
    required this.quantity,
    required this.status,
    this.proteinG,
    this.fatG,
    this.carbG,
  });

  final String name;
  final double energyKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;
  final double quantity;
  final ItemStatus status;
}

/// A food typed in by hand.
///
/// Figures are asked for **per serving**, the way a label or a menu states
/// them, and the number of servings separately - so the total can be shown as
/// it is typed and nobody has to multiply in their head. Only the name and the
/// energy are required; macros nobody knows are left blank rather than
/// guessed.
class _CustomFoodSheet extends StatefulWidget {
  final String initialName;
  final CustomFood? initial;
  final double? initialQuantity;
  final ItemStatus defaultStatus;

  const _CustomFoodSheet({
    required this.initialName,
    required this.defaultStatus,
    this.initial,
    this.initialQuantity,
  });

  @override
  State<_CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends State<_CustomFoodSheet> {
  static String _text(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
          ? v.round().toString()
          : '$v';

  late final _name = TextEditingController(text: widget.initialName);
  late final _kcal = TextEditingController(text: _text(widget.initial?.energyKcal));
  late final _protein = TextEditingController(text: _text(widget.initial?.proteinG));
  late final _fat = TextEditingController(text: _text(widget.initial?.fatG));
  late final _carb = TextEditingController(text: _text(widget.initial?.carbG));
  late final _servings =
      TextEditingController(text: _text(widget.initialQuantity ?? 1));
  late ItemStatus _status = widget.defaultStatus;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _fat, _carb, _servings]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  double? get _total {
    final kcal = _num(_kcal);
    final servings = _num(_servings);
    if (kcal == null || servings == null || servings <= 0) return null;
    return kcal * servings;
  }

  void _submit() {
    final name = _name.text.trim();
    final kcal = _num(_kcal);
    final servings = _num(_servings);
    if (name.isEmpty) {
      setState(() => _error = AppStrings.of('error_name_required'));
      return;
    }
    if (kcal == null || kcal < 0) {
      setState(() => _error = AppStrings.of('error_kcal_required'));
      return;
    }
    // The server's own limits, checked here so a slipped digit gets a plain
    // sentence instead of a validation dump.
    final macros = [_num(_protein), _num(_fat), _num(_carb)];
    if (kcal > 10000 ||
        macros.any((m) => m != null && (m < 0 || m > 1000)) ||
        servings == null ||
        servings <= 0 ||
        servings > 100) {
      setState(() => _error = AppStrings.of('error_invalid_number'));
      return;
    }
    Navigator.pop(
      context,
      _CustomEntry(
        name: name,
        energyKcal: kcal,
        proteinG: _num(_protein),
        fatG: _num(_fat),
        carbG: _num(_carb),
        quantity: servings,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = _total;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.of('title_custom_food'),
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _field(_name, AppStrings.of('label_food_name'),
                  required: true, text: true, autofocus: widget.initialName.isEmpty),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(_kcal, AppStrings.of('label_kcal_per_serving'),
                        required: true,
                        autofocus: widget.initialName.isNotEmpty &&
                            widget.initial == null),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _field(_servings, AppStrings.of('label_servings')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_protein, AppStrings.of('label_protein'))),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_fat, AppStrings.of('label_fat'))),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_carb, AppStrings.of('label_carb'))),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<ItemStatus>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ItemStatus.eaten,
                    label: Text(AppStrings.of('label_eaten')),
                  ),
                  ButtonSegment(
                    value: ItemStatus.planned,
                    label: Text(AppStrings.of('label_status_planned')),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (value) =>
                    setState(() => _status = value.first),
              ),
              if (total != null) ...[
                const SizedBox(height: 14),
                Text(
                  '= ${total.round()} ${AppStrings.of('unit_kcal')}',
                  style: TextStyle(
                      color: colors.primary1,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 12)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_status == ItemStatus.planned
                      ? AppStrings.of('btn_plan_food')
                      : AppStrings.of('btn_add_food')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool text = false,
    bool autofocus = false,
  }) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: text ? 200 : null,
      buildCounter: text
          ? (_, {required currentLength, required isFocused, maxLength}) => null
          : null,
      textCapitalization:
          text ? TextCapitalization.sentences : TextCapitalization.none,
      keyboardType: text
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() => _error = null),
      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: colors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
