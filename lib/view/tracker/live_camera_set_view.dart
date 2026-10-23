import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_strings.dart';
import '../../models/ai_set_result.dart';
import '../../models/workout_session_models.dart';
import '../../posecoach/exercise_processor.dart';
import '../../posecoach/exercise_processor_factory.dart';
import '../../posecoach/feedback_cue.dart';
import '../../posecoach/pose_overlay_painter.dart';
import '../../posecoach/skeleton_animator.dart';
import '../../posecoach/tts_coach.dart';

/// The two depth milestones, as colours. Orange is "counted, half marks",
/// green is "full depth" - the same planned/actual pairing the rest of the
/// tracker uses, so a user reading the depth bar already knows what green
/// means.
const _kMilestone1Color = Color(0xFFF2994A);
const _kMilestone2Color = Color(0xFF27AE60);

/// Android reports the sensor's orientation, not the phone's; this is the
/// difference between the two that ML Kit needs to read the frame upright.
const Map<DeviceOrientation, int> _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Counting and scoring a set from the camera.
///
/// The screen owns the camera, the detector and the processor, and hands back
/// an [AiSetResult] when the user finishes. It writes nothing itself: backing
/// out has to be free, and the caller already owns the "record this set" path
/// that the manual dialog uses.
///
/// The layout follows the reference clip the user brought: skeleton over a
/// full-screen preview, big figures across the top. Where that clip had two
/// duelling players, this shows the only two numbers that matter here - reps
/// counted and points scored - with the set's clock between them.
class LiveCameraSetView extends StatefulWidget {
  final SessionExercise exercise;

  const LiveCameraSetView({super.key, required this.exercise});

  @override
  State<LiveCameraSetView> createState() => _LiveCameraSetViewState();
}

class _LiveCameraSetViewState extends State<LiveCameraSetView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  late final ExerciseProcessor? _processor =
      processorFor(widget.exercise.aiAlgorithm);
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final TtsCoach _coach = TtsCoach();

  /// Where the skeleton is drawn - eased towards each detection at the
  /// screen's refresh rate rather than jumping to it. See [SkeletonAnimator].
  final SkeletonAnimator _skeleton = SkeletonAnimator();

  /// Drives [_skeleton] and the depth bar once per screen frame.
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  /// Whether the last detection found anybody. Only its *changes* rebuild the
  /// screen - it decides whether to show "get in frame".
  bool _hasPose = false;

  /// One frame at a time. ML Kit takes tens of milliseconds per frame and the
  /// camera delivers thirty a second; without this the queue grows until the
  /// skeleton is tracing where the user was two seconds ago.
  bool _detecting = false;

  int _reps = 0;
  int _score = 0;
  FeedbackCue? _cue;

  /// What the depth bar shows, eased towards [_targetDepth] every screen
  /// frame. A notifier rather than state, so the bar repaints on its own
  /// without rebuilding the HUD around it.
  final ValueNotifier<double> _shownDepth = ValueNotifier(0);
  double _targetDepth = 0;

  /// The latest reading, for the tuning readout - the one part of the HUD
  /// that genuinely changes on every detection.
  final ValueNotifier<ProcessorResult?> _live = ValueNotifier(null);
  Timer? _cueTimer;

  /// Live readout of what the algorithm is actually measuring.
  ///
  /// On while the thresholds are still being tuned: they were set by eye, and
  /// "the counting is erratic" cannot be fixed without knowing what a real rep
  /// reads at the top and at the bottom. Turned off once the numbers are
  /// settled - it is a tuning instrument, not a feature.
  static const bool _showTuningReadout = true;

  List<CameraDescription> _cameras = const [];
  CameraLensDirection _facing = CameraLensDirection.back;
  bool _switching = false;

  int _seconds = 0;
  Timer? _clock;

  String? _fatalError;
  bool _permissionDenied = false;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker.start();
    _start();
  }

  /// Once per screen frame: ease the skeleton and the depth bar towards the
  /// latest detection.
  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    _skeleton.advance(dt);

    final gap = _targetDepth - _shownDepth.value;
    if (gap.abs() > 0.002) {
      final seconds = math.min(dt.inMicroseconds / 1e6, 0.1);
      // ~60ms to close most of the gap: quick enough that the bar still
      // tracks the rep, slow enough that it stops stepping between
      // detections.
      _shownDepth.value += gap * (1 - math.exp(-seconds / 0.06));
    }
  }

  Future<void> _start() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _starting = false;
      });
      return;
    }

    await _coach.init();

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _fatalError = tr('error_camera_unavailable');
          _starting = false;
        });
        return;
      }

      await _open(_facing);
      if (!mounted) return;
      setState(() => _starting = false);

      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fatalError = tr('error_camera_unavailable');
        _starting = false;
      });
    }
  }

  /// Opens one lens, replacing whatever was running.
  ///
  /// The back camera is the default: the phone is propped on the floor facing
  /// the user and the back lens has the wider field of view, which is what
  /// gets a whole body into frame from a metre away. The front lens is there
  /// because propping the phone that way means you cannot see the screen -
  /// with the front camera the numbers face you while you work.
  Future<void> _open(CameraLensDirection facing) async {
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == facing,
      orElse: () => _cameras.first,
    );

    final previous = _controller;
    if (previous != null) {
      // Stop the stream before tearing the controller down: a frame arriving
      // afterwards reaches a detector that is no longer listening.
      try {
        await previous.stopImageStream();
      } catch (_) {}
      await previous.dispose();
      if (mounted) setState(() => _controller = null);
    }

    final controller = CameraController(
      camera,
      // Medium rather than high: ML Kit downsamples anyway, and every extra
      // pixel is copied per frame on the UI isolate.
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    await controller.startImageStream(_onFrame);
    setState(() {
      _controller = controller;
      _facing = camera.lensDirection;
    });
  }

  /// Flips between the front and back lens mid-set.
  ///
  /// Reps counted so far are kept: the user changed where the phone is
  /// looking from, not what they are doing. Throwing the count away would
  /// punish them for fixing the framing.
  Future<void> _flipCamera() async {
    if (_switching || _cameras.length < 2) return;
    setState(() => _switching = true);

    final wanted = _facing == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    try {
      await _open(wanted);
    } catch (_) {
      // Falling back to the lens that was working beats leaving a dead
      // preview on screen.
      try {
        await _open(_facing);
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
          _hasPose = false;
        });
        // The skeleton belongs to the old lens; it will be replaced by the
        // first frame from the new one.
        _skeleton.clear();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android revokes the camera when the app goes to the background, and
    // coming back to a dead controller shows a frozen frame. Leaving the
    // screen entirely is the honest response: the set was interrupted.
    if (state == AppLifecycleState.inactive && mounted) {
      _controller?.stopImageStream().catchError((_) {});
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final processor = _processor;
    if (_detecting || processor == null) return;
    _detecting = true;

    try {
      final input = _toInputImage(image);
      if (input == null) return;

      final poses = await _detector.processImage(input);
      if (!mounted) return;

      final upright =
          input.metadata!.rotation == InputImageRotation.rotation90deg ||
                  input.metadata!.rotation == InputImageRotation.rotation270deg
              ? Size(image.height.toDouble(), image.width.toDouble())
              : Size(image.width.toDouble(), image.height.toDouble());

      if (poses.isEmpty) {
        _skeleton.update(null, upright);
        if (_hasPose) setState(() => _hasPose = false);
        return;
      }

      // Counting reads the raw detection; only the drawing is eased.
      final result = processor.process(poses.first);
      _skeleton.update(poses.first, upright);
      _targetDepth = result.depth;
      _live.value = result;

      if (result.repJustScored != null) HapticFeedback.mediumImpact();
      if (result.cue != null) _showCue(result.cue!);

      // Rebuild only for what the HUD's widgets actually show. Doing it on
      // every detection rebuilt the preview and the whole HUD ten to twenty
      // times a second, which is where much of the stutter came from.
      if (result.repCount != _reps || result.score != _score || !_hasPose) {
        setState(() {
          _reps = result.repCount;
          _score = result.score;
          _hasPose = true;
        });
      }
    } catch (_) {
      // A frame that cannot be read is not worth reporting - the next one
      // arrives in 30ms.
    } finally {
      _detecting = false;
    }
  }

  /// Wraps a camera frame in what ML Kit expects, or null when the frame is in
  /// a layout it cannot read.
  ///
  /// The rotation is the fiddly part: ML Kit needs to know which way is up in
  /// the *sensor's* frame, which on Android is the sensor orientation adjusted
  /// by how the phone is being held - and adjusted the other way round for a
  /// front camera, because its image is mirrored.
  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final camera = controller.description;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else {
      final compensation =
          _orientationDegrees[controller.value.deviceOrientation];
      if (compensation == null) return null;
      final degrees = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + compensation) % 360
          : (camera.sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(degrees);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _showCue(FeedbackCue cue) {
    _coach.say(cue);
    setState(() => _cue = cue);
    _cueTimer?.cancel();
    _cueTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _cue = null);
    });
  }

  Future<void> _finish() async {
    final processor = _processor;
    if (processor == null || processor.repCount == 0) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(tr('msg_ai_no_reps')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('btn_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('btn_confirm')),
            ),
          ],
        ),
      );
      if (leave == true && mounted) Navigator.pop(context);
      return;
    }

    Navigator.pop(
      context,
      AiSetResult(
        reps: processor.repCount,
        repScores: List<int>.from(processor.repScores),
        algorithm: processor.algorithm,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _skeleton.dispose();
    _shownDepth.dispose();
    _live.dispose();
    _clock?.cancel();
    _cueTimer?.cancel();
    // Stop the stream before the detector goes: a frame arriving after the
    // detector is closed throws from native code with nothing to catch it.
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _detector.close();
    _coach.dispose();
    super.dispose();
  }

  static String _clockText(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(),
            if (_controller != null && _controller!.value.isInitialized) ...[
              _buildSkeleton(),
              _buildHud(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) return _buildPermissionWall();
    if (_fatalError != null) {
      return _buildMessage(_fatalError!, showSettings: false);
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Cover the screen rather than letter-box it: the overlay's projection
    // assumes the preview fills the widget, and a gap on either side would put
    // the skeleton next to the body instead of on it.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }

  /// Its own layer: the skeleton repaints every screen frame while the user
  /// moves, and nothing else on screen should be dragged along with it.
  Widget _buildSkeleton() => RepaintBoundary(
        child: CustomPaint(
          painter: PoseOverlayPainter(
            skeleton: _skeleton,
            mirror: _controller?.description.lensDirection ==
                CameraLensDirection.front,
          ),
        ),
      );

  Widget _buildPermissionWall() => _buildMessage(
        tr('msg_camera_permission'),
        title: tr('title_camera_permission'),
        showSettings: true,
      );

  Widget _buildMessage(String message,
      {String? title, required bool showSettings}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 42),
            const SizedBox(height: 14),
            if (title != null) ...[
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 18),
            if (showSettings)
              FilledButton(
                onPressed: openAppSettings,
                child: Text(tr('btn_open_settings')),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('btn_cancel'),
                  style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  /// Reps, clock and score across the top; depth underneath; the finish button
  /// at the bottom. Everything sits on a scrim rather than the raw preview -
  /// white figures over a bright room are unreadable otherwise.
  Widget _buildHud() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      widget.exercise.name ?? tr('title_ai_camera'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _cameras.length < 2 || _switching ? null : _flipCamera,
                    icon: Icon(
                      Icons.flip_camera_ios,
                      color:
                          _cameras.length < 2 ? Colors.white24 : Colors.white,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _figure(tr('label_ai_reps'), '$_reps',
                        color: _kMilestone2Color),
                  ),
                  Expanded(
                    child: _figure(tr('label_ai_time'), _clockText(_seconds),
                        color: Colors.white, small: true),
                  ),
                  Expanded(
                    child: _figure(tr('label_ai_score'), '$_score',
                        color: _kMilestone1Color),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDepthBar(),
              if (_showTuningReadout) _buildTuningReadout(),
            ],
          ),
        ),
        if (_cue != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _kMilestone1Color.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(_cue!.text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        const Spacer(),
        if (_reps == 0 && !_hasPose)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(tr(_processor?.setupHintKey ?? 'msg_ai_get_in_frame'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _finish,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(tr('btn_ai_finish_set')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _figure(String label, String value,
      {required Color color, bool small = false}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: small ? 26 : 34,
            fontWeight: FontWeight.w800,
            // Fixed-width digits, so the numbers do not jitter sideways as
            // they change mid-set.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// The numbers the algorithm is actually working from.
  ///
  /// Reads e.g. `R 138° · sâu 96° · tin 0.91 · mốc 155/120/95`. Everything
  /// needed to say why a rep did or did not count: which arm was measured, how
  /// straight it is right now, the deepest point of the rep in progress, how
  /// sure ML Kit is, and the thresholds those are being judged against.
  Widget _buildTuningReadout() {
    final processor = _processor;
    String number(double? v, {int digits = 0}) =>
        v == null ? '—' : v.toStringAsFixed(digits);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ValueListenableBuilder<ProcessorResult?>(
        valueListenable: _live,
        builder: (context, live, _) => Text(
          '${live?.side ?? "—"} ${number(live?.angle)}°'
          ' · sâu ${number(live?.deepest)}°'
          ' · tin ${number(live?.confidence, digits: 2)}'
          ' · mốc ${processor == null ? "—" : "${processor.restAngle.round()}"
              "/${processor.milestone1Angle.round()}"
              "/${processor.milestone2Angle.round()}"}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  /// How deep the user is right now, with the two scoring milestones marked.
  ///
  /// The marks are the point: without them the bar says "you are moving" and
  /// with them it says "one more inch and that rep is worth double".
  Widget _buildDepthBar() {
    final milestone1 = _processor?.milestone1Fraction ?? 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('label_ai_depth'),
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return ValueListenableBuilder<double>(
              valueListenable: _shownDepth,
              builder: (context, depth, _) => SizedBox(
                height: 12,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: depth.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          // Not >= 1.0: the eased value approaches the target
                          // without ever quite landing on it.
                          color: depth >= 0.99
                              ? _kMilestone2Color
                              : (depth >= milestone1
                                  ? _kMilestone1Color
                                  : Colors.white38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * milestone1 - 1,
                      child: Container(
                          width: 2, height: 12, color: _kMilestone1Color),
                    ),
                    Positioned(
                      right: 0,
                      child: Container(
                          width: 2, height: 12, color: _kMilestone2Color),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
