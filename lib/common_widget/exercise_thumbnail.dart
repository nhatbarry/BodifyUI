import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/media_cache.dart';

/// A catalog exercise's image, downloaded once and then read from disk.
///
/// Why this is not `Image.network`:
///
/// * `Image.network` caches only in memory. The cache is gone the moment the
///   app restarts, so every cold start re-downloads every picture the user
///   scrolls past - about 100 KB each.
/// * The media lives in R2 behind a presigned URL. The signature carries a
///   timestamp, so the URL for one file is a *different string* every day, and
///   any cache keyed on the URL would miss even within one session. `cacheKey`
///   pins the entry to the exercise instead, so a rotated signature reuses the
///   file already on disk rather than fetching it again.
/// * The catalog is immutable - the picture for an exercise never changes -
///   which is what makes caching by exercise id correct rather than merely
///   convenient.
///
/// The placeholder is shown until a frame is actually decoded. A bare image
/// widget paints nothing while a request is in flight, which reads on screen
/// as a missing image rather than a slow one.
class ExerciseThumbnail extends StatelessWidget {
  final String? url;

  /// Stable identity for the cached file, independent of the signed URL.
  /// Pass the exercise id; media kinds get their own prefix.
  final String cacheKey;

  final double size;
  final double radius;

  const ExerciseThumbnail({
    super.key,
    required this.url,
    required this.cacheKey,
    this.size = 46,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget placeholder({bool spinning = false}) => Container(
          color: colors.surfaceVariant,
          alignment: Alignment.center,
          child: spinning
              ? SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.primary1),
                )
              : Icon(Icons.fitness_center,
                  color: colors.primary1, size: size * 0.42),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? placeholder()
            : CachedNetworkImage(
                imageUrl: url!,
                cacheKey: cacheKey,
                cacheManager: MediaCache.instance,
                fit: BoxFit.cover,
                // No fade on a cache hit: the file is already there, and an
                // animation would make an instant load look slow.
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => placeholder(spinning: true),
                errorWidget: (_, __, ___) => placeholder(),
              ),
      ),
    );
  }
}
