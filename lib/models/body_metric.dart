/// Mirrors the backend's BodyMetricRead.
///
/// `bmi` is computed server-side and only present when both height and weight
/// were recorded, so it stays consistent with its inputs.
class BodyMetric {
  final int metricId;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final DateTime recordedAt;

  const BodyMetric({
    required this.metricId,
    required this.recordedAt,
    this.heightCm,
    this.weightKg,
    this.bmi,
  });

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    // Numeric columns arrive as JSON strings ("175.00"), not numbers.
    return value is num ? value.toDouble() : double.tryParse(value.toString());
  }

  factory BodyMetric.fromJson(Map<String, dynamic> json) => BodyMetric(
        metricId: json['metric_id'] as int,
        heightCm: _toDouble(json['height_cm']),
        weightKg: _toDouble(json['weight_kg']),
        bmi: _toDouble(json['bmi']),
        recordedAt: DateTime.parse(json['recorded_at'].toString()).toLocal(),
      );
}

/// WHO categories, used for the label under the BMI figure.
enum BmiCategory { underweight, normal, overweight, obese }

BmiCategory bmiCategoryOf(double bmi) {
  if (bmi < 18.5) return BmiCategory.underweight;
  if (bmi < 25) return BmiCategory.normal;
  if (bmi < 30) return BmiCategory.overweight;
  return BmiCategory.obese;
}
