
import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';
import 'food_detail_view.dart';
import 'food_picker_sheet.dart';
import 'meal_calendar_sheet.dart';
import 'nutrition_history_view.dart';
import 'nutrition_target_sheet.dart';

/// One day of eating: the user's own meals, what they add up to, and the target.
///
/// A day has as many meals as the user made. A meal with no name is drawn as
/// "Bữa 1", "Bữa 2" by its place in the day - the placeholder is this screen's
/// to draw, nothing is stored for it. Any date can be opened, the future
/// included: that is where a plan is made. Each food is either planned or
/// eaten; ticking a planned food marks it eaten, and only eaten food counts
/// toward the total and the target.
class MealDiaryView extends StatefulWidget {
  const MealDiaryView({super.key});

  @override
  State<MealDiaryView> createState() => MealDiaryViewState();
}

class MealDiaryViewState extends State<MealDiaryView> {
  DateTime _date = DateTime.now();
  DayDiary? _diary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public so the tab can refresh it after something else changes the diary.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final diary = await MealService.instance.day(_date);
      if (!mounted) return;
      setState(() {
        _diary = diary;
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

  void _shiftDay(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
    _load();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isToday => _dateOnly(_date) == _dateOnly(DateTime.now());

  bool get _isTomorrow =>
      _dateOnly(_date) ==
      _dateOnly(DateTime.now().add(const Duration(days: 1)));

  /// Nothing can have been eaten on a day that has not happened, so foods added
  /// there start as planned and cannot be ticked.
  bool get _isFuture => _dateOnly(_date).isAfter(_dateOnly(DateTime.now()));

  String _placeholderName(int index) =>
      AppStrings.of('label_meal_placeholder').replaceFirst('{n}', '${index + 1}');

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addMeal() async {
    final nextIndex = _diary?.meals.length ?? 0;
    final choice = await showModalBottomSheet<_NameChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealNameSheet(
        title: AppStrings.of('title_new_meal'),
        confirmLabel: AppStrings.of('btn_create'),
        placeholder: _placeholderName(nextIndex),
      ),
    );
    if (choice == null) return;

    try {
      await MealService.instance.createMeal(date: _date, name: choice.name);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _renameMeal(Meal meal, int index) async {
    final choice = await showModalBottomSheet<_NameChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealNameSheet(
        title: AppStrings.of('title_rename_meal'),
        confirmLabel: AppStrings.of('btn_save'),
        placeholder: _placeholderName(index),
        initial: meal.name,
      ),
    );
    if (choice == null) return;

    try {
      await MealService.instance.updateMeal(
        mealId: meal.mealId,
        name: choice.name,
        // A blank name goes back to the placeholder rather than to "".
        clearName: choice.name == null,
      );
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _addFood(Meal meal) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodPickerSheet(
        mealId: meal.mealId,
        defaultStatus: _isFuture ? ItemStatus.planned : ItemStatus.eaten,
      ),
    );
    if (added == true) {
      await _load();
      _toast(AppStrings.of('toast_food_logged'));
    }
  }

  /// Tick a planned food as eaten, or put an eaten one back on the plan.
  Future<void> _toggleItem(MealItem item) async {
    if (item.isPlanned && _isFuture) {
      _toast(AppStrings.of('msg_cannot_tick_future'));
      return;
    }
    try {
      await MealService.instance.setItemStatus(
        mealItemId: item.mealItemId,
        status: item.isPlanned ? ItemStatus.eaten : ItemStatus.planned,
      );
      await _load();
      _toast(AppStrings.of(
          item.isPlanned ? 'toast_marked_eaten' : 'toast_back_to_plan'));
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _removeItem(MealItem item) async {
    try {
      await MealService.instance.deleteItem(item.mealItemId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of('toast_item_removed'))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editTarget() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NutritionTargetSheet(current: _diary?.target),
    );
    if (saved == true) await _load();
  }

  Future<void> _editItem(MealItem item) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditItemSheet(item: item),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of('toast_item_updated'))),
      );
    }
  }

  void _viewFood(MealItem item) {
    final foodId = item.foodId;
    if (foodId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailView(foodId: foodId, initialName: item.foodName),
      ),
    );
  }

  Future<void> _editNote(Meal meal) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealNoteSheet(meal: meal),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of('toast_meal_note_saved'))),
      );
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(AppStrings.of('title_delete_meal'),
            style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
        content: Text(
          AppStrings.of('msg_delete_meal_confirm'),
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of('btn_cancel'),
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of('btn_delete'),
                style: const TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await MealService.instance.deleteMeal(meal.mealId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of('toast_meal_deleted'))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealCalendarSheet(selected: _date),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _load();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NutritionHistoryView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _diary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _diary == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final diary = _diary;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _DayBar(
            date: _date,
            isToday: _isToday,
            isTomorrow: _isTomorrow,
            onPrevious: () => _shiftDay(-1),
            // The future is open: that is where a plan is made.
            onNext: () => _shiftDay(1),
            onHistory: _openHistory,
            onPickDate: _pickDate,
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            totals: diary?.totals ?? const NutritionTotals(),
            plannedKcal: diary?.plannedKcal ?? 0,
            target: diary?.target,
            remainingKcal: diary?.remainingKcal,
            onEditTarget: _editTarget,
          ),
          const SizedBox(height: 18),
          if (diary == null || diary.meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Text(
                AppStrings.of('msg_no_meals_yet'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              ),
            ),
          for (final entry in (diary?.meals ?? const <Meal>[]).indexed) ...[
            _MealSection(
              name: entry.$2.name ?? _placeholderName(entry.$1),
              meal: entry.$2,
              onAdd: () => _addFood(entry.$2),
              onRemoveItem: _removeItem,
              onEditItem: _editItem,
              onViewItem: _viewFood,
              onToggleItem: _toggleItem,
              onRename: () => _renameMeal(entry.$2, entry.$1),
              onEditNote: _editNote,
              onDeleteMeal: _deleteMeal,
            ),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            onPressed: _addMeal,
            icon: const Icon(Icons.add),
            label: Text(AppStrings.of('btn_add_meal')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------

class _DayBar extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isTomorrow;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onHistory;
  final VoidCallback onPickDate;

  const _DayBar({
    required this.date,
    required this.isToday,
    required this.isTomorrow,
    required this.onPrevious,
    required this.onNext,
    required this.onHistory,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = isToday
        ? AppStrings.of('title_today')
        : isTomorrow
            ? AppStrings.of('title_tomorrow')
            : '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Row(
      children: [
        IconButton(
          onPressed: onHistory,
          icon: Icon(Icons.bar_chart_rounded, color: colors.textSecondary),
        ),
        IconButton(
          onPressed: onPrevious,
          icon: Icon(Icons.chevron_left, color: colors.textPrimary),
        ),
        // The date itself opens the month: stepping day by day is fine for
        // yesterday and tedious for last Tuesday.
        Expanded(
          child: InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_month,
                      size: 18, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(Icons.chevron_right, color: colors.textPrimary),
        ),
        // Balances the history icon on the left so the date stays centered.
        const SizedBox(width: 48),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final NutritionTotals totals;
  final double plannedKcal;
  final NutritionTarget? target;
  final double? remainingKcal;
  final VoidCallback onEditTarget;

  const _SummaryCard({
    required this.totals,
    required this.plannedKcal,
    required this.target,
    required this.remainingKcal,
    required this.onEditTarget,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final goal = target?.energyKcal;

    // Clamped only for the bar's width; the numbers above it are never
    // clamped, because going over a target is information, not an error.
    final progress = (goal == null || goal <= 0)
        ? 0.0
        : (totals.energyKcal / goal).clamp(0.0, 1.0);
    final over = goal != null && totals.energyKcal > goal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary1, colors.primary2]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totals.energyKcal.round().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  goal == null
                      ? AppStrings.of('unit_kcal')
                      : '/ ${goal.round()} ${AppStrings.of('unit_kcal')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // White on the brand gradient, deliberately not themed - this
              // label sits on colour, not on the surface.
              TextButton(
                onPressed: onEditTarget,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  goal == null
                      ? AppStrings.of('btn_set_target')
                      : AppStrings.of('label_target'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                over ? const Color(0xFFFFC46B) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remainingKcal == null
                ? AppStrings.of('label_no_target')
                : '${AppStrings.of('label_remaining')}: '
                    '${remainingKcal!.round()} ${AppStrings.of('unit_kcal')}',
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          if (plannedKcal > 0) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.of('label_planned_kcal')
                  .replaceFirst('{n}', '${plannedKcal.round()}'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Macro(label: AppStrings.of('label_protein'), grams: totals.proteinG),
              _Macro(label: AppStrings.of('label_fat'), grams: totals.fatG),
              _Macro(label: AppStrings.of('label_carb'), grams: totals.carbG),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final double grams;

  const _Macro({required this.label, required this.grams});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${grams.round()}${AppStrings.of('unit_gram')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final String name;
  final Meal meal;
  final VoidCallback onAdd;
  final Future<void> Function(MealItem) onRemoveItem;
  final void Function(MealItem) onEditItem;
  final void Function(MealItem) onViewItem;
  final Future<void> Function(MealItem) onToggleItem;
  final VoidCallback onRename;
  final Future<void> Function(Meal) onEditNote;
  final Future<void> Function(Meal) onDeleteMeal;

  const _MealSection({
    required this.name,
    required this.meal,
    required this.onAdd,
    required this.onRemoveItem,
    required this.onEditItem,
    required this.onViewItem,
    required this.onToggleItem,
    required this.onRename,
    required this.onEditNote,
    required this.onDeleteMeal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = meal.items;
    final kcal = AppStrings.of('unit_kcal');

    // Eaten so far, out of what was planned, once there is a plan to speak of.
    final total = meal.plannedKcal > 0
        ? '${meal.totals.energyKcal.round()} / ${meal.plannedKcal.round()} $kcal'
        : '${meal.totals.energyKcal.round()} $kcal';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // A placeholder is dimmer than a name the user typed, so
                    // it reads as a hint rather than as their own writing.
                    color: meal.name == null
                        ? colors.textSecondary
                        : colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  total,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              IconButton(
                onPressed: onAdd,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add_circle_outline,
                    color: colors.primary1, size: 22),
              ),
              PopupMenuButton<void>(
                icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 20),
                padding: EdgeInsets.zero,
                color: colors.surface,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: onRename,
                    child: Text(AppStrings.of('title_rename_meal'),
                        style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                  ),
                  PopupMenuItem(
                    onTap: () => onEditNote(meal),
                    child: Text(AppStrings.of('title_meal_note'),
                        style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                  ),
                  PopupMenuItem(
                    onTap: () => onDeleteMeal(meal),
                    child: Text(AppStrings.of('title_delete_meal'),
                        style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          if (meal.note != null && meal.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                meal.note!,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          if (meal.photoKey != null || items.isNotEmpty) ...[
            const SizedBox(height: 6),
            _PhotoPlaceholder(photoKey: meal.photoKey),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 6),
              child: Text(
                AppStrings.of('msg_nothing_logged'),
                style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
              ),
            )
          else
            for (final item in items)
              _ItemRow(
                item: item,
                onRemove: () => onRemoveItem(item),
                onEdit: () => onEditItem(item),
                onTap: item.foodId == null ? null : () => onViewItem(item),
                // An eaten food that was never planned has nothing to go back
                // to, so its check is a mark rather than a button.
                onToggle: item.isPlanned || item.hasPlan
                    ? () => onToggleItem(item)
                    : null,
              ),
        ],
      ),
    );
  }
}

/// Where a photo of the meal will go.
///
/// A placeholder on purpose: `meals.photo_key` exists and the API accepts one,
/// but nothing uploads yet - user uploads need the write-scoped R2 credential
/// and an image pipeline of their own, the way avatars do. Drawing the slot
/// now keeps the layout honest about what is coming without pretending the
/// button works.
class _PhotoPlaceholder extends StatelessWidget {
  final String? photoKey;

  const _PhotoPlaceholder({this.photoKey});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: DottedBorderBox(
        child: Row(
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 18, color: colors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.of('msg_photo_placeholder'),
                style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed-looking slot. Kept local because nothing else needs it yet.
class DottedBorderBox extends StatelessWidget {
  final Widget child;

  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }
}

class _ItemRow extends StatelessWidget {
  final MealItem item;
  final VoidCallback onRemove;
  final VoidCallback onEdit;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const _ItemRow({
    required this.item,
    required this.onRemove,
    required this.onEdit,
    this.onTap,
    this.onToggle,
  });

  static String _format(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final planned = item.isPlanned;

    final unit = AppStrings.of('unit_${item.unit.name}');
    var detail = '${_format(item.quantity)} $unit'
        // The weight is genuinely unknown for some dishes, so it is simply
        // absent rather than shown as a guess.
        '${item.grams != null ? ' · ${item.grams!.round()}${AppStrings.of('unit_gram')}' : ''}';

    if (item.isCustom) detail += ' · ${AppStrings.of('label_custom_tag')}';

    // Eaten in a different amount from the plan: say what was planned, so the
    // gap between the two is visible without opening anything.
    if (item.differsFromPlan) {
      final plannedUnit = AppStrings.of('unit_${item.plannedUnit!.name}');
      detail += ' · ${AppStrings.of('label_planned_amount').replaceFirst('{qty}', '${_format(item.plannedQuantity!)} $plannedUnit')}';
    }

    // A planned food is drawn quieter than one that happened.
    final textColor = planned ? colors.textSecondary : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              planned ? Icons.radio_button_unchecked : Icons.check_circle,
              size: 22,
              color: planned
                  ? colors.textSecondary
                  : onToggle == null
                      ? colors.textSecondary.withValues(alpha: 0.45)
                      : colors.primary1,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.foodName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${item.energyKcal.round()}',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: planned ? FontStyle.italic : FontStyle.normal,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 16, color: colors.textSecondary),
          ),
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 17, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Corrects a mistyped amount. The unit is not offered here - it is a delete
/// and a fresh entry, same rule as swapping the food itself - so the preview
/// scales linearly from the amount already logged rather than refetching the
/// food's own conversion factors.
class _EditItemSheet extends StatefulWidget {
  final MealItem item;

  const _EditItemSheet({required this.item});

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.item.quantity));

  bool _saving = false;
  String? _error;

  static String _format(double value) =>
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

  double? get _previewKcal {
    final quantity = _quantity;
    if (quantity == null || widget.item.quantity == 0) return null;
    return widget.item.energyKcal / widget.item.quantity * quantity;
  }

  Future<void> _save() async {
    final quantity = _quantity;
    if (quantity == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MealService.instance.updateItem(
        mealItemId: widget.item.mealItemId,
        quantity: quantity,
        unit: widget.item.unit,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = AppStrings.of('unit_${widget.item.unit.name}');
    final preview = _previewKcal;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.foodName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    unit,
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (preview != null)
              Text(
                '≈ ${preview.round()} ${AppStrings.of('unit_kcal')}',
                style: TextStyle(color: colors.primary1, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 12)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_quantity == null || _saving) ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.of('btn_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The note that belongs to a sitting, not to any one food in it.
class _MealNoteSheet extends StatefulWidget {
  final Meal meal;

  const _MealNoteSheet({required this.meal});

  @override
  State<_MealNoteSheet> createState() => _MealNoteSheetState();
}

class _MealNoteSheetState extends State<_MealNoteSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.meal.note ?? '');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MealService.instance.updateMeal(
        mealId: widget.meal.mealId,
        note: _controller.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.of('title_meal_note'),
              style: TextStyle(
                  color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 2000,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.of('hint_meal_note'),
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                filled: true,
                fillColor: colors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 12)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.of('btn_save')),
              ),
            ),
          ],
        ),
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
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

/// What the user chose in the name sheet. Wrapped so that "cancelled" (a null
/// result from the sheet) stays distinguishable from "left it blank", which
/// means "no name, show the placeholder".
class _NameChoice {
  const _NameChoice(this.name);

  final String? name;
}

/// Names a meal, when it is created or renamed. The placeholder the meal will
/// be drawn with ("Bữa 3") is the hint, so leaving the field empty visibly
/// means "keep that".
class _MealNameSheet extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String placeholder;
  final String? initial;

  const _MealNameSheet({
    required this.title,
    required this.confirmLabel,
    required this.placeholder,
    this.initial,
  });

  @override
  State<_MealNameSheet> createState() => _MealNameSheetState();
}

class _MealNameSheetState extends State<_MealNameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.pop(context, _NameChoice(text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                  color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: AppStrings.of('label_meal_name'),
                labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                hintText: widget.placeholder,
                hintStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
