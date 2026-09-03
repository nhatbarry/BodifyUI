import 'dart:async';

import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/app_strings.dart';
import '../../core/api_exception.dart';
import '../../models/exercise_models.dart';
import '../../services/exercise_service.dart';
import 'exercise_detail_view.dart';

class ExerciseExplorerView extends StatefulWidget {
  const ExerciseExplorerView({super.key});

  @override
  State<ExerciseExplorerView> createState() => _ExerciseExplorerViewState();
}

class _ExerciseExplorerViewState extends State<ExerciseExplorerView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ExerciseListItem> _items = [];
  ExerciseFilters? _filters;

  // The muscle filter travels as an id, not a label: labels are translated and
  // can be renamed, ids cannot.
  int? _muscleGroupId;
  String? _experienceLevel;

  int _page = 1;
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFilters();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await ExerciseService.instance.getFilters();
      if (mounted) setState(() => _filters = filters);
    } on ApiException {
      // The list still works without the filter chips.
    }
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Search on a debounce so typing does not fire a request per keystroke.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
      });
    }

    try {
      final result = await ExerciseService.instance.listExercises(
        page: _page,
        search: _searchController.text,
        muscleGroup: _muscleGroupId?.toString(),
        experienceLevel: _experienceLevel,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _total = result.total;
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
    if (_isLoading || _isLoadingMore || _items.length >= _total) return;
    setState(() => _isLoadingMore = true);
    _page += 1;
    await _load();
    if (mounted) setState(() => _isLoadingMore = false);
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
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        title: Text(
          tr('exercises'),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(15)),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
                  border: InputBorder.none,
                  hintText: tr('searchExercises'),
                  hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: context.colors.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: context.colors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _load(reset: true);
                          },
                        ),
                ),
              ),
            ),
          ),
          if (_filters != null) _buildFilterChips(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  _isLoading ? tr('loading') : "$_total ${tr('exerciseCount')}",
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // Two rows rather than one long strip: levels and muscle groups are
    // independent filters, and mixing them in a single scroller meant scrolling
    // past the levels to reach any muscle.
    return Column(
      children: [
        _chipRow([
          for (final level in _filters!.experienceLevels)
            _chip(level, _experienceLevel == level, () => _toggleLevel(level)),
        ]),
        const SizedBox(height: 6),
        // Every muscle group, not a truncated slice: the row scrolls
        // horizontally, and cutting the list hid common filters ("Cơ ngực" sat
        // at position 15).
        _chipRow([
          for (final muscle in _filters!.muscleGroups)
            _chip(muscle.name, _muscleGroupId == muscle.id,
                () => _toggleMuscle(muscle.id)),
        ]),
      ],
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: chips,
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: context.colors.primaryGradient)
                : null,
            color: selected ? null : context.colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.colors.surface : context.colors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: context.colors.primary1));
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: context.colors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(reset: true),
                child: Text(tr('retry'),
                    style: TextStyle(color: context.colors.primary1)),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(tr('noExercisesFound'),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _items.length + (_items.length < _total ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(color: context.colors.primary1)),
          );
        }
        return _ExerciseRow(
          item: _items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseDetailView(exerciseId: _items[index].exerciseId),
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseListItem item;
  final VoidCallback onTap;

  const _ExerciseRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            ExerciseThumbnail(
              url: item.listImageUrl,
              cacheKey: item.listImageCacheKey,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name ?? "#${item.exerciseId}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [item.experienceLevel, item.exerciseType, item.mechanics]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(" · "),
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
