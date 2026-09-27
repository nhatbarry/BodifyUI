/// One heart-rate reading as Health Connect stored it.
class HeartRateSample {
  final DateTime time;
  final int bpm;

  const HeartRateSample(this.time, this.bpm);
}

/// One day of phone health data - what `PUT /health-data/daily` takes and
/// `GET` returns. Every measure is nullable: a phone without a watch has
/// steps and distance and no heart rate, and 0 bpm is not "no reading".
class HealthDay {
  final DateTime day;
  final int? steps;
  final double? distanceM;
  final int? heartRateAvg;
  final int? heartRateMin;
  final int? heartRateMax;

  const HealthDay({
    required this.day,
    this.steps,
    this.distanceM,
    this.heartRateAvg,
    this.heartRateMin,
    this.heartRateMax,
  });

  bool get isEmpty =>
      steps == null && distanceM == null && heartRateAvg == null;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'day': _date(day),
        if (steps != null) 'steps': steps,
        // The column keeps one decimal; more would be refused as a 422.
        if (distanceM != null)
          'distance_m': double.parse(distanceM!.toStringAsFixed(1)),
        if (heartRateAvg != null) 'heart_rate_avg': heartRateAvg,
        if (heartRateMin != null) 'heart_rate_min': heartRateMin,
        if (heartRateMax != null) 'heart_rate_max': heartRateMax,
      };

  static double? _toDouble(dynamic v) => v == null
      ? null
      // Numeric columns arrive as JSON strings ("1234.5").
      : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  factory HealthDay.fromJson(Map<String, dynamic> json) => HealthDay(
        day: DateTime.parse(json['day'] as String),
        steps: json['steps'] as int?,
        distanceM: _toDouble(json['distance_m']),
        heartRateAvg: json['heart_rate_avg'] as int?,
        heartRateMin: json['heart_rate_min'] as int?,
        heartRateMax: json['heart_rate_max'] as int?,
      );
}

/// Where the app stands with Health Connect, in the order a user meets the
/// obstacles: the app must exist, then allow access.
enum HealthAccess { unavailable, notInstalled, notGranted, granted }

/// Everything the home screen draws: today's totals and today's heart-rate
/// curve, both read straight from the phone.
class HealthToday {
  final HealthAccess access;
  final HealthDay? today;
  final List<HeartRateSample> heartRate;

  const HealthToday(this.access, {this.today, this.heartRate = const []});
}
