import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/app_colors.dart';
import '../core/app_strings.dart';
import '../models/progress_models.dart';

/// The numbers one set is made of, whichever axes the exercise uses.
///
/// All four are nullable and travel together. A Plank fills `durationSeconds`
/// and leaves `reps` null; a Farmer's Carry fills `distanceM` *and*
/// `weightKg`. Callers pass the whole thing to the API, which stores exactly
/// what it is given.
class SetValues {
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceM;

  const SetValues({
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceM,
  });

  bool get isEmpty =>
      reps == null &&
      weightKg == null &&
      durationSeconds == null &&
      distanceM == null;
}

/// Which inputs an exercise needs.
///
/// Weight is on every one of them, deliberately. A Weighted Pull Up Hang is
/// seconds *and* 20 kg; a Farmer's Carry is metres *and* 40 kg. Hiding the
/// weight field for anything that is not `reps` would make those unloggable,
/// which is why `tracking_type` describes the effort axis only and never
/// claims the exercise is unloaded.
class SetFieldSpec {
  final bool reps;
  final bool weight;
  final bool duration;
  final bool distance;

  const SetFieldSpec({
    required this.reps,
    required this.weight,
    required this.duration,
    required this.distance,
  });

  factory SetFieldSpec.of(TrackingType type) => switch (type) {
        TrackingType.duration => const SetFieldSpec(
            reps: false, weight: true, duration: true, distance: false),
        TrackingType.distance => const SetFieldSpec(
            reps: false, weight: true, duration: false, distance: true),
        TrackingType.repsDuration => const SetFieldSpec(
            reps: true, weight: true, duration: true, distance: false),
        TrackingType.reps => const SetFieldSpec(
            reps: true, weight: true, duration: false, distance: false),
      };
}

/// Plates come in pairs of 1.25 kg, so the bar moves in 2.5 kg steps. Matching
/// the increment to the equipment means the common case is one tap, not typing.
const double kWeightStep = 2.5;

/// The slider's default ceiling. Raised automatically when the current value
/// is already above it, so a 180 kg deadlift is not clamped to 200 - the
/// track just rescales around what the user actually lifts.
const double kWeightSliderMax = 200;

/// Reps move one at a time. Seconds move in fives: holds are planned at 30,
/// 45, 60, 90, and stepping one second at a time to reach 90 is not an input
/// method.
const int kRepsStep = 1;
const int kDurationStep = 5;

/// The number fields for one set, chosen by how the exercise is measured.
///
/// Every value stays typeable - the stepper and the slider are shortcuts, not
/// replacements. Somebody moving from 45 s to 120 s should not tap 15 times,
/// and somebody at 42.5 kg needs a keyboard the slider cannot give them.
///
/// Owns nothing: the dialog that hosts it owns the controllers and reads them
/// back, because a dialog needs the values at the moment Save is tapped and a
/// callback-per-keystroke would be a worse way to get them.
class SetInputFields extends StatefulWidget {
  final TrackingType trackingType;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController duration;
  final TextEditingController distance;

  /// Labels differ between logging what was done and planning what to do -
  /// "Rep" against "Rep mục tiêu" - so the caller supplies the wording.
  final String Function(String key) label;

  const SetInputFields({
    super.key,
    required this.trackingType,
    required this.reps,
    required this.weight,
    required this.duration,
    required this.distance,
    required this.label,
  });

  @override
  State<SetInputFields> createState() => _SetInputFieldsState();
}

class _SetInputFieldsState extends State<SetInputFields> {
  @override
  void initState() {
    super.initState();
    // The slider has to follow the text field: typing 60 must move the thumb,
    // or the two controls disagree about the same number.
    widget.weight.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.weight.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  static double _readDouble(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  static int _readInt(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? 0;

  void _stepInt(TextEditingController c, int by, {int min = 0}) {
    final next = (_readInt(c) + by).clamp(min, 100000);
    c.text = '$next';
    // Caret to the end, or the next keystroke lands in the middle of it.
    c.selection = TextSelection.collapsed(offset: c.text.length);
    HapticFeedback.selectionClick();
  }

  void _setWeight(double value) {
    final snapped = (value / kWeightStep).round() * kWeightStep;
    widget.weight.text = _trim(snapped);
    widget.weight.selection =
        TextSelection.collapsed(offset: widget.weight.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final spec = SetFieldSpec.of(widget.trackingType);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The effort axis comes first and takes focus: it is what the user
        // opened the dialog to type.
        if (spec.duration)
          _stepper(
            widget.label('duration'),
            widget.duration,
            step: kDurationStep,
            autofocus: true,
            suffix: tr('unit_seconds'),
          ),
        if (spec.distance)
          _decimalField(
            widget.label('distance'),
            widget.distance,
            autofocus: !spec.duration,
            suffix: 'm',
          ),
        if (spec.reps)
          _stepper(
            widget.label('reps'),
            widget.reps,
            step: kRepsStep,
            autofocus: !spec.duration && !spec.distance,
          ),
        if (spec.weight) _weightSlider(),
      ],
    );
  }

  /// A number with a minus and a plus either side, still typeable in the
  /// middle.
  Widget _stepper(
    String label,
    TextEditingController controller, {
    required int step,
    bool autofocus = false,
    String? suffix,
  }) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              _roundButton(Icons.remove, () => _stepInt(controller, -step)),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    suffixText: suffix,
                    suffixStyle: TextStyle(
                        color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              _roundButton(Icons.add, () => _stepInt(controller, step)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(color: colors.primary1.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 18, color: colors.primary1),
      ),
    );
  }

  /// Weight: a 2.5 kg slider with the exact number beside it.
  ///
  /// The slider is for the common move - up or down a plate - and the field is
  /// for everything it cannot express: 42.5 kg on a machine, or 180 kg past
  /// the default ceiling.
  Widget _weightSlider() {
    final colors = context.colors;
    final value = _readDouble(widget.weight);
    // The track grows to fit whatever is typed rather than clamping it.
    final max = value > kWeightSliderMax
        ? (value / kWeightStep).ceil() * kWeightStep
        : kWeightSliderMax;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.label('weight'),
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 12)),
              ),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: widget.weight,
                  textAlign: TextAlign.right,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '0',
                    suffixText: tr('unit_kg').toLowerCase(),
                    suffixStyle: TextStyle(
                        color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.clamp(0, max),
              min: 0,
              max: max,
              // One division per plate change, so the thumb snaps to real
              // weights instead of landing on 37.3 kg.
              divisions: (max / kWeightStep).round(),
              activeColor: colors.primary1,
              inactiveColor: colors.surfaceVariant,
              onChanged: _setWeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _decimalField(
    String label,
    TextEditingController controller, {
    bool autofocus = false,
    String? suffix,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
          suffixText: suffix,
          suffixStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
          isDense: true,
          filled: true,
          fillColor: colors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Reads the controllers back, keeping only the axes this exercise uses.
///
/// Filtering by the spec matters: a Plank's reps controller may still hold a
/// stale value from a previous exercise's dialog, and sending it would put a
/// rep count on a set that was measured in seconds.
SetValues readSetValues({
  required TrackingType trackingType,
  required TextEditingController reps,
  required TextEditingController weight,
  required TextEditingController duration,
  required TextEditingController distance,
}) {
  final spec = SetFieldSpec.of(trackingType);
  int? whole(TextEditingController c) {
    final value = int.tryParse(c.text.trim());
    // A stepper bottoms out at 0, and 0 kg or 0 reps is "not set" rather than
    // a performance - except reps, where a failed set is worth recording.
    return value;
  }

  // Commas are what a Vietnamese keyboard offers for a decimal point.
  double? decimal(TextEditingController c) {
    final value = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return value == 0 ? null : value;
  }

  return SetValues(
    reps: spec.reps ? whole(reps) : null,
    weightKg: spec.weight ? decimal(weight) : null,
    durationSeconds: spec.duration ? whole(duration) : null,
    distanceM: spec.distance ? decimal(distance) : null,
  );
}

/// "KH 12 × 20kg", "KH 60 giây", "KH 20m × 40kg" - the planned line above the
/// inputs, phrased for whichever axes were actually planned.
String formatTarget({
  int? reps,
  double? weightKg,
  int? durationSeconds,
  double? distanceM,
}) {
  String trim(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  final parts = <String>[];
  if (durationSeconds != null) parts.add('$durationSeconds ${tr('unit_seconds')}');
  if (distanceM != null) parts.add('${trim(distanceM)}m');
  if (reps != null) parts.add('$reps');
  if (weightKg != null) parts.add('${trim(weightKg)}kg');
  return parts.join(' × ');
}

/// The one number that identifies a set on a summary line, with its unit.
///
/// A Plank's set is "60 giây", a carry's is "20m", a Bench Press's is "12".
/// Reading `reps` for all three is what made every timed exercise show up as
/// a dash on the calendar.
String setAxisValue({
  required TrackingType trackingType,
  int? reps,
  int? durationSeconds,
  double? distanceM,
}) {
  String trim(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  switch (trackingType) {
    case TrackingType.duration:
      return durationSeconds == null ? '-' : '$durationSeconds${tr('unit_seconds')}';
    case TrackingType.distance:
      return distanceM == null ? '-' : '${trim(distanceM)}m';
    case TrackingType.repsDuration:
      // Both axes matter here, so neither can stand in for the other.
      if (reps == null && durationSeconds == null) return '-';
      final parts = <String>[
        if (reps != null) '$reps',
        if (durationSeconds != null) '$durationSeconds${tr('unit_seconds')}',
      ];
      return parts.join('×');
    case TrackingType.reps:
      return reps?.toString() ?? '-';
  }
}
