import 'dart:async';
import 'dart:math' as math;

import 'package:dotted_dashed_line/dotted_dashed_line.dart';
import 'package:bodify/common_widget/round_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../common_widget/latest_workout_section.dart';
import 'package:simple_animation_progress_bar/simple_animation_progress_bar.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';
import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/body_metric.dart';
import '../../models/health_models.dart';
import '../../models/profile.dart';
import '../../services/body_metric_service.dart';
import '../../services/health_sync_service.dart';
import '../../services/profile_service.dart';
import '../body_metrics/bmi_view.dart';
import 'activity_tracker_view.dart';
import 'notification_view.dart';
import '../../common_widget/activity_progress_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  HomeViewState createState() => HomeViewState();
}

/// Public so [MainTabView] can hold a key and call [refreshActivity] when the
/// Home tab is tapped, rather than tearing the whole screen down and rebuilding
/// it - which was the old, accidental way this screen ever picked up a workout
/// just finished elsewhere in the app.
class HomeViewState extends State<HomeView> {
  final _activityKey = GlobalKey<ActivityProgressCardState>();

  BodyMetric? _latestMetric;
  Profile? _profile;

  void refreshActivity() => _activityKey.currentState?.reload();

  /// The greeting reads `_profile?.name`, loaded once in [initState]. Editing
  /// the name happens on a screen reached through the Profile tab, which has
  /// no path back through here to say so - see RefreshFlags.homeProfile.
  void refreshProfile() => _loadProfile();

  @override
  void initState() {
    super.initState();
    _loadLatestMetric();
    _loadProfile();
    _loadHealth();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.get();
      if (mounted) setState(() => _profile = profile);
    } on ApiException {
      // The greeting falls back to a neutral one; the rest of the screen is
      // unaffected by not knowing the name.
    }
  }

  Future<void> _loadLatestMetric() async {
    try {
      final metric = await BodyMetricService.instance.latest();
      if (mounted) setState(() => _latestMetric = metric);
    } on ApiException {
      // The rest of the home screen still works without a BMI reading.
    }
  }

  Future<void> _openBmi() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BmiView()),
    );
    // Recording or deleting a measurement changes what the card should show.
    _loadLatestMetric();
  }

  /// Index of the heart-rate point whose tooltip is showing, if any.
  List<int> showingTooltipOnSpots = [];

  HealthToday? _health;
  bool _healthBusy = false;

  /// Reads today from Health Connect for the card, then pushes the unsent
  /// days to the backend. The card does not wait on the upload.
  Future<void> _loadHealth() async {
    try {
      final today = await HealthSyncService.instance.today();
      if (!mounted) return;
      setState(() {
        _health = today;
        showingTooltipOnSpots.clear();
      });
      if (today.access == HealthAccess.granted) {
        unawaited(HealthSyncService.instance.sync().catchError((_) {
          // The phone still holds the data; the next open retries.
        }));
      }
    } catch (_) {
      // Health Connect threw (e.g. its app is being updated). The card keeps
      // showing "not connected" rather than taking the screen down.
      if (mounted) {
        setState(() => _health = const HealthToday(HealthAccess.notGranted));
      }
    }
  }

  /// Home tab re-selected: steps have moved on since the screen was built.
  void refreshHealth() => _loadHealth();

  Future<void> _connectHealth() async {
    if (_healthBusy) return;
    setState(() => _healthBusy = true);
    try {
      if (_health?.access == HealthAccess.notInstalled) {
        await HealthSyncService.instance.install();
      } else if (!await HealthSyncService.instance.connect() && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('msg_health_denied'))));
      }
    } finally {
      if (mounted) setState(() => _healthBusy = false);
    }
    await _loadHealth();
  }

  /// Heart rate as chart points: x in minutes since midnight. A watch logging
  /// every second during a workout hands over thousands of samples, so they
  /// are averaged into 5-minute buckets - at most 288 points for a whole day,
  /// which is more than a card this wide can show anyway.
  List<FlSpot> _heartRateSpots() {
    final samples = _health?.heartRate ?? const <HeartRateSample>[];
    final buckets = <int, List<int>>{};
    for (final s in samples) {
      final minute = s.time.hour * 60 + s.time.minute;
      buckets.putIfAbsent(minute ~/ 5, () => []).add(s.bpm);
    }
    final keys = buckets.keys.toList()..sort();
    return [
      for (final k in keys)
        FlSpot(
          k * 5.0,
          buckets[k]!.reduce((a, b) => a + b) / buckets[k]!.length,
        ),
    ];
  }

  static String _clock(double minutes) {
    final m = minutes.round();
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  List waterArr = [
    {"title": "6am - 8am", "subtitle": "600ml"},
    {"title": "9am - 11am", "subtitle": "500ml"},
    {"title": "11am - 2pm", "subtitle": "1000ml"},
    {"title": "2pm - 4pm", "subtitle": "700ml"},
    {"title": "4pm - now", "subtitle": "900ml"},
  ];

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    final spots = _heartRateSpots();
    final today = _health?.today;
    final lineBarsData = [
      LineChartBarData(
        showingIndicators: showingTooltipOnSpots,
        // fl_chart cannot draw an empty series; one invisible point keeps the
        // card's shape while there is nothing to plot.
        spots: spots.isEmpty ? const [FlSpot(0, 0)] : spots,
        show: spots.isNotEmpty,
        isCurved: true,
        preventCurveOverShooting: true,
        barWidth: 3,
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(colors: [
            context.colors.primary2.withOpacity(0.4),
            context.colors.primary1.withOpacity(0.1),
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        dotData: FlDotData(show: false),
        gradient: LinearGradient(
          colors: context.colors.primaryGradient,
        ),
      ),
    ];

    final tooltipsOnBar = lineBarsData[0];

    return Scaffold(
      backgroundColor: context.colors.surface,
      // SafeArea only pads the *first* layout - it reserves space above the
      // greeting once, but that reserved space is part of the scrollable
      // content, so the instant the user scrolls it moves away with
      // everything else and the next line of text slides in behind the
      // status bar / camera cutout, which Flutter has no reason to clip
      // since that area is legitimately part of the screen. Pinning an
      // opaque strip the height of the top inset above the scroll view masks
      // whatever scrolls underneath it instead.
      body: Stack(
        children: [
          SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('label_welcome_back'),
                          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          // The kit shipped a hardcoded name here. Until the
                          // profile arrives, a neutral word beats someone
                          // else's name.
                          _profile?.name ?? tr('label_bodify_user'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationView(),
                            ),
                          );
                        },
                        icon: Image.asset(
                          "assets/img/notification_active.png",
                          width: 25,
                          height: 25,
                          fit: BoxFit.fitHeight,
                        ))
                  ],
                ),
                SizedBox(height: media.width * 0.05),
                Container(
                  height: media.width * 0.4,
                  decoration: BoxDecoration(
                      // Colour follows the BMI category so the warning is
                      // visible without opening the detail screen.
                      gradient: LinearGradient(
                          colors: _latestMetric?.bmi == null
                              ? context.colors.primaryGradient
                              : bmiCategoryGradient(_latestMetric!.bmi!)),
                      borderRadius: BorderRadius.circular(media.width * 0.075)),
                  child: Stack(alignment: Alignment.center, children: [
                    Image.asset(
                      "assets/img/bg_dots.png",
                      height: media.width * 0.4,
                      width: double.maxFinite,
                      fit: BoxFit.fitHeight,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 25, horizontal: 25),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('title_bmi'),
                                style: TextStyle(
                                    color: context.colors.surface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                _latestMetric?.bmi == null
                                    ? tr('msg_no_bmi_yet')
                                    : bmiCategoryLabel(_latestMetric!.bmi!),
                                style: TextStyle(
                                    color: context.colors.surface.withOpacity(0.7),
                                    fontSize: 12),
                              ),
                              SizedBox(
                                height: media.width * 0.05,
                              ),
                              SizedBox(
                                  width: 120,
                                  height: 35,
                                  child: RoundButton(
                                      title: tr('btn_view_more'),
                                      type: RoundButtonType.bgSGradient,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      onPressed: _openBmi))
                            ],
                          ),
                          AspectRatio(
                            aspectRatio: 1,
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {},
                                ),
                                startDegreeOffset: 250,
                                borderData: FlBorderData(
                                  show: false,
                                ),
                                sectionsSpace: 1,
                                centerSpaceRadius: 0,
                                sections: showingSections(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ]),
                ),
                SizedBox(height: media.width * 0.05),
                Text(
                  tr('title_activity_status'),
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  height: media.width * 0.02,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    // Taller than the kit's 0.4: the card now carries a
                    // caption and, until connected, a button.
                    height: media.width * 0.48,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: context.colors.primary2.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('label_heart_rate'),
                                style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                          colors: context.colors.primaryGradient,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight)
                                      .createShader(Rect.fromLTRB(
                                          0, 0, bounds.width, bounds.height));
                                },
                                child: Text(
                                  // The latest reading, not the day's average:
                                  // the figure a watch face shows.
                                  spots.isEmpty
                                      ? '--'
                                      : '${_health!.heartRate.last.bpm} ${tr('unit_bpm')}',
                                  style: TextStyle(
                                      color: context.colors.surface.withOpacity(0.7),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _heartRateCaption(today),
                            ],
                          ),
                        ),
                        // The chart is laid over the caption and fills the
                        // card, so while it has nothing to draw it must not
                        // take touches: it swallowed every tap on the
                        // "Connect Health Connect" button beneath it, which
                        // is only ever shown when there are no points.
                        IgnorePointer(
                          ignoring: spots.isEmpty,
                          child: LineChart(
                          LineChartData(
                            showingTooltipIndicators:
                                showingTooltipOnSpots.map((index) {
                              return ShowingTooltipIndicators([
                                LineBarSpot(
                                  tooltipsOnBar,
                                  lineBarsData.indexOf(tooltipsOnBar),
                                  tooltipsOnBar.spots[index],
                                ),
                              ]);
                            }).toList(),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              handleBuiltInTouches: false,
                              touchCallback: (FlTouchEvent event,
                                  LineTouchResponse? response) {
                                if (spots.isEmpty ||
                                    response == null ||
                                    response.lineBarSpots == null) {
                                  return;
                                }
                                if (event is FlTapUpEvent) {
                                  final spotIndex =
                                      response.lineBarSpots!.first.spotIndex;
                                  showingTooltipOnSpots.clear();
                                  setState(() {
                                    showingTooltipOnSpots.add(spotIndex);
                                  });
                                }
                              },
                              mouseCursorResolver: (FlTouchEvent event,
                                  LineTouchResponse? response) {
                                if (response == null ||
                                    response.lineBarSpots == null) {
                                  return SystemMouseCursors.basic;
                                }
                                return SystemMouseCursors.click;
                              },
                              getTouchedSpotIndicator:
                                  (LineChartBarData barData,
                                      List<int> spotIndexes) {
                                return spotIndexes.map((index) {
                                  return TouchedSpotIndicatorData(
                                    FlLine(
                                      color: Colors.red,
                                    ),
                                    FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) =>
                                              FlDotCirclePainter(
                                        radius: 3,
                                        color: Colors.white,
                                        strokeWidth: 3,
                                        strokeColor: context.colors.secondary1,
                                      ),
                                    ),
                                  );
                                }).toList();
                              },
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => context.colors.secondary1,
                                tooltipBorderRadius: BorderRadius.circular(20),
                                getTooltipItems:
                                    (List<LineBarSpot> lineBarsSpot) {
                                  return lineBarsSpot.map((lineBarSpot) {
                                    return LineTooltipItem(
                                      '${_clock(lineBarSpot.x)} · '
                                      '${lineBarSpot.y.round()} ${tr('unit_bpm')}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: lineBarsData,
                            // The day's own range with headroom, so a resting
                            // 60-70 bpm is not a flat line pinned to the
                            // bottom of a 0-200 axis.
                            minY: spots.isEmpty
                                ? 0
                                : spots.map((e) => e.y).reduce(math.min) - 15,
                            maxY: spots.isEmpty
                                ? 130
                                : spots.map((e) => e.y).reduce(math.max) + 25,
                            titlesData: FlTitlesData(
                              show: false,
                            ),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: media.width * 0.05),
                Row(
                  children: [
                    // Distance replaced calories: a phone without a watch can
                    // measure how far somebody walked but only guess what it
                    // cost them. A dash still means "no reading".
                    Expanded(
                      child: _metricCard(
                        media,
                        tr('label_distance'),
                        today?.distanceM == null
                            ? null
                            : '${(today!.distanceM! / 1000).toStringAsFixed(2)} km',
                      ),
                    ),
                    SizedBox(width: media.width * 0.05),
                    Expanded(
                      child: _metricCard(
                        media,
                        tr('label_steps'),
                        today?.steps?.toString(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: media.width * 0.05),
                ActivityProgressCard(key: _activityKey),
                    SizedBox(height: media.width * 0.1),
                  ],
                ),
              ),
            ),
          ),
          // Masks whatever has scrolled up behind the status bar / notch -
          // see the note on `body` above.
          Container(
            height: MediaQuery.of(context).padding.top,
            width: double.infinity,
            color: context.colors.surface,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> showingSections() {
    return List.generate(
      2,
      (i) {
        // Matches the card behind it rather than the fixed kit accent.
        var color0 = _latestMetric?.bmi == null
            ? context.colors.secondary1
            : bmiCategoryColor(_latestMetric!.bmi!);

        switch (i) {
          case 0:
            return PieChartSectionData(
                color: color0,
                value: 33,
                title: '',
                radius: 55,
                titlePositionPercentageOffset: 0.55,
                badgeWidget: Text(
                  _latestMetric?.bmi?.toStringAsFixed(1) ?? "–",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ));
          case 1:
            return PieChartSectionData(
              color: Colors.white,
              value: 75,
              title: '',
              radius: 45,
              titlePositionPercentageOffset: 0.55,
            );

          default:
            throw Error();
        }
      },
    );
  }

  /// The line under the heart-rate figure: the day's range once there is
  /// one, otherwise what stands between the user and a reading.
  Widget _heartRateCaption(HealthDay? today) {
    final colors = context.colors;
    final access = _health?.access;
    if (_health == null) return const SizedBox.shrink();
    if (access == HealthAccess.unavailable) {
      return Text(tr('msg_health_unavailable'),
          style: TextStyle(color: colors.textSecondary, fontSize: 11));
    }
    if (access == HealthAccess.notInstalled ||
        access == HealthAccess.notGranted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('msg_health_permission'),
              style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: RoundButton(
              title: tr(access == HealthAccess.notInstalled
                  ? 'btn_install_health'
                  : 'btn_connect_health'),
              type: RoundButtonType.bgGradient,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              onPressed: _connectHealth,
            ),
          ),
        ],
      );
    }
    if (today?.heartRateMin == null) {
      return Text(tr('msg_no_heart_rate'),
          style: TextStyle(color: colors.textSecondary, fontSize: 11));
    }
    return Text(
      tr('label_hr_range')
          .replaceAll('{min}', '${today!.heartRateMin}')
          .replaceAll('{max}', '${today.heartRateMax}'),
      style: TextStyle(color: colors.textSecondary, fontSize: 11),
    );
  }

  /// One of the two square tiles under the heart-rate chart. [value] null
  /// draws a dash: a plausible number would be read as a measurement.
  Widget _metricCard(Size media, String title, String? value) {
    final colors = context.colors;
    final connected = _health?.access == HealthAccess.granted;
    return Container(
      width: double.maxFinite,
      height: media.width * 0.26,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value ?? '--',
              style: TextStyle(
                  color: value == null ? colors.textSecondary : colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(tr(connected ? 'label_today' : 'msg_not_connected'),
              style: TextStyle(color: colors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
