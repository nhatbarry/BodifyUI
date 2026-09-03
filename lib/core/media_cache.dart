import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for exercise catalog media.
///
/// The defaults are wrong for this app in both directions that matter:
///
/// * `maxNrOfCacheObjects` defaults to 200. The catalog has 688 thumbnails, so
///   a user who browses past 200 exercises starts evicting pictures they will
///   scroll back to, and the cache spends its time re-downloading its own
///   contents.
/// * `stalePeriod` defaults to 30 days. Exercise media is immutable - the
///   picture for an exercise is the same file forever - so expiring it only
///   buys a repeat download.
///
/// Sized against the real payload: ~64 KB median per thumbnail, so 1200
/// objects is roughly 75 MB worst case, and only for someone who has actually
/// looked at the whole catalog.
class MediaCache {
  const MediaCache._();

  static const String _key = 'bodify-exercise-media';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 1200,
    ),
  );

  /// Demonstration clips, kept apart from the pictures on purpose.
  ///
  /// A clip is ~1.7 MB against a 7 KB icon, so sharing one store would let a
  /// handful of videos evict hundreds of icons and undo the thing that makes
  /// list scrolling cheap. Sixty files is a few recent exercises' worth.
  ///
  /// Videos are downloaded in full before playback rather than streamed. The
  /// catalog's mp4s are not faststart - the moov index sits after the media
  /// data - so a streaming player has to fetch the tail before it can do
  /// anything, and every scrub becomes another range request over the
  /// network. Playing from a local file makes seeking instant and a repeat
  /// view free.
  static final CacheManager videos = CacheManager(
    Config(
      'bodify-exercise-video',
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 60,
    ),
  );

  /// Opens the cache's database before the first screen needs it.
  ///
  /// Each cached image is an async lookup in a sqflite store, and the very
  /// first one pays for opening that database. On a cold start that lands
  /// exactly when the explorer is trying to draw twelve rows at once, so every
  /// row sits on a spinner over files that are already on disk. Doing the
  /// open once at launch, off the critical path, moves that cost out of the
  /// way. Failure is not worth reporting - a cold lookup later just pays the
  /// cost it would have paid anyway.
  static Future<void> warmUp() async {
    try {
      await Future.wait([
        instance.getFileFromCache('warmup'),
        videos.getFileFromCache('warmup'),
      ]);
    } catch (_) {
      // Ignored on purpose: this is an optimisation, not a requirement.
    }
  }

  /// Drops every cached picture and clip. Nothing calls this yet; it is what a
  /// "clear cache" setting would use.
  static Future<void> clear() async {
    await instance.emptyCache();
    await videos.emptyCache();
  }
}
