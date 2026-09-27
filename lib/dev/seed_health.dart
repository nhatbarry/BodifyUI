// Debug-only entrypoint: fills Health Connect on an emulator with two weeks of
// plausible steps, distance and heart rate, so Phase 8 can be tried and
// demonstrated without a watch.
//
//   flutter run -t lib/dev/seed_health.dart
//
// The WRITE permissions it needs are declared only in
// android/app/src/debug/AndroidManifest.xml; a release build can read Health
// Connect and nothing else. Every record carries a clientRecordId derived from
// its time, so running this twice overwrites instead of doubling the steps.
//
// Health Connect rate-limits writes (roughly a thousand calls, refilling
// slowly), and there is no batch call in the plugin: the first version wrote
// every 15 minutes and was cut off on day 9 with "API call quota exceeded".
// Hence 2-hour step blocks, a reading every 30 minutes, today first, and a
// wait-and-retry when a write is refused.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

const _days = 14;

void main() => runApp(const MaterialApp(home: _SeedScreen()));

class _SeedScreen extends StatefulWidget {
  const _SeedScreen();

  @override
  State<_SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<_SeedScreen> {
  final _health = Health();
  String _status = 'Tap to write $_days days of sample data';
  bool _busy = false;

  /// Retries a refused write until the quota refills. False from the plugin
  /// is how "API call quota exceeded" arrives; it logs the reason instead of
  /// throwing.
  Future<void> _write(Future<bool> Function() call) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      if (await call()) return;
      if (mounted) setState(() => _status = 'Waiting on the write quota...');
      await Future.delayed(const Duration(seconds: 5));
    }
    throw StateError('Health Connect kept refusing writes');
  }

  Future<void> _seed() async {
    setState(() => _busy = true);
    try {
      await _health.configure();
      const types = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.HEART_RATE,
      ];
      final ok = await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ_WRITE),
      );
      if (!ok) {
        setState(() => _status = 'Write access was not granted');
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Clear what this app wrote earlier: records from an older layout of
      // this script carry other ids and would be added on top, not replaced.
      // Health Connect only lets an app delete its own records, so a real
      // source's data in the same window is untouched.
      final from = today.subtract(const Duration(days: _days));
      for (final type in types) {
        await _health.delete(type: type, startTime: from, endTime: now);
      }
      var written = 0;
      for (var d = 0; d < _days; d++) {
        final day = today.subtract(Duration(days: d));
        // Same numbers on every run for a given date.
        final rnd = math.Random(day.millisecondsSinceEpoch ~/ 86400000);

        // Walking hours 07:00-21:00 in 2-hour blocks, heavier around commutes.
        for (var h = 7; h < 21; h += 2) {
          final start = day.add(Duration(hours: h));
          final end = start.add(const Duration(minutes: 119));
          if (end.isAfter(now)) break;
          final busy = (h == 7 || h == 11 || h == 17);
          final steps = (busy ? 1800 : 600) + rnd.nextInt(busy ? 1500 : 800);
          final id = 'bodify-seed-${start.millisecondsSinceEpoch}';
          await _write(() => _health.writeHealthData(
            value: steps.toDouble(),
            type: HealthDataType.STEPS,
            startTime: start,
            endTime: end,
            clientRecordId: '$id-steps',
            clientRecordVersion: 1,
          ));
          await _write(() => _health.writeHealthData(
            value: steps * 0.74, // metres, an average stride
            type: HealthDataType.DISTANCE_DELTA,
            startTime: start,
            endTime: end,
            clientRecordId: '$id-dist',
            clientRecordVersion: 1,
          ));
          written += 2;
        }

        // A reading every 30 minutes: low overnight, higher by day, and a
        // workout at 18:00 that peaks around 150 bpm.
        for (var m = 0; m < 24 * 60; m += 30) {
          final t = day.add(Duration(minutes: m));
          if (t.isAfter(now)) break;
          final hour = m / 60;
          double bpm;
          if (hour < 6) {
            bpm = 56 + rnd.nextInt(8).toDouble();
          } else if (hour >= 18 && hour < 19) {
            bpm = 120 + 30 * math.sin((hour - 18) * math.pi) + rnd.nextInt(8);
          } else if (hour >= 22) {
            bpm = 62 + rnd.nextInt(8).toDouble();
          } else {
            bpm = 72 + rnd.nextInt(20).toDouble();
          }
          await _write(() => _health.writeHealthData(
            value: bpm.roundToDouble(),
            type: HealthDataType.HEART_RATE,
            startTime: t,
            clientRecordId: 'bodify-seed-${t.millisecondsSinceEpoch}-hr',
            clientRecordVersion: 1,
          ));
          written++;
        }
        setState(() => _status = 'Day ${d + 1}/$_days - $written records');
      }
      setState(() => _status = 'Done: $written records written');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Seed Health Connect')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_status, key: const Key('status')),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _seed,
                child: const Text('Write sample data'),
              ),
            ],
          ),
        ),
      );
}
