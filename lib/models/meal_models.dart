/// The food catalog and the diary logged against it.
///
/// The one thing to carry through every screen here is [FoodSummary.basis]. A
/// `per_100g` row publishes its nutrition per 100 g and is logged in grams; a
/// `per_serving` row publishes it per serving and is logged in servings.
/// Offering the wrong input is how a food app reports double somebody's
/// intake, so the widgets read `basis` rather than guessing from the name.
library;

/// Which of the four sittings an entry belongs to.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  static MealType fromApi(String value) => MealType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => MealType.snack,
      );

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
    required this.mealType,
    required this.items,
    required this.totals,
    this.note,
    this.photoKey,
  });

  final int mealId;
  final DateTime loggedDate;
  final MealType mealType;
  final String? note;

  /// A storage key, not a URL. Nothing uploads one yet - the diary shows a
  /// placeholder where the picture will go.
  final String? photoKey;

  final List<MealItem> items;
  final NutritionTotals totals;

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        mealId: json['meal_id'] as int,
        loggedDate: DateTime.parse(json['logged_date'] as String),
        mealType: MealType.fromApi(json['meal_type'] as String? ?? 'snack'),
        note: json['note'] as String?,
        photoKey: json['photo_key'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: NutritionTotals.fromJson(
            json['totals'] as Map<String, dynamic>?),
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
    this.target,
    this.remainingKcal,
  });

  final DateTime loggedDate;
  final List<Meal> meals;
  final NutritionTotals totals;

  /// Null when the user has never set one.
  final NutritionTarget? target;

  /// Null rather than 0 when there is no target: "none left" and "you never
  /// said what you were aiming for" are different answers.
  final double? remainingKcal;

  Meal? mealOf(MealType type) {
    for (final meal in meals) {
      if (meal.mealType == type) return meal;
    }
    return null;
  }

  factory DayDiary.fromJson(Map<String, dynamic> json) => DayDiary(
        loggedDate: DateTime.parse(json['logged_date'] as String),
        meals: (json['meals'] as List<dynamic>? ?? [])
            .map((e) => Meal.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: NutritionTotals.fromJson(
            json['totals'] as Map<String, dynamic>?),
        target: json['target'] == null
            ? null
            : NutritionTarget.fromJson(json['target'] as Map<String, dynamic>),
        remainingKcal: _toDouble(json['remaining_kcal']),
      );
}
