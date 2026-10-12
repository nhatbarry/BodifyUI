/// The food catalog and the diary logged against it.
///
/// The one thing to carry through every screen here is [FoodSummary.basis]. A
/// `per_100g` row publishes its nutrition per 100 g and is logged in grams; a
/// `per_serving` row publishes it per serving and is logged in servings.
/// Offering the wrong input is how a food app reports double somebody's
/// intake, so the widgets read `basis` rather than guessing from the name.
library;

/// Whether a food has been eaten yet.
///
/// A planned food is ticked when it is eaten. Only eaten food counts toward
/// the day's total and the target; the plan is kept beside the actual so the
/// two can be compared.
enum ItemStatus {
  planned,
  eaten;

  static ItemStatus fromApi(String value) =>
      value == 'planned' ? ItemStatus.planned : ItemStatus.eaten;

  String get api => name;
}

/// What an amount is counted in. Which one is allowed depends on the food.
enum MealUnit {
  serving,
  gram;

  static MealUnit fromApi(String value) =>
      value == 'gram' ? MealUnit.gram : MealUnit.serving;

  String get api => name;
}

double? _toDouble(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());

double _toDoubleOr0(dynamic value) => _toDouble(value) ?? 0;

class FoodSummary {
  const FoodSummary({
    required this.foodId,
    required this.name,
    required this.basis,
    required this.energyKcal,
    this.proteinG,
    this.fatG,
    this.carbG,
    this.fiberG,
    this.servingGrams,
    this.servingSource,
    this.categoryName,
    this.imageUrl,
    this.componentNames = const [],
  });

  final int foodId;
  final String name;

  /// `per_100g` or `per_serving`.
  final String basis;

  /// Per 100 g or per serving, according to [basis].
  final double energyKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;
  final double? fiberG;

  /// Only meaningful for `per_serving`, and null for the 237 dishes whose
  /// label never published a weight - those can only be logged in servings.
  final double? servingGrams;
  final String? servingSource;

  final String? categoryName;
  final String? imageUrl;

  /// The first few ingredients, for telling same-named dishes apart.
  ///
  /// The Institute publishes no description for any dish - the field
  /// exists and is empty in all 1247 - so this breakdown, read off their
  /// own label images, is the only thing that distinguishes three rows all
  /// reading "Phở gà": one is 600 g of broth, another has two kinds of egg
  /// in it. Empty for per-100 g ingredients, which have no recipe.
  final List<String> componentNames;

  bool get isPerServing => basis == 'per_serving';

  /// Which units this food can actually be logged in.
  ///
  /// A dish is always loggable in servings, and additionally in grams when its
  /// serving weight is known. An ingredient is grams only - nobody published
  /// what one serving of raw pork is.
  List<MealUnit> get allowedUnits {
    if (!isPerServing) return const [MealUnit.gram];
    return servingGrams == null
        ? const [MealUnit.serving]
        : const [MealUnit.serving, MealUnit.gram];
  }

  MealUnit get defaultUnit =>
      isPerServing ? MealUnit.serving : MealUnit.gram;

  /// The amount a fresh log dialog should start on: one serving, or a round
  /// 100 g, whichever suits the row.
  double get defaultQuantity => isPerServing ? 1 : 100;

  factory FoodSummary.fromJson(Map<String, dynamic> json) => FoodSummary(
        foodId: json['food_id'] as int,
        name: json['name'] as String? ?? '',
        basis: json['basis'] as String? ?? 'per_100g',
        energyKcal: _toDoubleOr0(json['energy_kcal']),
        proteinG: _toDouble(json['protein_g']),
        fatG: _toDouble(json['fat_g']),
        carbG: _toDouble(json['carb_g']),
        fiberG: _toDouble(json['fiber_g']),
        servingGrams: _toDouble(json['serving_grams']),
        servingSource: json['serving_source'] as String?,
        categoryName: json['category_name'] as String?,
        imageUrl: json['image_url'] as String?,
        componentNames: (json['component_names'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// A hand-typed food as it was last entered, per serving.
class CustomFood {
  const CustomFood({
    required this.name,
    required this.energyKcal,
    this.proteinG,
    this.fatG,
    this.carbG,
  });

  final String name;
  final double energyKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;

  factory CustomFood.fromJson(Map<String, dynamic> json) => CustomFood(
        name: json['name'] as String? ?? '',
        energyKcal: _toDoubleOr0(json['energy_kcal']),
        proteinG: _toDouble(json['protein_g']),
        fatG: _toDouble(json['fat_g']),
        carbG: _toDouble(json['carb_g']),
      );
}

/// Something eaten before, for logging it again in one tap. Exactly one of
/// [food] and [custom] is set.
class RecentFood {
  const RecentFood({
    required this.lastQuantity,
    required this.lastUnit,
    this.food,
    this.custom,
  });

  final FoodSummary? food;
  final CustomFood? custom;

  /// How much was had last time - the likeliest amount now.
  final double lastQuantity;
  final MealUnit lastUnit;

  factory RecentFood.fromJson(Map<String, dynamic> json) => RecentFood(
        food: json['food'] == null
            ? null
            : FoodSummary.fromJson(json['food'] as Map<String, dynamic>),
        custom: json['custom'] == null
            ? null
            : CustomFood.fromJson(json['custom'] as Map<String, dynamic>),
        lastQuantity: _toDoubleOr0(json['last_quantity']),
        lastUnit: MealUnit.fromApi(json['last_unit'] as String? ?? 'serving'),
      );
}

class FoodComponent {
  const FoodComponent({required this.nameVi, this.grams});

  final String nameVi;
  final double? grams;

  factory FoodComponent.fromJson(Map<String, dynamic> json) => FoodComponent(
        nameVi: json['name_vi'] as String? ?? '',
        grams: _toDouble(json['grams']),
      );
}

class FoodDetail {
  const FoodDetail({required this.summary, this.components = const []});

  final FoodSummary summary;
  final List<FoodComponent> components;

  factory FoodDetail.fromJson(Map<String, dynamic> json) => FoodDetail(
        summary: FoodSummary.fromJson(json),
        components: (json['components'] as List<dynamic>? ?? [])
            .map((e) => FoodComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MealItem {
  const MealItem({
    required this.mealItemId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.energyKcal,
    this.status = ItemStatus.eaten,
    this.isCustom = false,
    this.plannedQuantity,
    this.plannedUnit,
    this.plannedEnergyKcal,
    this.foodId,
    this.grams,
    this.proteinG,
    this.fatG,
    this.carbG,
    this.fiberG,
  });

  final int mealItemId;

  /// Null once the food has been removed from the catalog. [foodName] is a
  /// snapshot taken when it was logged, so the entry still says what was
  /// eaten.
  final int? foodId;
  final String foodName;

  final double quantity;
  final MealUnit unit;

  /// Null when the weight is genuinely unknown, not zero.
  final double? grams;

  final double energyKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;
  final double? fiberG;

  final ItemStatus status;

  /// Typed in by hand rather than picked from the catalog. [foodId] is null
  /// then, and the amount can still be edited - it scales from the entry's
  /// own per-serving figures.
  final bool isCustom;

  /// What was planned, kept after the item is eaten so the two can be
  /// compared. All null for something that was never planned.
  final double? plannedQuantity;
  final MealUnit? plannedUnit;
  final double? plannedEnergyKcal;

  bool get isPlanned => status == ItemStatus.planned;
  bool get hasPlan => plannedQuantity != null;

  /// Eaten in a different amount from what was planned.
  bool get differsFromPlan =>
      !isPlanned &&
      hasPlan &&
      (plannedQuantity != quantity || plannedUnit != unit);

  /// The same item at another status or amount - what the diary draws while
  /// the write is in flight. Macros scale with energy, which is how the server
  /// rescales them too (quantity x the same per-unit figures).
  MealItem copyWith({
    ItemStatus? status,
    double? quantity,
    MealUnit? unit,
    double? energyKcal,
    double? plannedEnergyKcal,
  }) {
    final ratio = (energyKcal == null || this.energyKcal == 0)
        ? 1.0
        : energyKcal / this.energyKcal;
    double? scale(double? v) => v == null ? null : v * ratio;
    return MealItem(
      mealItemId: mealItemId,
      foodId: foodId,
      foodName: foodName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      grams: scale(grams),
      energyKcal: energyKcal ?? this.energyKcal,
      proteinG: scale(proteinG),
      fatG: scale(fatG),
      carbG: scale(carbG),
      fiberG: scale(fiberG),
      status: status ?? this.status,
      isCustom: isCustom,
      plannedQuantity: plannedQuantity,
      plannedUnit: plannedUnit,
      plannedEnergyKcal: plannedEnergyKcal ?? this.plannedEnergyKcal,
    );
  }

  /// What `PUT /meal-items/{id}/status` will answer, predicted: ticking keeps
  /// the amount; putting back restores the planned amount and its kcal.
  MealItem toggled() => isPlanned
      ? copyWith(status: ItemStatus.eaten)
      : copyWith(
          status: ItemStatus.planned,
          quantity: plannedQuantity,
          unit: plannedUnit,
          energyKcal: plannedEnergyKcal,
        );

  factory MealItem.fromJson(Map<String, dynamic> json) => MealItem(
        mealItemId: json['meal_item_id'] as int,
        foodId: json['food_id'] as int?,
        foodName: json['food_name'] as String? ?? '',
        quantity: _toDoubleOr0(json['quantity']),
        unit: MealUnit.fromApi(json['unit'] as String? ?? 'serving'),
        grams: _toDouble(json['grams']),
        energyKcal: _toDoubleOr0(json['energy_kcal']),
        proteinG: _toDouble(json['protein_g']),
        fatG: _toDouble(json['fat_g']),
        carbG: _toDouble(json['carb_g']),
        fiberG: _toDouble(json['fiber_g']),
        status: ItemStatus.fromApi(json['status'] as String? ?? 'eaten'),
        isCustom: json['is_custom'] as bool? ?? false,
        plannedQuantity: _toDouble(json['planned_quantity']),
        plannedUnit: json['planned_unit'] == null
            ? null
            : MealUnit.fromApi(json['planned_unit'] as String),
        plannedEnergyKcal: _toDouble(json['planned_energy_kcal']),
      );
}

class NutritionTotals {
  const NutritionTotals({
    this.energyKcal = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.carbG = 0,
    this.fiberG = 0,
  });

  final double energyKcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double fiberG;

  /// The server's rule, repeated so the diary can redraw before it answers:
  /// only eaten food counts, and a macro nobody published counts as nothing.
  factory NutritionTotals.ofEaten(Iterable<MealItem> items) {
    double e = 0, p = 0, f = 0, c = 0, fi = 0;
    for (final i in items.where((i) => !i.isPlanned)) {
      e += i.energyKcal;
      p += i.proteinG ?? 0;
      f += i.fatG ?? 0;
      c += i.carbG ?? 0;
      fi += i.fiberG ?? 0;
    }
    return NutritionTotals(
        energyKcal: e, proteinG: p, fatG: f, carbG: c, fiberG: fi);
  }

  factory NutritionTotals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NutritionTotals();
    return NutritionTotals(
      energyKcal: _toDoubleOr0(json['energy_kcal']),
      proteinG: _toDoubleOr0(json['protein_g']),
      fatG: _toDoubleOr0(json['fat_g']),
      carbG: _toDoubleOr0(json['carb_g']),
      fiberG: _toDoubleOr0(json['fiber_g']),
    );
  }
}

class Meal {
  const Meal({
    required this.mealId,
    required this.loggedDate,
    required this.position,
    required this.items,
    required this.totals,
    this.name,
    this.note,
    this.photoKey,
    this.plannedKcal = 0,
  });

  final int mealId;
  final DateTime loggedDate;

  /// Null until the user names it - the screen draws "Bữa 1", "Bữa 2" by
  /// position as a placeholder, so nothing is stored the user did not write.
  final String? name;
  final int position;
  final String? note;

  /// A storage key, not a URL. Nothing uploads one yet - the diary shows a
  /// placeholder where the picture will go.
  final String? photoKey;

  final List<MealItem> items;

  /// What was eaten. Planned items are not in it.
  final NutritionTotals totals;

  /// What the plan said this meal would come to, eaten yet or not.
  final double plannedKcal;

  /// The server's `_planned_kcal`: the plan snapshot of every item that had
  /// one, eaten or not.
  static double plannedKcalOf(Iterable<MealItem> items) => items.fold(
      0.0, (sum, i) => sum + (i.plannedEnergyKcal ?? 0));

  /// This meal with other items, name or note; totals are recomputed rather
  /// than carried, so they can never disagree with the items drawn.
  Meal copyWith({
    int? mealId,
    List<MealItem>? items,
    String? name,
    bool clearName = false,
    String? note,
  }) {
    final next = items ?? this.items;
    return Meal(
      mealId: mealId ?? this.mealId,
      loggedDate: loggedDate,
      position: position,
      items: next,
      totals: NutritionTotals.ofEaten(next),
      name: clearName ? null : (name ?? this.name),
      note: note ?? this.note,
      photoKey: photoKey,
      plannedKcal: plannedKcalOf(next),
    );
  }

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        mealId: json['meal_id'] as int,
        loggedDate: DateTime.parse(json['logged_date'] as String),
        name: json['name'] as String?,
        position: json['position'] as int? ?? 0,
        note: json['note'] as String?,
        photoKey: json['photo_key'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: NutritionTotals.fromJson(
            json['totals'] as Map<String, dynamic>?),
        plannedKcal: _toDoubleOr0(json['planned_kcal']),
      );
}

class NutritionTarget {
  const NutritionTarget({
    required this.energyKcal,
    this.proteinG,
    this.fatG,
    this.carbG,
  });

  final double energyKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;

  factory NutritionTarget.fromJson(Map<String, dynamic> json) => NutritionTarget(
        energyKcal: _toDoubleOr0(json['energy_kcal']),
        proteinG: _toDouble(json['protein_g']),
        fatG: _toDouble(json['fat_g']),
        carbG: _toDouble(json['carb_g']),
      );
}

/// One day of `GET /nutrition/summary` - a date and what it added up to.
/// Only dates with at least one logged item are returned; a day absent from
/// the list is a day nothing was tracked, not a day of zero intake.
class DaySummary {
  const DaySummary({
    required this.loggedDate,
    required this.energyKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.fiberG,
    required this.mealCount,
  });

  final DateTime loggedDate;
  final double energyKcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double fiberG;
  final int mealCount;

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
        loggedDate: DateTime.parse(json['logged_date'] as String),
        energyKcal: _toDoubleOr0(json['energy_kcal']),
        proteinG: _toDoubleOr0(json['protein_g']),
        fatG: _toDoubleOr0(json['fat_g']),
        carbG: _toDoubleOr0(json['carb_g']),
        fiberG: _toDoubleOr0(json['fiber_g']),
        mealCount: json['meal_count'] as int? ?? 0,
      );
}

/// One day of the diary.
class DayDiary {
  const DayDiary({
    required this.loggedDate,
    required this.meals,
    required this.totals,
    this.plannedKcal = 0,
    this.target,
    this.remainingKcal,
  });

  final DateTime loggedDate;

  /// In display order.
  final List<Meal> meals;

  /// What was eaten.
  final NutritionTotals totals;

  /// What the plan said the day would come to. A future day has nothing eaten
  /// yet, so this is the number it has to show against the target.
  final double plannedKcal;

  /// Null when the user has never set one.
  final NutritionTarget? target;

  /// Null rather than 0 when there is no target: "none left" and "you never
  /// said what you were aiming for" are different answers.
  final double? remainingKcal;

  /// The same day with other meals, every total recomputed the way
  /// `GET /meals` computes it.
  DayDiary withMeals(List<Meal> next) {
    final items = [for (final m in next) ...m.items];
    final totals = NutritionTotals.ofEaten(items);
    return DayDiary(
      loggedDate: loggedDate,
      meals: next,
      totals: totals,
      plannedKcal: Meal.plannedKcalOf(items),
      target: target,
      remainingKcal:
          target == null ? null : target!.energyKcal - totals.energyKcal,
    );
  }

  factory DayDiary.fromJson(Map<String, dynamic> json) => DayDiary(
        loggedDate: DateTime.parse(json['logged_date'] as String),
        meals: (json['meals'] as List<dynamic>? ?? [])
            .map((e) => Meal.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: NutritionTotals.fromJson(
            json['totals'] as Map<String, dynamic>?),
        plannedKcal: _toDoubleOr0(json['planned_kcal']),
        target: json['target'] == null
            ? null
            : NutritionTarget.fromJson(json['target'] as Map<String, dynamic>),
        remainingKcal: _toDouble(json['remaining_kcal']),
      );
}

/// One date on the diary's month calendar. Only dates with at least one food
/// come back from the API, so a missing date means nothing was logged.
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.eatenKcal,
    required this.plannedKcal,
    required this.eatenCount,
    required this.plannedCount,
  });

  final DateTime date;
  final double eatenKcal;
  final double plannedKcal;
  final int eatenCount;
  final int plannedCount;

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    final d = DateTime.parse(json['logged_date'] as String);
    return CalendarDay(
      date: DateTime(d.year, d.month, d.day),
      eatenKcal: _toDoubleOr0(json['eaten_kcal']),
      plannedKcal: _toDoubleOr0(json['planned_kcal']),
      eatenCount: json['eaten_count'] as int? ?? 0,
      plannedCount: json['planned_count'] as int? ?? 0,
    );
  }
}
