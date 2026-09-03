import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../core/media_cache.dart';

/// The demonstration clip for one exercise.
///
/// Nothing is fetched until the user taps play. The clips are 1-2 MB against a
/// 6 KB list icon, so loading one on every page open would undo the work that
/// made the catalog cheap to browse - and most visits to this screen are to
/// read the instructions, not to watch the movement.
///
/// The clip is **downloaded in full and played from disk**, not streamed. The
/// catalog's mp4s are not faststart - `moov`, the seek index, sits after
/// `mdat` - so a streaming player must fetch the tail of the file before it
/// can start, and every scrub costs another range request across the network.
/// Dragging the progress bar was unusable that way. From a local file seeking
/// is instant, and a second viewing costs nothing.
///
/// The poster is the icon the list already cached, so the section is drawn
/// from disk with no request at all until it is actually wanted.
class ExerciseVideo extends StatefulWidget {
  final String url;

  /// Stable identity for the downloaded clip, independent of the signed URL,
  /// which is re-signed daily.
  final String cacheKey;

  /// Shown before playback starts. Pass the same url/key the list row used so
  /// the poster is already on disk.
  final String? posterUrl;
  final String posterCacheKey;

  const ExerciseVideo({
    super.key,
    required this.url,
    required this.cacheKey,
    required this.posterUrl,
    required this.posterCacheKey,
  });

  @override
  State<ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<ExerciseVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  /// 0..1 while downloading, null once the file is in hand. Only meaningful
  /// on a cache miss - a clip already on disk skips straight past it.
  double? _downloadProgress;

  /// Initialised from the disk cache but not yet started, so the play button
  /// has nothing to wait for.
  VideoPlayerController? _prepared;

  @override
  void initState() {
    super.initState();
    _prepareIfCached();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _prepared?.dispose();
    super.dispose();
  }

  /// Loads the decoder up front when the clip is already on disk.
  ///
  /// Costs no network - `getFileFromCache` never fetches - so the rule that
  /// nothing downloads until the user asks still holds. It only moves the
  /// decoder's start-up off the tap, which on a cold start is most of the wait
  /// between pressing play and seeing a picture.
  Future<void> _prepareIfCached() async {
    final cached = await MediaCache.videos.getFileFromCache(widget.cacheKey);
    if (cached == null || !mounted || _controller != null || _loading) return;

    final controller = VideoPlayerController.file(cached.file);
    try {
      await controller.initialize();
      await controller.setLooping(true);
    } catch (_) {
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    // Ready, but deliberately not playing: the user still has to press play.
    setState(() => _prepared = controller);
  }

  Future<void> _start() async {
    if (_loading || _controller != null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });

    // Already decoded from the cache - just start it.
    final prepared = _prepared;
    if (prepared != null) {
      _prepared = null;
      await prepared.play();
      if (!mounted) {
        await prepared.dispose();
        return;
      }
      setState(() {
        _controller = prepared;
        _loading = false;
      });
      return;
    }

    VideoPlayerController? controller;
    try {
      final file = await _download();
      if (!mounted) return;

      controller = VideoPlayerController.file(file);
      await controller.initialize();
      // These are short silent demonstrations - looping is how you actually
      // study a movement, and it saves the user tapping replay every 20s.
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
        _downloadProgress = null;
      });
    } catch (_) {
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
        _downloadProgress = null;
      });
    }
  }

  /// Returns the clip from disk, fetching it first if it is not there yet.
  Future<File> _download() async {
    await for (final response in MediaCache.videos.getFileStream(
      widget.url,
      key: widget.cacheKey,
      withProgress: true,
    )) {
      if (response is DownloadProgress) {
        if (!mounted) break;
        setState(() => _downloadProgress = response.progress);
      } else if (response is FileInfo) {
        return response.file;
      }
    }
    throw StateError('video download produced no file');
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    // No setState: the ValueListenableBuilder below is what repaints.
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final started = controller != null && controller.value.isInitialized;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            // Before initialising there is no real aspect ratio to use, and 16:9
            // matches every clip in the catalog closely enough that the box does
            // not jump when playback starts.
            aspectRatio: started ? controller.value.aspectRatio : 16 / 9,
            child: started ? _buildPlayer(controller) : _buildPoster(),
          ),
        ),
        // The hint explains why nothing has downloaded yet, so it has no
        // business staying on screen once the video is running.
        if (!started) ...[
          const SizedBox(height: 6),
          Text(
            tr('videoTapToPlay'),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildPoster() {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Not ExerciseThumbnail: that one is a fixed square, and this poster
        // fills a 16:9 box. Same cache entry either way.
        if (widget.posterUrl != null)
          CachedNetworkImage(
            imageUrl: widget.posterUrl!,
            cacheKey: widget.posterCacheKey,
            cacheManager: MediaCache.instance,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: colors.surfaceVariant),
            errorWidget: (_, __, ___) =>
                Container(color: colors.surfaceVariant),
          )
        else
          Container(color: colors.surfaceVariant),
        // The icon is a 256 px file stretched across the full width, so it is
        // soft. Dimming it makes that read as a deliberate poster rather than
        // a blurry photo, and gives the button something to sit on.
        Container(color: Colors.black.withValues(alpha: 0.35)),
        Center(
          child: _loading
              ? SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                    // Determinate once the download reports bytes; a clip
                    // already on disk never gets here at all.
                    value: _downloadProgress,
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _start,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _failed ? Icons.refresh : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),
        ),
        if (_failed)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              tr('videoFailed'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayer(VideoPlayerController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(controller),
        // Tap anywhere to pause, the way every video on a phone behaves.
        // opaque, not the default deferToChild: this detector has no child, so
        // deferring means hit-testing finds nothing and the tap falls through.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
        ),
        // The controller is a ValueNotifier, and playback state also changes
        // without us - looping, buffering, the app going to the background.
        // Reading controller.value directly here would paint a play icon that
        // never goes away.
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.isPlaying
              ? const SizedBox.shrink()
              : const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 56),
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: context.colors.primary1,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
        ),
      ],
    );
  }
}
