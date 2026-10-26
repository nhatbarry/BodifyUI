import 'dart:async';
import 'dart:math' as math;

import 'package:bodify/common_widget/round_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
  bool _metricLoading = false;
  bool _metricError = false;

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
    if (!mounted || _metricLoading) return;
    setState(() {
      _metricLoading = true;
      _metricError = false;
    });
    try {
      final metric = await BodyMetricService.instance.latest();
      if (mounted) setState(() => _latestMetric = metric);
    } catch (_) {
      if (mounted) setState(() => _metricError = true);
    } finally {
      if (mounted) setState(() => _metricLoading = false);
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
  bool _healthLoading = false;
  bool _healthError = false;

  /// Reads today from Health Connect for the card, then pushes the unsent
  /// days to the backend. The card does not wait on the upload.
  Future<void> _loadHealth() async {
    if (!mounted || _healthLoading) return;
    setState(() {
      _healthLoading = true;
      _healthError = false;
    });
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
      // A read failure is not a permission denial. Keep any previous readings
      // and offer a retry instead of sending the user through permissions.
      if (mounted) setState(() => _healthError = true);
    } finally {
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  /// Home tab re-selected: steps have moved on since the screen was built.
  void refreshHealth() => _loadHealth();

  Future<void> _connectHealth() async {
    if (!mounted || _healthBusy) return;
    setState(() => _healthBusy = true);
    try {
      if (_health?.access == HealthAccess.notInstalled) {
        await HealthSyncService.instance.install();
      } else if (!await HealthSyncService.instance.connect() && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('msg_health_denied'))));
      }
      await _loadHealth();
    } catch (_) {
      if (mounted) {
        setState(() => _healthError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('msg_health_load_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _healthBusy = false);
    }
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

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadProfile(),
      _loadLatestMetric(),
      _loadHealth(),
      _activityKey.currentState?.reload() ?? Future<void>.value(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final today = _health?.today;
    final spots = _heartRateSpots();

    return Scaffold(
      backgroundColor: colors.surface,
      // Keep scrolled content out of the status bar and display cutout.
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshHome,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('label_welcome_back'),
                                      style: type.bodyMedium?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _profile?.name ?? tr('label_bodify_user'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: type.titleLarge?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: tr('title_notification_section'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationView(),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.notifications_none_rounded,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _bmiCard(),
                          const SizedBox(height: 28),
                          Text(
                            tr('title_activity_status'),
                            style: type.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _heartRateCard(today, spots),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final distance = _metricCard(
                                tr('label_distance'),
                                today?.distanceM == null
                                    ? null
                                    : '${(today!.distanceM! / 1000).toStringAsFixed(2)} km',
                              );
                              final steps = _metricCard(
                                tr('label_steps'),
                                today?.steps?.toString(),
                              );
                              final largeText =
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      21;
                              if (constraints.maxWidth < 300 || largeText) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    distance,
                                    const SizedBox(height: 12),
                                    steps,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: distance),
                                  const SizedBox(width: 16),
                                  Expanded(child: steps),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          ActivityProgressCard(key: _activityKey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: MediaQuery.paddingOf(context).top,
            width: double.infinity,
            color: colors.surface,
          ),
        ],
      ),
    );
  }

  Widget _bmiCard() {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final bmi = _latestMetric?.bmi;
    final foreground = colors.onPrimary;
    final caption = _metricError
        ? tr('msg_bmi_load_failed')
        : _metricLoading && bmi == null
            ? tr('msg_loading')
            : bmi == null
                ? tr('msg_no_bmi_yet')
                : bmiCategoryLabel(bmi);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              bmi == null ? colors.primaryGradient : bmiCategoryGradient(bmi),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('title_bmi'),
            style: type.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // BMI is a measurement, not a completion percentage. A fixed pie
          // slice implied a target that the user had never configured.
          LayoutBuilder(
            builder: (context, constraints) {
              final value = Text(
                bmi?.toStringAsFixed(1) ?? '–',
                style: type.displaySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              );
              final description = Text(
                caption,
                style: type.bodyMedium?.copyWith(color: foreground),
              );
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [value, const SizedBox(height: 8), description],
                );
              }
              return Row(
                children: [
                  value,
                  const SizedBox(width: 20),
                  Expanded(child: description),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openBmi,
                style: OutlinedButton.styleFrom(
                  foregroundColor: foreground,
                  side: BorderSide(color: foreground),
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle:
                      type.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                label: Text(tr('btn_view_more')),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                iconAlignment: IconAlignment.end,
              ),
              if (_metricError)
                TextButton(
                  onPressed: _loadLatestMetric,
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(tr('btn_retry')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heartRateCard(HealthDay? today, List<FlSpot> spots) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('label_heart_rate'),
            style: type.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // Keep the latest real watch reading; absence is never zero BPM.
            spots.isEmpty
                ? '–'
                : '${_health!.heartRate.last.bpm} ${tr('unit_bpm')}',
            style: type.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _heartRateCaption(today),
          if (spots.isNotEmpty) ...[
            const SizedBox(height: 20),
            _heartRateChart(spots),
          ],
        ],
      ),
    );
  }

  Widget _heartRateChart(List<FlSpot> spots) {
    final colors = context.colors;
    final bar = LineChartBarData(
      showingIndicators: showingTooltipOnSpots,
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      barWidth: 3,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            colors.primary2.withValues(alpha: 0.3),
            colors.primary1.withValues(alpha: 0.03),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(colors: colors.primaryGradient),
    );

    // The chart lives below the caption so it never intercepts the Health
    // Connect button or paints a tooltip over a permission explanation.
    return Semantics(
      label: '${tr('label_heart_rate')}. '
          '${tr('label_hr_range').replaceAll('{min}', '${_health?.today?.heartRateMin ?? '–'}').replaceAll('{max}', '${_health?.today?.heartRateMax ?? '–'}')}',
      child: SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            showingTooltipIndicators: [
              for (final index in showingTooltipOnSpots)
                if (index < spots.length)
                  ShowingTooltipIndicators([LineBarSpot(bar, 0, spots[index])]),
            ],
            lineTouchData: LineTouchData(
              handleBuiltInTouches: false,
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent ||
                    response?.lineBarSpots?.isEmpty != false) {
                  return;
                }
                setState(() {
                  showingTooltipOnSpots = [
                    response!.lineBarSpots!.first.spotIndex
                  ];
                });
              },
              getTouchedSpotIndicator: (barData, indexes) => [
                for (final _ in indexes)
                  TouchedSpotIndicatorData(
                    FlLine(color: colors.textSecondary),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: colors.surface,
                        strokeWidth: 3,
                        strokeColor: colors.primary1,
                      ),
                    ),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colors.primary2,
                tooltipBorderRadius: BorderRadius.circular(12),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touched) => [
                  for (final spot in touched)
                    LineTooltipItem(
                      '${_clock(spot.x)} · ${spot.y.round()} ${tr('unit_bpm')}',
                      TextStyle(
                        color: colors.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [bar],
            minY: spots.map((e) => e.y).reduce(math.min) - 15,
            maxY: spots.map((e) => e.y).reduce(math.max) + 25,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _heartRateCaption(HealthDay? today) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        );
    final access = _health?.access;
    if (_healthBusy || _healthLoading) {
      return Semantics(
        liveRegion: true,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('msg_loading'), style: style)),
          ],
        ),
      );
    }
    if (_healthError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('msg_health_load_failed'), style: style),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadHealth,
            style: TextButton.styleFrom(
              foregroundColor: colors.textPrimary,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(tr('btn_retry')),
          ),
        ],
      );
    }
    if (access == HealthAccess.unavailable) {
      return Text(tr('msg_health_unavailable'), style: style);
    }
    if (access == HealthAccess.notInstalled ||
        access == HealthAccess.notGranted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('msg_health_permission'), style: style),
          const SizedBox(height: 12),
          RoundButton(
            title: tr(access == HealthAccess.notInstalled
                ? 'btn_install_health'
                : 'btn_connect_health'),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            onPressed: _connectHealth,
          ),
        ],
      );
    }
    if (today?.heartRateMin == null) {
      return Text(tr('msg_no_heart_rate'), style: style);
    }
    return Text(
      tr('label_hr_range')
          .replaceAll('{min}', '${today!.heartRateMin}')
          .replaceAll('{max}', '${today.heartRateMax}'),
      style: style,
    );
  }

  Widget _metricCard(String title, String? value) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final connected = _health?.access == HealthAccess.granted;
    final status = _healthLoading
        ? tr('msg_loading')
        : _healthError
            ? tr('msg_health_load_failed')
            : tr(connected ? 'label_today' : 'msg_not_connected');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: type.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value ?? '–',
            style: type.headlineSmall?.copyWith(
              color: value == null ? colors.textSecondary : colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: type.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
