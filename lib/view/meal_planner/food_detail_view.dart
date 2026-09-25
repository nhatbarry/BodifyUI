import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/media_cache.dart';
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

  /// Width / height of the photo, once it has been decoded.
  double? _aspect;

  /// Margin around the rounded picture.
  static const double _cardInset = 16;

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
      final url = detail.summary.imageUrl;
      if (url != null && _aspect == null) _measure(url, detail.summary.foodId);
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
    if (_loading || _error != null) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.textPrimary),
          title: Text(
            widget.initialName ?? '',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ErrorState(message: _error!, onRetry: _load),
      );
    }
    return Scaffold(
      backgroundColor: colors.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            _header(_detail!.summary),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList.list(children: _content(_detail!)),
            ),
          ],
        ),
      ),
    );
  }

  /// Reads the photo's real proportions so the header can match them.
  ///
  /// The Institute's photos are information cards - the dish plus a table of
  /// its ingredients and their weights - and their shapes vary from 1.1:1 to
  /// 2.1:1. Any fixed height either crops the table (cover) or letterboxes
  /// it; sizing the header to the picture shows all of it, edge to edge.
  /// Resolved through the same cache the list uses, so it costs nothing extra.
  void _measure(String url, int foodId) {
    final stream = CachedNetworkImageProvider(
      url,
      cacheKey: 'food-$foodId',
      cacheManager: MediaCache.instance,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!mounted || info.image.height == 0) return;
        setState(() => _aspect = info.image.width / info.image.height);
      },
      onError: (_, __) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  /// The picture spans the full width at its own proportions and folds into
  /// the app bar on scroll. Rows with no picture (every per-100 g ingredient)
  /// get a short plate banner rather than a large empty box.
  Widget _header(FoodSummary food) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final hasImage = food.imageUrl != null;
    // Until the picture is decoded, a typical card's 16:10; never so tall
    // that the recipe is pushed off the first screen.
    // The picture is a rounded card inset from the screen edges, so its width
    // - and from it the header's height - is the screen minus both margins.
    final imageWidth = media.size.width - 2 * _cardInset;
    // The picture starts below the toolbar, so the back button has a row of
    // its own - as on every other screen - instead of sitting on the card.
    final picture = hasImage
        ? (imageWidth / (_aspect ?? 1.6))
            .clamp(120.0, media.size.height * 0.55)
            .toDouble()
        : 140.0;
    final expanded = kToolbarHeight + picture + _cardInset;
    final collapsedAt = kToolbarHeight + media.padding.top + 8;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expanded,
      backgroundColor: colors.surface,
      elevation: 0,
      iconTheme: IconThemeData(color: colors.textPrimary),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxHeight <= collapsedAt;
          return FlexibleSpaceBar(
            // The name only once the picture has folded away; over the photo
            // it would cover the part worth looking at.
            title: collapsed
                ? Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  )
                : null,
            titlePadding: const EdgeInsetsDirectional.only(
                start: 64, bottom: 16, end: 16),
            // Below the status bar and the toolbar: the cards carry labels in
            // their top corners, and neither the clock nor the back button
            // should sit on them.
            background: Padding(
              padding: EdgeInsets.fromLTRB(_cardInset,
                  media.padding.top + kToolbarHeight, _cardInset, _cardInset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: hasImage ? _photo(food) : _plateBanner(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _photo(FoodSummary food) {
    final colors = context.colors;
    return CachedNetworkImage(
      imageUrl: food.imageUrl!,
      // Same key as the list thumbnails, so the file already on
      // disk from the picker is reused rather than refetched.
      cacheKey: 'food-${food.foodId}',
      cacheManager: MediaCache.instance,
      // The header is sized to the picture, so contain fills it exactly;
      // cover would crop the ingredient table the card exists to show.
      fit: BoxFit.contain,
      placeholder: (_, __) => Container(
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: colors.primary1),
      ),
      errorWidget: (_, __, ___) => _plateBanner(),
    );
  }

  Widget _plateBanner() {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary1.withValues(alpha: 0.25),
            colors.primary2.withValues(alpha: 0.15),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, size: 56, color: colors.primary1),
    );
  }

  List<Widget> _content(FoodDetail detail) {
    final colors = context.colors;
    final food = detail.summary;
    final per = food.isPerServing ? tr('msg_per_serving') : tr('msg_per_100g');

    return [
      Text(
        food.name,
        style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700),
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
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700),
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
    ];
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
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: colors.textSecondary, fontSize: 11)),
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
