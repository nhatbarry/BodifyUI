// Debug-only entrypoint: mirrors the health history already stored on the
// server into Health Connect, so the phone and the backend tell one story.
//
//   flutter run -t lib/dev/seed_health_history.dart \
//     --dart-define=SEED_EMAIL=... --dart-define=SEED_PASSWORD=...
//
// For every day the server has, it writes records whose totals come out to
// the server's numbers: one steps block, one distance block, and just enough
// heart-rate readings to hit that day's min, max and average. Today instead
// gets 2-hour step blocks and a reading every 30 minutes, because the home
// screen draws today's heart-rate curve from the phone. It then reads every
// day back exactly as HealthSyncService does and pushes those roll-ups, so
// whatever rounding Health Connect applies, both sides end up identical.
//
// Write quota: Health Connect allows roughly a thousand calls before it
// starts refusing, which is why the past days get so few records each.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

const _email = String.fromEnvironment('SEED_EMAIL');
const _password = String.fromEnvironment('SEED_PASSWORD');
const _historyDays = 92;

void main() => runApp(const MaterialApp(home: _SeedScreen()));

class _SeedScreen extends StatefulWidget {
  const _SeedScreen();

  @override
  State<_SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<_SeedScreen> {
  final _health = Health();
  String _status = 'Starting...';
  bool _busy = false;
  int _written = 0;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  void _say(String s) {
    debugPrint('SEED: $s');
    if (mounted) setState(() => _status = s);
  }

  Future<void> _write(Future<bool> Function() call) async {
    for (var attempt = 0; attempt < 360; attempt++) {
      if (await call()) {
        _written++;
        return;
      }
      _say('Waiting on the write quota... ($_written written)');
      await Future.delayed(const Duration(seconds: 5));
    }
    throw StateError('Health Connect kept refusing writes');
  }

  Future<bool> _steps(DateTime from, DateTime to, int steps, double metres,
          String id) async =>
      await _health.writeHealthData(
        value: steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: from,
        endTime: to,
        clientRecordId: '$id-steps',
        clientRecordVersion: 1,
      ) &&
      await _health.writeHealthData(
        value: metres,
        type: HealthDataType.DISTANCE_DELTA,
        startTime: from,
        endTime: to,
        clientRecordId: '$id-dist',
        clientRecordVersion: 1,
      );

  Future<bool> _bpm(DateTime t, int bpm) => _health.writeHealthData(
        value: bpm.toDouble(),
        type: HealthDataType.HEART_RATE,
        startTime: t,
        clientRecordId: 'bodify-hist-${t.millisecondsSinceEpoch}-hr',
        clientRecordVersion: 1,
      );

  /// The fewest readings (at least 5) whose min, max and rounded mean are
  /// exactly the server's: one at each extreme, the rest sharing what is left.
  List<int> _readings(int lo, int hi, int avg) {
    for (var n = 5; n < 60; n++) {
      final rest = n * avg - lo - hi;
      final each = rest / (n - 2);
      if (each < lo || each > hi) continue;
      final base = rest ~/ (n - 2);
      final extra = rest - base * (n - 2);
      return [
        lo,
        for (var i = 0; i < n - 2; i++) base + (i < extra ? 1 : 0),
        hi,
      ];
    }
    return [lo, avg, hi];
  }

  Future<void> _seed() async {
    setState(() => _busy = true);
    try {
      if (_email.isEmpty) throw StateError('SEED_EMAIL not given');
      await _health.configure();
      final ok = await _health.requestAuthorization(
        _types,
        permissions: List.filled(_types.length, HealthDataAccess.READ_WRITE),
      );
      if (!ok) return _say('Write access was not granted');

      _say('Signing in...');
      final login = await http.post(ApiConfig.path('/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': _email, 'password': _password}));
      if (login.statusCode != 200) {
        return _say('Login failed: ${login.statusCode} ${login.body}');
      }
      final token = jsonDecode(login.body)['access_token'] as String;
      final auth = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final first = today.subtract(const Duration(days: _historyDays - 1));
      String ymd(DateTime d) => d.toIso8601String().substring(0, 10);

      final res = await http.get(
          ApiConfig.path('/health-data/daily?from=${ymd(first)}&to=${ymd(today)}'),
          headers: auth);
      final server = {
        for (final d in jsonDecode(res.body) as List) d['day'] as String: d
      };
      _say('Server has ${server.length} days. Clearing old records...');

      for (final type in _types) {
        await _health.delete(
            type: type,
            startTime: first.subtract(const Duration(days: 1)),
            endTime: now);
      }

      for (var d = today;
          !d.isBefore(first);
          d = d.subtract(const Duration(days: 1))) {
        final row = server[ymd(d)];
        if (row == null) continue;
        final steps = row['steps'] as int?;
        final metres = double.tryParse('${row['distance_m']}');
        final rnd = math.Random(d.millisecondsSinceEpoch ~/ 86400000);

        if (d == today) {
          // 2-hour blocks up to now, and a full curve for the home chart.
          final blocks = <DateTime>[];
          for (var h = 7; h < 21; h += 2) {
            final end = d.add(Duration(hours: h, minutes: 119));
            if (end.isAfter(now)) break;
            blocks.add(d.add(Duration(hours: h)));
          }
          if (steps != null && blocks.isNotEmpty) {
            var left = steps;
            for (var i = 0; i < blocks.length; i++) {
              final part = i == blocks.length - 1
                  ? left
                  : (steps / blocks.length * (0.7 + 0.6 * rnd.nextDouble()))
                      .round()
                      .clamp(0, left);
              left -= part;
              final m = (metres ?? steps * 0.74) * part / steps;
              await _write(() => _steps(blocks[i],
                  blocks[i].add(const Duration(minutes: 119)), part, m,
                  'bodify-hist-${blocks[i].millisecondsSinceEpoch}'));
            }
          }
          for (var m = 0; m < 24 * 60; m += 30) {
            final t = d.add(Duration(minutes: m));
            if (t.isAfter(now)) break;
            final hour = m / 60;
            final bpm = hour < 6
                ? 55 + rnd.nextInt(7)
                : hour >= 22
                    ? 62 + rnd.nextInt(7)
                    : 70 + rnd.nextInt(18);
            await _write(() => _bpm(t, bpm));
          }
        } else {
          if (steps != null) {
            final from = d.add(const Duration(hours: 7));
            await _write(() => _steps(from, d.add(const Duration(hours: 21)),
                steps, metres ?? steps * 0.74,
                'bodify-hist-${from.millisecondsSinceEpoch}'));
          }
          final lo = row['heart_rate_min'] as int?;
          final hi = row['heart_rate_max'] as int?;
          final avg = row['heart_rate_avg'] as int?;
          if (lo != null && hi != null && avg != null) {
            final values = _readings(lo, hi, avg);
            // The low at 04:00, the peak at 18:30, the rest spread 06-22h.
            final times = <DateTime>[
              d.add(const Duration(hours: 4)),
              for (var i = 0; i < values.length - 2; i++)
                d.add(Duration(
                    minutes: 360 + (960 * i / (values.length - 2)).round())),
              d.add(const Duration(hours: 18, minutes: 31)),
            ];
            for (var i = 0; i < values.length; i++) {
              await _write(() => _bpm(times[i], values[i]));
            }
          }
        }
        _say('${ymd(d)} written ($_written records)');
      }

      _say('Reading back and pushing to the server...');
      final days = <Map<String, dynamic>>[];
      for (var d = first; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
        final day = await _readDay(d);
        if (day != null) days.add(day);
      }
      for (var i = 0; i < days.length; i += 31) {
        final r = await http.put(ApiConfig.path('/health-data/daily'),
            headers: auth,
            body: jsonEncode({
              'source': 'health_connect',
              'days': days.sublist(i, math.min(i + 31, days.length)),
            }));
        if (r.statusCode >= 300) throw StateError('push ${r.statusCode} ${r.body}');
      }
      _say('DONE: $_written records written, ${days.length} days pushed');
    } catch (e) {
      _say('FAILED: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Same reading as HealthSyncService._readDay.
  Future<Map<String, dynamic>?> _readDay(DateTime day) async {
    final end = day.add(const Duration(days: 1));
    final now = DateTime.now();
    final to = end.isAfter(now) ? now : end;
    final steps = await _health.getTotalStepsInInterval(day, to);
    double? distance;
    for (final p in await _health.getHealthDataFromTypes(
        types: const [HealthDataType.DISTANCE_DELTA],
        startTime: day,
        endTime: to)) {
      final v = p.value;
      if (v is NumericHealthValue) {
        distance = (distance ?? 0) + v.numericValue.toDouble();
      }
    }
    final bpm = <int>[];
    for (final p in await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: day,
        endTime: to)) {
      final v = p.value;
      if (v is NumericHealthValue) bpm.add(v.numericValue.round());
    }
    final hasSteps = steps != null && steps != 0;
    if (!hasSteps && distance == null && bpm.isEmpty) return null;
    return {
      'day': day.toIso8601String().substring(0, 10),
      if (hasSteps) 'steps': steps,
      if (distance != null)
        'distance_m': double.parse(distance.toStringAsFixed(1)),
      if (bpm.isNotEmpty) ...{
        'heart_rate_avg': (bpm.reduce((a, b) => a + b) / bpm.length).round(),
        'heart_rate_min': bpm.reduce(math.min),
        'heart_rate_max': bpm.reduce(math.max),
      },
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mirror health history')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_status, key: const Key('status')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _seed,
                child: const Text('Run again'),
              ),
            ]),
          ),
        ),
      );
}
