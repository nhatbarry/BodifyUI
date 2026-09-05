import 'package:bodify/common/app_colors.dart';
import 'package:bodify/core/api_exception.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/services/body_metric_service.dart';
import 'package:bodify/services/profile_service.dart';
import 'package:bodify/view/login/what_your_goal_view.dart';
import 'package:flutter/material.dart';

import '../../common_widget/round_button.dart';
import '../../common_widget/round_textfield.dart';

/// The step straight after registering: gender, date of birth and a first
/// body measurement.
///
/// This screen used to be kit scaffolding - one `txtDate` controller wired to
/// all three fields, so typing a weight also filled the height and the date -
/// and "Next" only pushed the next route. Nothing entered here was ever saved,
/// which is why a freshly registered account had no date of birth, no gender
/// and no measurement.
class CompleteProfileView extends StatefulWidget {
  const CompleteProfileView({super.key});

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView> {
  // One controller per field. They are separate objects for the same reason
  // they are separate fields.
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  /// Stored lowercase because that is what `user_profiles.gender` holds and
  /// what `PUT /profile` expects; the label is translated at render time.
  String? _gender;
  DateTime? _dateOfBirth;
  bool _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  /// Height and weight are optional here, but a half-filled pair is not: BMI
  /// needs both, and recording one alone would leave a measurement that can
  /// never be plotted.
  String? _validateMeasurements() {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final hasHeightText = _heightController.text.trim().isNotEmpty;
    final hasWeightText = _weightController.text.trim().isNotEmpty;

    if (!hasHeightText && !hasWeightText) return null;
    if (hasHeightText != hasWeightText) return tr('error_need_both_measurements');
    if (height == null || weight == null) return tr('error_measurement_numeric');
    // The same range the API enforces, checked here so a typo is caught
    // without a round trip and names the field it is about.
    if (height < 30 || height > 280) return tr('error_height_range');
    if (weight < 2 || weight > 650) return tr('error_weight_range');
    return null;
  }

  Future<void> _next() async {
    final problem = _validateMeasurements();
    if (problem != null) {
      _showMessage(problem);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_gender != null || _dateOfBirth != null) {
        await ProfileService.instance.update(
          gender: _gender,
          dateOfBirth: _dateOfBirth,
        );
      }
      final height = double.tryParse(_heightController.text.trim());
      final weight = double.tryParse(_weightController.text.trim());
      if (height != null && weight != null) {
        await BodyMetricService.instance
            .record(heightCm: height, weightKg: weight);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(tr('error_save_failed'));
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WhatYourGoalView()),
    );
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return tr('label_gender_male');
      case 'female':
        return tr('label_gender_female');
      default:
        return tr('label_gender_other');
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Image.asset(
                  "assets/img/complete_profile.png",
                  width: media.width,
                  fit: BoxFit.fitWidth,
                ),
                SizedBox(height: media.width * 0.05),
                Text(
                  tr('title_complete_profile'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  tr('subtitle_complete_profile'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                SizedBox(height: media.width * 0.05),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      _genderField(colors),
                      SizedBox(height: media.width * 0.04),
                      _dateOfBirthField(colors),
                      SizedBox(height: media.width * 0.04),
                      _measurementField(
                        controller: _weightController,
                        hint: tr('label_your_weight'),
                        icon: "assets/img/weight.png",
                        unit: tr('unit_kg'),
                        colors: colors,
                      ),
                      SizedBox(height: media.width * 0.04),
                      _measurementField(
                        controller: _heightController,
                        hint: tr('label_your_height'),
                        icon: "assets/img/hight.png",
                        unit: tr('unit_cm'),
                        colors: colors,
                      ),
                      SizedBox(height: media.width * 0.07),
                      _isSaving
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: CircularProgressIndicator(),
                            )
                          : RoundButton(
                              title: tr('btn_next'),
                              onPressed: _next,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderField(BodifyColors colors) {
    return Container(
      decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            width: 50,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Image.asset(
              "assets/img/gender.png",
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              color: colors.textSecondary,
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _gender,
                items: const ['male', 'female', 'other']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            _genderLabel(value),
                            style: TextStyle(
                                color: colors.textPrimary, fontSize: 14),
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _gender = value),
                isExpanded: true,
                dropdownColor: colors.surfaceVariant,
                hint: Text(
                  tr('label_choose_gender'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _dateOfBirthField(BodifyColors colors) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Container(
              alignment: Alignment.center,
              width: 50,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Image.asset(
                "assets/img/date.png",
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                color: colors.textSecondary,
              ),
            ),
            Expanded(
              child: Text(
                _dateOfBirth == null
                    ? tr('label_date_of_birth')
                    : _formatDate(_dateOfBirth!),
                style: TextStyle(
                  color: _dateOfBirth == null
                      ? colors.textSecondary
                      : colors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            if (_dateOfBirth != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
                onPressed: () => setState(() => _dateOfBirth = null),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _measurementField({
    required TextEditingController controller,
    required String hint,
    required String icon,
    required String unit,
    required BodifyColors colors,
  }) {
    return Row(
      children: [
        Expanded(
          child: RoundTextField(
            controller: controller,
            hitText: hint,
            icon: icon,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors.secondaryGradient),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            unit,
            style: TextStyle(color: colors.surface, fontSize: 12),
          ),
        )
      ],
    );
  }
}
