import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';
import 'food_detail_view.dart';
import 'food_picker_sheet.dart';

/// The food catalog, for looking around rather than logging.
///
/// Opened from the search button beside the exercise catalog. Nothing here
/// writes to the diary - that needs a meal and a date, which the diary itself
/// has - so a tap opens the recipe.
class FoodExplorerView extends StatefulWidget {
  const FoodExplorerView({super.key});

  @override
  State<FoodExplorerView> createState() => _FoodExplorerViewState();
}

enum _Basis {
  all(null, 'label_filter_all'),
  dishes('per_serving', 'label_basis_dishes'),
  ingredients('per_100g', 'label_basis_ingredients');

  const _Basis(this.api, this.labelKey);

  final String? api;
  final String labelKey;
}

class _FoodExplorerViewState extends State<FoodExplorerView>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;

  _Basis _basis = _Basis.all;
  List<FoodSummary> _items = const [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Identifies the request whose answer the screen should show; an older,
  /// slower one arriving late is dropped.
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? get _query {
    final text = _searchController.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await MealService.instance.searchFoods(
        search: _query,
        basis: _basis.api,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = page;
        _page = 1;
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await MealService.instance.searchFoods(
        search: _query,
        basis: _basis.api,
        page: _page + 1,
        limit: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...page];
        _page += 1;
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
    setState(() {}); // the clear button follows the text
  }

  void _select(_Basis basis) {
    if (basis == _basis) return;
    setState(() => _basis = basis);
    _reload();
  }

  void _open(FoodSummary food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailView(foodId: food.foodId, initialName: food.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
                border: InputBorder.none,
                hintText: tr('hint_search_foods'),
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                prefixIcon:
                    Icon(Icons.search, color: colors.textSecondary, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close,
                            color: colors.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _reload();
                        },
                      ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final basis in _Basis.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tr(basis.labelKey)),
                    selected: basis == _basis,
                    onSelected: (_) => _select(basis),
                    showCheckmark: false,
                    selectedColor: colors.primary1,
                    labelStyle: TextStyle(
                      color: basis == _basis
                          ? colors.onPrimary
                          : colors.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          basis == _basis ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: colors.surfaceVariant,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    final colors = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _reload, child: Text(tr('btn_retry'))),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(tr('msg_no_foods_found'),
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colors.textSecondary.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final food = _items[index];
          return FoodListRow(food: food, browsing: true, onTap: () => _open(food));
        },
      ),
    );
  }
}
