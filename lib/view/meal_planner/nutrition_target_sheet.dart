import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';

/// Sets the daily target.
///
/// Only energy is required. Somebody counting calories and nothing else is the
/// common case, and demanding three macros they have not thought about is how
/// a setup screen gets abandoned - so the macro fields are optional and left
/// blank rather than prefilled with a guess.
///
/// Saving replaces the whole target rather than patching it, matching the
/// backend's PUT: a macro cleared here is cleared there.
class NutritionTargetSheet extends StatefulWidget {
  final NutritionTarget? current;

  const NutritionTargetSheet({super.key, this.current});

  @override
  State<NutritionTargetSheet> createState() => _NutritionTargetSheetState();
}

class _NutritionTargetSheetState extends State<NutritionTargetSheet> {
  late final _energy = TextEditingController(text: _initial(widget.current?.energyKcal));
  late final _protein = TextEditingController(text: _initial(widget.current?.proteinG));
  late final _fat = TextEditingController(text: _initial(widget.current?.fatG));
  late final _carb = TextEditingController(text: _initial(widget.current?.carbG));

  bool _saving = false;
  String? _error;

  static String _initial(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.round().toString() : '$value';
  }

  @override
  void dispose() {
    _energy.dispose();
    _protein.dispose();
    _fat.dispose();
    _carb.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MealService.instance.deleteTarget();
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of('toast_target_cleared'))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _save() async {
    final energy = _parse(_energy);
    if (energy == null || energy <= 0) {
      setState(() => _error = AppStrings.of('label_target'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MealService.instance.setTarget(
        energyKcal: energy,
        proteinG: _parse(_protein),
        fatG: _parse(_fat),
        carbG: _parse(_carb),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of('toast_target_saved'))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.of('title_nutrition_target'),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _field(_energy, AppStrings.of('unit_kcal'), required: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_protein, AppStrings.of('label_protein'))),
                const SizedBox(width: 10),
                Expanded(child: _field(_fat, AppStrings.of('label_fat'))),
                const SizedBox(width: 10),
                Expanded(child: _field(_carb, AppStrings.of('label_carb'))),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE05B5B), fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.of('btn_set_target')),
              ),
            ),
            if (widget.current != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving ? null : _clear,
                  child: Text(
                    AppStrings.of('btn_clear_target'),
                    style: const TextStyle(color: Color(0xFFE05B5B)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool required = false}) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      // The energy field is the only required one and the reason the sheet
      // opened, so the keyboard lands on it rather than making the user aim.
      autofocus: required,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: colors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
