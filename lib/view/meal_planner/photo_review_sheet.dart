import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/meal_models.dart';
import '../../services/meal_service.dart';

/// Asks camera or gallery, then picks a photo. Null when the user backs out.
///
/// Shrunk on the device first: the server re-encodes to 1280 px anyway, and a
/// 4000 px original over a phone connection is seconds of upload for nothing.
Future<File?> pickMealPhoto(BuildContext context) async {
  final colors = context.colors;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: colors.primary1),
              title: Text(AppStrings.of('btn_take_photo'),
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: colors.primary1),
              title: Text(AppStrings.of('btn_pick_gallery'),
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 88,
  );
  return picked == null ? null : File(picked.path);
}

/// The photo's draft: what the model saw, matched to the catalog, for the user
/// to check before anything reaches the diary.
///
/// Runs the analysis itself, so the photo is on screen while the model looks
/// at it. Nothing is logged until "Add" - each ticked dish is then saved
/// through the ordinary `logItem` / `logCustomItem`, carrying the analysis id.
///
/// A catalog match is preferred and preselected: its figures were measured.
/// The model's own estimate is the last choice in each dropdown, labelled as
/// one, and the only choice when the catalog has nothing by that name.
/// Pops `true` when anything was saved.
class PhotoReviewSheet extends StatefulWidget {
  final int mealId;
  final File image;
  final ItemStatus defaultStatus;

  const PhotoReviewSheet({
    super.key,
    required this.mealId,
    required this.image,
    this.defaultStatus = ItemStatus.eaten,
  });

  @override
  State<PhotoReviewSheet> createState() => _PhotoReviewSheetState();
}

/// Below this the dish starts unticked: the model said it was unsure, and an
/// unticked row costs one tap where a wrong one costs a delete.
const double _confidentEnough = 0.5;

class _Row {
  _Row(this.detected)
      : selected = detected.confidence >= _confidentEnough,
        // The server lists plausible matches first; when even the first one
        // is not, the model's estimate is the safer default.
        pick = detected.candidates.isNotEmpty &&
                detected.candidates.first.plausible
            ? 0
            : -1 {
    amount = TextEditingController(text: _format(defaultQuantity));
  }

  final DetectedFood detected;
  bool selected;

  /// Index into the candidates, or -1 for the model's estimate.
  int pick;
  late final TextEditingController amount;

  PhotoCandidate? get candidate =>
      pick >= 0 ? detected.candidates[pick] : null;

  double get defaultQuantity =>
      candidate?.quantity ?? detected.estimate.quantity;

  MealUnit get unit => candidate?.unit ?? MealUnit.serving;

  double? get quantity {
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    // A hand-typed food is capped at 100 servings, a catalog one at 10000.
    if (value > (candidate == null ? 100 : 10000)) return null;
    return double.parse(value.toStringAsFixed(2));
  }

  /// Linear in the amount, for either kind: the candidate came priced for its
  /// own suggested amount in the same unit, and the estimate is per serving.
  double? get kcal {
    final q = quantity;
    if (q == null) return null;
    final c = candidate;
    if (c != null) {
      return c.quantity == 0 ? null : c.energyKcal * q / c.quantity;
    }
    return detected.estimate.energyKcal * q;
  }

  void choose(int index) {
    pick = index;
    // The unit may have changed with the food, so the old number means
    // nothing - start again from what the photo suggested for this one.
    amount.text = _format(defaultQuantity);
  }
}

String _format(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

class _PhotoReviewSheetState extends State<PhotoReviewSheet> {
  PhotoAnalysis? _analysis;
  List<_Row> _rows = const [];
  late ItemStatus _status = widget.defaultStatus;

  bool _analyzing = true;
  bool _saving = false;
  ApiException? _error;
  bool _savedAny = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final analysis =
          await MealService.instance.analyzeMealPhoto(widget.mealId, widget.image);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _rows = analysis.items.map(_Row.new).toList();
        _analyzing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _analyzing = false;
      });
    }
  }

  /// When the analysis is refused, the photo can still be kept - it is the
  /// meal's photo either way. Only offered for the user's own daily limit,
  /// which refuses before uploading; a failure after upload already kept it.
  Future<void> _savePhotoOnly() async {
    setState(() => _saving = true);
    try {
      await MealService.instance.uploadMealPhoto(widget.mealId, widget.image);
      if (mounted) Navigator.pop(context, false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  Iterable<_Row> get _chosen => _rows.where((r) => r.selected);

  bool get _canSave =>
      !_saving && _chosen.isNotEmpty && _chosen.every((r) => r.quantity != null);

  /// One request per dish, in order. A failure stops there: the rows already
  /// saved leave the list, so a retry cannot log them twice.
  Future<void> _save() async {
    final analysis = _analysis;
    if (analysis == null || !_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    for (final row in _chosen.toList()) {
      try {
        final c = row.candidate;
        if (c != null) {
          await MealService.instance.logItem(
            mealId: widget.mealId,
            foodId: c.food.foodId,
            quantity: row.quantity!,
            unit: c.unit,
            status: _status,
            photoAnalysisId: analysis.analysisId,
          );
        } else {
          final e = row.detected.estimate;
          await MealService.instance.logCustomItem(
            mealId: widget.mealId,
            name: e.name,
            energyKcal: e.energyKcal,
            proteinG: e.proteinG,
            fatG: e.fatG,
            carbG: e.carbG,
            quantity: row.quantity!,
            status: _status,
            photoAnalysisId: analysis.analysisId,
          );
        }
        _savedAny = true;
        setState(() => _rows = [..._rows]..remove(row));
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = e;
        });
        return;
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      // Not mid-save: the diary reloads when the sheet closes, and a request
      // still in flight would land after that reload.
      canPop: !_saving,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.of('title_photo_review'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, _savedAny),
                      icon: Icon(Icons.close, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Image.file(
                          widget.image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._body(colors),
                  ],
                ),
              ),
              if (_analysis != null && _rows.isNotEmpty) _footer(colors),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BodifyColors colors) {
    if (_analyzing) {
      return [
        const SizedBox(height: 18),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 14),
        Text(
          AppStrings.of('msg_photo_analyzing'),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.of('msg_photo_privacy'),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
        ),
      ];
    }

    final error = _error;
    if (_analysis == null && error != null) {
      return [
        Text(
          error.message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            // The user's own limit will still be spent in a minute; Google's
            // quota or a timeout may not be.
            if (error.statusCode != 429)
              FilledButton(
                onPressed: _analyze,
                child: Text(AppStrings.of('btn_retry')),
              ),
            if (error.statusCode == 429)
              OutlinedButton(
                onPressed: _saving ? null : _savePhotoOnly,
                child: Text(AppStrings.of('btn_save_photo_only')),
              ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.of('btn_close')),
            ),
          ],
        ),
      ];
    }

    if (_rows.isEmpty) {
      return [
        Text(
          AppStrings.of('msg_photo_no_food'),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, _savedAny),
            child: Text(AppStrings.of('btn_close')),
          ),
        ),
      ];
    }

    return [
      Text(
        AppStrings.of('msg_photo_review_hint'),
        style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
      ),
      const SizedBox(height: 10),
      for (final row in _rows) ...[
        _DetectedRow(
          row: row,
          enabled: !_saving,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
      ],
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            error.message,
            style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 12.5),
          ),
        ),
    ];
  }

  Widget _footer(BodifyColors colors) {
    final total = _chosen.fold<double>(0, (sum, r) => sum + (r.kcal ?? 0));
    final count = _chosen.length;
    final label = _status == ItemStatus.planned
        ? AppStrings.of('btn_plan_n_foods')
        : AppStrings.of('btn_add_n_foods');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SegmentedButton<ItemStatus>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ItemStatus.eaten,
                      label: Text(AppStrings.of('label_eaten')),
                    ),
                    ButtonSegment(
                      value: ItemStatus.planned,
                      label: Text(AppStrings.of('label_status_planned')),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() => _status = value.first),
                ),
                const Spacer(),
                Text(
                  '≈ ${total.round()} ${AppStrings.of('unit_kcal')}',
                  style: TextStyle(
                    color: colors.primary1,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
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
                    : Text(label.replaceFirst('{n}', '$count')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedRow extends StatelessWidget {
  final _Row row;
  final bool enabled;
  final VoidCallback onChanged;

  const _DetectedRow({
    required this.row,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detected = row.detected;
    final kcal = row.kcal;
    final unsure = detected.confidence < _confidentEnough;

    final options = <DropdownMenuItem<int>>[
      for (final (i, c) in detected.candidates.indexed)
        DropdownMenuItem(
          value: i,
          child: Text(
            c.food.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textPrimary, fontSize: 13),
          ),
        ),
      DropdownMenuItem(
        value: -1,
        child: Text(
          '${AppStrings.of('label_ai_estimate')}: ${detected.estimate.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic),
        ),
      ),
    ];

    return Opacity(
      opacity: row.selected ? 1 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: row.selected,
                  onChanged: enabled
                      ? (v) {
                          row.selected = v ?? false;
                          onChanged();
                        }
                      : null,
                ),
                Expanded(
                  child: Text(
                    detected.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (unsure) _Tag(AppStrings.of('label_low_confidence')),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: DropdownButton<int>(
                value: row.pick,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: colors.surface,
                items: options,
                onChanged: enabled
                    ? (v) {
                        if (v == null) return;
                        row.choose(v);
                        onChanged();
                      }
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: row.amount,
                      enabled: enabled,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        errorText: row.quantity == null ? '' : null,
                        errorStyle: const TextStyle(height: 0),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.of('unit_${row.unit.name}'),
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  if (row.candidate == null) _Tag(AppStrings.of('label_ai_estimate')),
                  const Spacer(),
                  Text(
                    kcal == null
                        ? '—'
                        : '${kcal.round()} ${AppStrings.of('unit_kcal')}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primary1.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.primary1,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
