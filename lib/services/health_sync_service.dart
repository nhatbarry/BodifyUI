import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/health_models.dart';
import 'auth_service.dart';

/// Reads steps, distance and heart rate from Android Health Connect and
/// pushes one roll-up per day to the backend.
///
/// The backend cannot reach the phone's health store, which is why this runs
/// here. What goes up is a day total, never the samples: the intraday
/// heart-rate curve on the home screen is drawn from the phone directly.
class HealthSyncService {
  HealthSyncService._();

  static final HealthSyncService instance = HealthSyncService._();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
  ];

  /// How far back the first sync reads. After that only yesterday and today
  /// are re-read - yesterday because a watch often hands its last hours over
  /// the next morning.
  static const _firstSyncDays = 14;
  static const _lastSyncKey = 'health_last_sync_day';

  final Health _health = Health();
  final http.Client _client = http.Client();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Where the user stands, without prompting for anything.
  Future<HealthAccess> access() async {
    if (!Platform.isAndroid) return HealthAccess.unavailable;
    await _configure();
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkUnavailable) {
      return HealthAccess.unavailable;
    }
    if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      return HealthAccess.notInstalled;
    }
    final granted = await _health.hasPermissions(_types) ?? false;
    return granted ? HealthAccess.granted : HealthAccess.notGranted;
  }

  /// Sends the user to the Play Store page for Health Connect (Android 13
  /// and below, where it is a separate app).
  Future<void> install() => _health.installHealthConnect();

  /// Shows Health Connect's own permission screen. True when every type was
  /// granted.
  Future<bool> connect() async {
    await _configure();
    return _health.requestAuthorization(_types);
  }

  /// Today's totals and heart-rate curve, read on the phone.
  Future<HealthToday> today() async {
    final state = await access();
    if (state != HealthAccess.granted) return HealthToday(state);

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final samples = await _heartRate(midnight, now);
    final day = await _readDay(midnight, samples: samples);
    return HealthToday(state, today: day, heartRate: samples);
  }

  /// Reads the days not yet sent and pushes them. Quietly does nothing
  /// without access - the home screen says so on its own.
  Future<void> sync() async {
    if (await access() != HealthAccess.granted) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime.tryParse(prefs.getString(_lastSyncKey) ?? '');
    var from = last == null
        ? today.subtract(const Duration(days: _firstSyncDays - 1))
        : last.subtract(const Duration(days: 1));
    if (from.isAfter(today)) from = today;

    final days = <HealthDay>[];
    for (var d = from; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      final day = await _readDay(d);
      if (!day.isEmpty) days.add(day);
    }
    if (days.isNotEmpty) await _push(days);
    await prefs.setString(_lastSyncKey, today.toIso8601String());
  }

  Future<List<HeartRateSample>> _heartRate(DateTime from, DateTime to) async {
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.HEART_RATE],
      startTime: from,
      endTime: to,
    );
    final samples = <HeartRateSample>[];
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) {
        samples.add(HeartRateSample(p.dateFrom, v.numericValue.round()));
      }
    }
    samples.sort((a, b) => a.time.compareTo(b.time));
    return samples;
  }

  Future<HealthDay> _readDay(DateTime day,
      {List<HeartRateSample>? samples}) async {
    final end = day.add(const Duration(days: 1));
    final now = DateTime.now();
    final to = end.isAfter(now) ? now : end;

    // Health Connect's own aggregate: it de-duplicates a phone and a watch
    // counting the same walk, which summing raw records would not.
    final steps = await _health.getTotalStepsInInterval(day, to);

    final distances = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.DISTANCE_DELTA],
      startTime: day,
      endTime: to,
    );
    double? distance;
    for (final p in distances) {
      final v = p.value;
      if (v is NumericHealthValue) {
        distance = (distance ?? 0) + v.numericValue.toDouble();
      }
    }

    final hr = samples ?? await _heartRate(day, to);
    int? avg, lo, hi;
    if (hr.isNotEmpty) {
      final bpm = hr.map((s) => s.bpm).toList();
      lo = bpm.reduce(math.min);
      hi = bpm.reduce(math.max);
      avg = (bpm.reduce((a, b) => a + b) / bpm.length).round();
    }

    return HealthDay(
      day: day,
      // Health Connect answers 0, not null, for a day nothing recorded -
      // measured: days with no records at all synced as "0 steps". A phone
      // that was carried never logs exactly zero, so 0 is read as "no data"
      // and the day shows a dash instead of claiming the user sat still.
      steps: (steps == null || steps == 0) ? null : steps,
      distanceM: distance,
      heartRateAvg: avg,
      heartRateMin: lo,
      heartRateMax: hi,
    );
  }

  Future<void> _push(List<HealthDay> days) async {
    final token = await AuthService.instance.validAccessToken();
    if (token == null) return;
    Future<http.Response> send(String t) => _client
        .put(
          ApiConfig.path('/health-data/daily'),
          headers: {
            'Authorization': 'Bearer $t',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'source': 'health_connect',
            'days': days.map((d) => d.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    var response = await send(token);
    if (response.statusCode == 401) {
      final session = await AuthService.instance.refreshSession();
      if (session == null) return;
      response = await send(session.accessToken);
    }
    if (response.statusCode >= 300) {
      throw ApiException(
        parseErrorMessage(
          response.body.isEmpty ? null : jsonDecode(response.body),
          fallback: 'Health sync failed (${response.statusCode})',
        ),
        statusCode: response.statusCode,
      );
    }
  }
}
