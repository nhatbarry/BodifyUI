import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/body_metric.dart';
import '../../services/body_metric_service.dart';

String bmiCategoryLabel(double bmi) {
  switch (bmiCategoryOf(bmi)) {
    case BmiCategory.underweight:
      return tr('bmiUnderweight');
    case BmiCategory.normal:
      return tr('bmiNormal');
    case BmiCategory.overweight:
      return tr('bmiOverweight');
    case BmiCategory.obese:
      return tr('bmiObese');
  }
}

/// Traffic-light colouring: the further from a healthy range, the more alarming.
/// Amber rather than pure yellow so the figure stays readable on white.
Color bmiCategoryColor(double bmi) {
  switch (bmiCategoryOf(bmi)) {
    case BmiCategory.underweight:
      return const Color(0xFFE0A800); // vàng
    case BmiCategory.normal:
      return const Color(0xFF27AE60); // xanh
    case BmiCategory.overweight:
      return const Color(0xFFE67E22); // cam
    case BmiCategory.obese:
      return const Color(0xFFE74C3C); // đỏ
  }
}

/// Two shades of the category colour, for cards that use a gradient.
List<Color> bmiCategoryGradient(double bmi) {
  switch (bmiCategoryOf(bmi)) {
    case BmiCategory.underweight:
      return const [Color(0xFFF6C445), Color(0xFFE0A800)];
    case BmiCategory.normal:
      return const [Color(0xFF56C596), Color(0xFF27AE60)];
    case BmiCategory.overweight:
      return const [Color(0xFFF5A15C), Color(0xFFE67E22)];
    case BmiCategory.obese:
      return const [Color(0xFFF07167), Color(0xFFE74C3C)];
  }
}

class BmiView extends StatefulWidget {
  const BmiView({super.key});

  @override
  State<BmiView> createState() => _BmiViewState();
}

class _BmiViewState extends State<BmiView> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  List<BodyMetric> _history = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  BodyMetric? get _latest => _history.isEmpty ? null : _history.first;

  /// Height rarely changes, so prefill it from the last record that had one -
  /// the user usually only wants to type today's weight.
  double? get _lastKnownHeight {
    for (final metric in _history) {
      if (metric.heightCm != null) return metric.heightCm;
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history = await BodyMetricService.instance.history();
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
        final height = _lastKnownHeight;
        if (height != null && _heightController.text.isEmpty) {
          _heightController.text = _trim(height);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    if (heightText.isEmpty && weightText.isEmpty) {
      _showMessage(tr('needHeightOrWeight'));
      return;
    }

    final height = heightText.isEmpty ? null : double.tryParse(heightText);
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);

    if ((heightText.isNotEmpty && (height == null || height <= 0)) ||
        (weightText.isNotEmpty && (weight == null || weight <= 0))) {
      _showMessage(tr('invalidNumber'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await BodyMetricService.instance.record(heightCm: height, weightKg: weight);
      _weightController.clear();
      _showMessage(tr('saved'));
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(BodyMetric metric) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete')),
        content: Text(tr('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel'), style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete'),
                style: const TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BodyMetricService.instance.delete(metric.metricId);
      _showMessage(tr('deleted'));
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  static String _date(DateTime value) =>
      "${value.day.toString().padLeft(2, '0')}/"
      "${value.month.toString().padLeft(2, '0')}/${value.year}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        title: Text(
          tr('bmiTitle'),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary1))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  if (_error != null) _buildError(),
                  _buildCurrentCard(),
                  const SizedBox(height: 20),
                  _buildForm(),
                  const SizedBox(height: 24),
                  Text(
                    tr('bmiHistory'),
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    _buildEmptyHistory()
                  else
                    for (final metric in _history) _buildHistoryRow(metric),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
          ),
          TextButton(
            onPressed: _load,
            child: Text(tr('retry'),
                style: TextStyle(color: context.colors.primary1, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCard() {
    final latest = _latest;
    final bmi = latest?.bmi;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // The card itself carries the warning: green when healthy, amber when
        // underweight, red when obese. Falls back to the app gradient when
        // there is no reading to judge.
        gradient: LinearGradient(
          colors: bmi == null ? context.colors.primaryGradient : bmiCategoryGradient(bmi),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('bmiTitle'),
            style: TextStyle(
                color: context.colors.surface, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (bmi == null) ...[
            Text(
              latest == null ? tr('noBmiYet') : tr('bmiNeedBoth'),
              style: TextStyle(color: context.colors.surface, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              tr('noBmiHint'),
              style: TextStyle(
                  color: context.colors.surface.withOpacity(0.75), fontSize: 12),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bmi.toStringAsFixed(1),
                  style: TextStyle(
                      color: context.colors.surface,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    bmiCategoryLabel(bmi),
                    style: TextStyle(
                        color: context.colors.surface.withOpacity(0.9), fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "${_trim(latest!.heightCm!)} cm · ${_trim(latest.weightKg!)} kg · ${_date(latest.recordedAt)}",
              style: TextStyle(
                  color: context.colors.surface.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('recordMeasurement'),
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField(_heightController, tr('heightCm'))),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_weightController, tr('weightKg'))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: _isSaving
                ? Center(
                    child: CircularProgressIndicator(color: context.colors.primary1))
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: context.colors.primaryGradient),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextButton(
                      onPressed: _save,
                      child: Text(
                        tr('save'),
                        style: TextStyle(
                            color: context.colors.surface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.monitor_weight_outlined, color: context.colors.textSecondary, size: 30),
          const SizedBox(height: 8),
          Text(tr('noBmiYet'),
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(BodyMetric metric) {
    final bmi = metric.bmi;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            alignment: Alignment.center,
            child: Text(
              bmi == null ? "–" : bmi.toStringAsFixed(1),
              style: TextStyle(
                color: bmi == null ? context.colors.textSecondary : bmiCategoryColor(bmi),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (metric.heightCm != null) "${_trim(metric.heightCm!)} cm",
                    if (metric.weightKg != null) "${_trim(metric.weightKg!)} kg",
                  ].join(" · "),
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _date(metric.recordedAt),
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _delete(metric),
            icon: Icon(Icons.delete_outline, color: context.colors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}
