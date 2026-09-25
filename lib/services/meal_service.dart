import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/meal_models.dart';
import 'auth_service.dart';

/// The food catalog and the signed-in user's diary.
///
/// `user_id` is taken from the token by the backend and never sent by the app,
/// the same rule every other service here follows.
class MealService {
  MealService._();

  static final MealService instance = MealService._();

  final http.Client _client = http.Client();

  Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) async {
    final token = await AuthService.instance.validAccessToken();
    if (token == null) {
      throw const ApiException('Not signed in', statusCode: 401);
    }

    http.Response response;
    try {
      response = await request(token).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException('Cannot reach the server. Is the backend running?');
    }

    // Refresh once and retry rather than bouncing the user to the login screen.
    if (response.statusCode == 401) {
      final session = await AuthService.instance.refreshSession();
      if (session == null) {
        throw const ApiException('Session expired', statusCode: 401);
      }
      try {
        response = await request(session.accessToken)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const ApiException('Cannot reach the server. Is the backend running?');
      }
    }

    return response;
  }

  dynamic _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(
      parseErrorMessage(decoded, fallback: 'Request failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ----------------------------------------------------------------------
  // Catalog
  // ----------------------------------------------------------------------

  /// GET /foods - search the catalog.
  ///
  /// Accents are stripped server-side, so "banh mi" finds "bánh mì".
  Future<List<FoodSummary>> searchFoods({
    String? search,
    String? basis,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/foods').replace(queryParameters: {
            if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
            if (basis != null) 'basis': basis,
            'page': '$page',
            'limit': '$limit',
          }),
          headers: {'Authorization': 'Bearer $token'},
        ));

    final json = _decode(response) as Map<String, dynamic>;
    return (json['items'] as List<dynamic>)
        .map((e) => FoodSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /foods/{id} - one food, with what it was made of.
  Future<FoodDetail> foodDetail(int foodId) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/foods/$foodId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return FoodDetail.fromJson(_decode(response) as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------------
  // The diary
  // ----------------------------------------------------------------------

  /// GET /meals/calendar?from=&to= - what each date adds up to, eaten and
  /// planned, for the month calendar. Keyed by date (time stripped).
  Future<Map<DateTime, CalendarDay>> calendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/meals/calendar').replace(queryParameters: {
            'from': _day(from),
            'to': _day(to),
          }),
          headers: {'Authorization': 'Bearer $token'},
        ));
    final days = (_decode(response) as List<dynamic>)
        .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>));
    return {for (final d in days) d.date: d};
  }

  /// GET /meals?date= - one day, with totals and the target to compare against.
  Future<DayDiary> day(DateTime date) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/meals')
              .replace(queryParameters: {'date': _day(date)}),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return DayDiary.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /meals - add a meal to a day. A null [name] leaves it unnamed, so
  /// the screen shows the "Bữa N" placeholder.
  Future<Meal> createMeal({required DateTime date, String? name}) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/meals'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'logged_date': _day(date), 'name': name}),
        ));
    return Meal.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /meal-items - log or plan a food into a meal.
  Future<MealItem> logItem({
    required int mealId,
    required int foodId,
    required double quantity,
    required MealUnit unit,
    ItemStatus status = ItemStatus.eaten,
  }) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/meal-items'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'meal_id': mealId,
            'food_id': foodId,
            'quantity': quantity,
            'unit': unit.api,
            'status': status.api,
          }),
        ));
    return MealItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// POST /meal-items/custom - a food the catalog does not have, typed in by
  /// hand. The figures are per serving; [quantity] is how many servings.
  Future<MealItem> logCustomItem({
    required int mealId,
    required String name,
    required double energyKcal,
    double? proteinG,
    double? fatG,
    double? carbG,
    double quantity = 1,
    ItemStatus status = ItemStatus.eaten,
  }) async {
    final response = await _send((token) => _client.post(
          ApiConfig.path('/meal-items/custom'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'meal_id': mealId,
            'name': name,
            'energy_kcal': energyKcal,
            if (proteinG != null) 'protein_g': proteinG,
            if (fatG != null) 'fat_g': fatG,
            if (carbG != null) 'carb_g': carbG,
            'quantity': quantity,
            'status': status.api,
          }),
        ));
    return MealItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// GET /meal-items/recent - what the user logged lately, newest first,
  /// each food once. The picker shows these before anything is typed.
  Future<List<RecentFood>> recentFoods({int limit = 15}) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/meal-items/recent')
              .replace(queryParameters: {'limit': '$limit'}),
          headers: {'Authorization': 'Bearer $token'},
        ));
    return (_decode(response) as List<dynamic>)
        .map((e) => RecentFood.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /meal-items/{id}/status - tick a planned food as eaten (optionally in
  /// a different amount), or put it back on the plan.
  Future<MealItem> setItemStatus({
    required int mealItemId,
    required ItemStatus status,
    double? quantity,
    MealUnit? unit,
  }) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/meal-items/$mealItemId/status'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'status': status.api,
            if (quantity != null) 'quantity': quantity,
            if (unit != null) 'unit': unit.api,
          }),
        ));
    return MealItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /meal-items/{id} - correct an amount. The food itself is not
  /// swappable; that is a delete and a fresh entry.
  Future<MealItem> updateItem({
    required int mealItemId,
    required double quantity,
    required MealUnit unit,
  }) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/meal-items/$mealItemId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'quantity': quantity, 'unit': unit.api}),
        ));
    return MealItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /meal-items/{id}
  Future<void> deleteItem(int mealItemId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/meal-items/$mealItemId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode != 204) _decode(response);
  }

  /// PUT /meals/{id} - the name, note and photo belong to the meal.
  ///
  /// Omitting a field keeps it. A cleared name is `clearName: true`, because
  /// null on its own means "leave it" here and "clear it" on the wire.
  Future<void> updateMeal({
    required int mealId,
    String? name,
    bool clearName = false,
    String? note,
    String? photoKey,
  }) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/meals/$mealId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            if (clearName) 'name': null else if (name != null) 'name': name,
            if (note != null) 'note': note,
            if (photoKey != null) 'photo_key': photoKey,
          }),
        ));
    _decode(response);
  }

  /// DELETE /meals/{id} - removes the sitting and everything logged in it.
  Future<void> deleteMeal(int mealId) async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/meals/$mealId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode != 204) _decode(response);
  }

  // ----------------------------------------------------------------------
  // Target
  // ----------------------------------------------------------------------

  /// GET /nutrition-targets - null when none has been set.
  Future<NutritionTarget?> target() async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/nutrition-targets'),
          headers: {'Authorization': 'Bearer $token'},
        ));

    // 404 is the normal empty state, not an error.
    if (response.statusCode == 404) return null;
    return NutritionTarget.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// PUT /nutrition-targets - replaces the target rather than patching it.
  Future<NutritionTarget> setTarget({
    required double energyKcal,
    double? proteinG,
    double? fatG,
    double? carbG,
  }) async {
    final response = await _send((token) => _client.put(
          ApiConfig.path('/nutrition-targets'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'energy_kcal': energyKcal,
            if (proteinG != null) 'protein_g': proteinG,
            if (fatG != null) 'fat_g': fatG,
            if (carbG != null) 'carb_g': carbG,
          }),
        ));
    return NutritionTarget.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// DELETE /nutrition-targets - stop tracking against a target. The diary
  /// itself is untouched.
  Future<void> deleteTarget() async {
    final response = await _send((token) => _client.delete(
          ApiConfig.path('/nutrition-targets'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode != 204) _decode(response);
  }

  // ----------------------------------------------------------------------
  // History
  // ----------------------------------------------------------------------

  /// GET /nutrition/summary?from=&to= - daily totals across a range. Days with
  /// nothing logged are absent from the result, not zero.
  Future<List<DaySummary>> summary({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _send((token) => _client.get(
          ApiConfig.path('/nutrition/summary').replace(queryParameters: {
            'from': _day(from),
            'to': _day(to),
          }),
          headers: {'Authorization': 'Bearer $token'},
        ));
    final json = _decode(response) as List<dynamic>;
    return json
        .map((e) => DaySummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
