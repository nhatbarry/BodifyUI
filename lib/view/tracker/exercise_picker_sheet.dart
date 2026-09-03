import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/exercise_models.dart';
import '../../services/exercise_service.dart';

/// Picks the exercises for one date.
///
/// Opens with everything already on that date ticked, and returns the complete
/// list of ticks - so unticking is how an exercise is taken off the date. The
/// caller sends the whole list to the server, which keeps the rows that
/// survived and with them their target sets.
///
/// Selections are held as ids, not list positions: the catalog list is paged,
/// filtered and searched underneath, so a chosen exercise routinely scrolls
/// out of the loaded window and must stay ticked when it comes back.
class ExercisePickerSheet extends StatefulWidget {
  final List<int> initialSelection;

  const ExercisePickerSheet({super.key, required this.initialSelection});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Ordered, because the order the user ticks in becomes the order the
  /// exercises sit in on the day.
  late final List<int> _selected = List<int>.from(widget.initialSelection);

  ExerciseFilters? _filters;
  final List<ExerciseListItem> _items = [];

  int? _muscleGroupId;
  String? _experienceLevel;

  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await ExerciseService.instance.getFilters();
      if (mounted) setState(() => _filters = filters);
    } on ApiException {
      // Filters are a convenience; the list still works without the chips.
    }
  }

  void _onSearchChanged(String _) {
    // 400 ms, same as the explorer: typing "ngực" would otherwise fire a
    // request per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400),
        () => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });

    try {
      final result = await ExerciseService.instance.listExercises(
        page: _page,
        limit: 20,
        search: _searchController.text,
        muscleGroup: _muscleGroupId?.toString(),
        experienceLevel: _experienceLevel,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    _page += 1;
    await _load();
  }

  void _toggle(ExerciseListItem item) {
    setState(() {
      if (!_selected.remove(item.exerciseId)) {
        _selected.add(item.exerciseId);
      }
    });
  }

  void _toggleMuscle(int id) {
    setState(() => _muscleGroupId = _muscleGroupId == id ? null : id);
    _load(reset: true);
  }

  void _toggleLevel(String level) {
    setState(() => _experienceLevel = _experienceLevel == level ? null : level);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sheetController) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            _buildSearch(),
            if (_filters != null) ...[
              const SizedBox(height: 8),
              _buildFilterChips(),
            ],
            const SizedBox(height: 8),
            Expanded(child: _buildList(sheetController)),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr('pickExercises'),
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (_selected.isNotEmpty)
            Text(
              tr('selectedCount').replaceFirst('{n}', '${_selected.length}'),
              style: TextStyle(color: colors.primary1, fontSize: 12),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: colors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: tr('searchExercises'),
          hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
          prefixIcon:
              Icon(Icons.search, color: colors.textSecondary, size: 20),
          isDense: true,
          filled: true,
          fillColor: colors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    // Two rows rather than one strip, matching the explorer: levels and muscle
    // groups are independent filters and should not be scrolled past.
    return Column(
      children: [
        _chipRow([
          for (final level in _filters!.experienceLevels)
            _chip(level, _experienceLevel == level, () => _toggleLevel(level)),
        ]),
        const SizedBox(height: 6),
        _chipRow([
          for (final muscle in _filters!.muscleGroups)
            _chip(muscle.name, _muscleGroupId == muscle.id,
                () => _toggleMuscle(muscle.id)),
        ]),
      ],
    );
  }

  Widget _chipRow(List<Widget> chips) => SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: chips,
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient:
                selected ? LinearGradient(colors: colors.primaryGradient) : null,
            color: selected ? null : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ScrollController sheetController) {
    final colors = context.colors;

    if (_isLoading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.primary1));
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => _load(reset: true),
                  child: Text(tr('retry'))),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(tr('noExercisesFound'),
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      );
    }

    // The sheet's own controller drives the drag; a second controller on the
    // same list would fight it, so paging listens to the sheet's instead.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
        return false;
      },
      child: ListView.builder(
        controller: sheetController,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.primary1),
              )),
            );
          }
          final item = _items[i];
          return _PickerRow(
            item: item,
            selected: _selected.contains(item.exerciseId),
            onTap: () => _toggle(item),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selected.isEmpty
                    ? tr('emptySelectionClearsDay')
                    : tr('selectedCount')
                        .replaceFirst('{n}', '${_selected.length}'),
                style:
                    TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary1,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              ),
              child: Text(tr('save'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final ExerciseListItem item;
  final bool selected;
  final VoidCallback onTap;

  const _PickerRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                activeColor: colors.primary1,
                checkColor: colors.onPrimary,
              ),
              ExerciseThumbnail(
                url: item.listImageUrl,
                cacheKey: item.listImageCacheKey,
                size: 42,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? '#${item.exerciseId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    if (item.experienceLevel != null) ...[
                      const SizedBox(height: 2),
                      Text(item.experienceLevel!,
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
