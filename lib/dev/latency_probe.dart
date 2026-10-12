// Debug-only entrypoint: times real CRUD round trips from the device, over
// the same kind of keep-alive http.Client the app's services use.
//
//   flutter run -t lib/dev/latency_probe.dart
//   flutter run -t lib/dev/latency_probe.dart --dart-define=API_BASE_URL=http://10.0.2.2:8000
//
// Signs in as pytest-latency-probe@example.com (registering it the first
// time) - the `pytest-` prefix is what the backend test suite purges, so the
// account does not linger. Every row a round creates is deleted in the same
// round. Results go to the screen and to logcat as `LATENCY ...` lines.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

const _email = 'pytest-latency-probe@example.com';
const _password = 'LatencyProbe123';
const _rounds = 5;

void main() => runApp(const MaterialApp(home: _ProbeScreen()));

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen();

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _Stat {
  final String name;
  final List<int> ms = [];
  _Stat(this.name);

  int _q(double p) {
    final s = [...ms]..sort();
    return s[((s.length - 1) * p).round()];
  }

  int get median => _q(0.5);
  int get p90 => _q(0.9);
  int get min => ms.reduce((a, b) => a < b ? a : b);
  int get max => ms.reduce((a, b) => a > b ? a : b);
}

class _ProbeScreenState extends State<_ProbeScreen> {
  final _client = http.Client();
  final _stats = <String, _Stat>{};
  final _order = <String>[];
  String _status = 'Tap to run $_rounds rounds against\n${ApiConfig.baseUrl}';
  bool _busy = false;
  String? _token;

  Uri _u(String path, [Map<String, String>? q]) =>
      ApiConfig.path(path).replace(queryParameters: q);

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Times one request and fails loudly on an unexpected status: a latency
  /// figure for a request that errored measures the wrong thing.
  Future<dynamic> _t(String name, Future<http.Response> Function() call,
      {int expect = 200}) async {
    final sw = Stopwatch()..start();
    final r = await call();
    sw.stop();
    if (r.statusCode != expect) {
      throw StateError('$name -> ${r.statusCode}: ${r.body}');
    }
    _stats.putIfAbsent(name, () {
      _order.add(name);
      return _Stat(name);
    }).ms.add(sw.elapsedMilliseconds);
    debugPrint('LATENCY $name ${sw.elapsedMilliseconds}');
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  Future<void> _signIn() async {
    final sw = Stopwatch()..start();
    var r = await _client.post(_u('/auth/login'),
        headers: _h, body: jsonEncode({'email': _email, 'password': _password}));
    if (r.statusCode != 200) {
      r = await _client.post(_u('/auth/register'),
          headers: _h,
          body: jsonEncode(
              {'email': _email, 'password': _password, 'name': 'Latency Probe'}));
      if (r.statusCode != 201) throw StateError('register -> ${r.body}');
      _token = (jsonDecode(r.body)['session'] as Map)['access_token'] as String;
    } else {
      _token = jsonDecode(r.body)['access_token'] as String;
    }
    debugPrint('LATENCY sign-in(first, cold) ${sw.elapsedMilliseconds}');
  }

  Future<void> _round(int foodId, String today) async {
    // Baselines: the same server with and without the database.
    await _t('GET / (no DB)',
        () => _client.get(Uri.parse('${ApiConfig.baseUrl}/')));
    await _t('GET /health (SELECT 1)', () => _client.get(_u('/health')));

    // Body metrics: full CRUD.
    final m = await _t('POST /body-metrics', () => _client.post(_u('/body-metrics'),
        headers: _h, body: jsonEncode({'height_cm': 170, 'weight_kg': 65})),
        expect: 201);
    await _t('GET /body-metrics', () => _client.get(_u('/body-metrics'), headers: _h));
    await _t('GET /body-metrics/latest',
        () => _client.get(_u('/body-metrics/latest'), headers: _h));
    await _t('DELETE /body-metrics/{id}',
        () => _client.delete(_u('/body-metrics/${m['metric_id']}'), headers: _h),
        expect: 204);

    // Workout plan: create, list, read, update, delete.
    final p = await _t('POST /workout-plans', () => _client.post(_u('/workout-plans'),
        headers: _h, body: jsonEncode({'name': 'Latency probe plan'})),
        expect: 201);
    final pid = p['plan_id'];
    await _t('GET /workout-plans', () => _client.get(_u('/workout-plans'), headers: _h));
    await _t('GET /workout-plans/{id}',
        () => _client.get(_u('/workout-plans/$pid', {'language': 'vi'}), headers: _h));
    await _t('PUT /workout-plans/{id}', () => _client.put(_u('/workout-plans/$pid'),
        headers: _h, body: jsonEncode({'name': 'Latency probe plan (renamed)'})));
    await _t('DELETE /workout-plans/{id}',
        () => _client.delete(_u('/workout-plans/$pid'), headers: _h),
        expect: 204);

    // Meal diary: the busiest screen's write path.
    final meal = await _t('POST /meals', () => _client.post(_u('/meals'),
        headers: _h, body: jsonEncode({'logged_date': today})),
        expect: 201);
    final item = await _t('POST /meal-items', () => _client.post(_u('/meal-items'),
        headers: _h,
        body: jsonEncode({
          'meal_id': meal['meal_id'],
          'food_id': foodId,
          'quantity': 1,
          'unit': 'serving',
          'status': 'planned',
        })),
        expect: 201);
    final iid = item['meal_item_id'];
    await _t('PUT /meal-items/{id}', () => _client.put(_u('/meal-items/$iid'),
        headers: _h, body: jsonEncode({'quantity': 2, 'unit': 'serving'})));
    await _t('PUT /meal-items/{id}/status', () => _client.put(
        _u('/meal-items/$iid/status'),
        headers: _h, body: jsonEncode({'status': 'eaten'})));
    await _t('GET /meals?date=',
        () => _client.get(_u('/meals', {'date': today}), headers: _h));
    await _t('DELETE /meal-items/{id}',
        () => _client.delete(_u('/meal-items/$iid'), headers: _h),
        expect: 204);
    await _t('DELETE /meals/{id}',
        () => _client.delete(_u('/meals/${meal['meal_id']}'), headers: _h),
        expect: 204);

    // Catalog reads the explorer and the food picker make.
    await _t('GET /exercises?limit=20', () => _client.get(
        _u('/exercises', {'limit': '20', 'language': 'vi'}), headers: _h));
    await _t('GET /foods?search=pho', () => _client.get(
        _u('/foods', {'search': 'pho', 'limit': '25', 'language': 'vi'}),
        headers: _h));
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _stats.clear();
      _order.clear();
    });
    try {
      setState(() => _status = 'Signing in...');
      await _signIn();
      final foods = await _client.get(
          _u('/foods', {'basis': 'per_serving', 'limit': '1'}), headers: _h);
      final foodId = ((jsonDecode(foods.body)['items'] as List).first
          as Map)['food_id'] as int;
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      for (var i = 1; i <= _rounds; i++) {
        setState(() => _status = 'Round $i/$_rounds...');
        await _round(foodId, today);
      }
      for (final n in _order) {
        final s = _stats[n]!;
        debugPrint('LATENCY_SUMMARY $n | median ${s.median} | p90 ${s.p90} '
            '| min ${s.min} | max ${s.max} | n ${s.ms.length}');
      }
      setState(() => _status = 'Done - ${ApiConfig.baseUrl}');
    } catch (e) {
      debugPrint('LATENCY_FAILED $e');
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('API latency (ms)')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_status, textAlign: TextAlign.center),
            ),
            ElevatedButton(
              onPressed: _busy ? null : _run,
              child: const Text('Run'),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final n in _order)
                    ListTile(
                      dense: true,
                      title: Text(n),
                      trailing: Text(
                          'med ${_stats[n]!.median}  p90 ${_stats[n]!.p90}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
