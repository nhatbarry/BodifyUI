import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/exercise_thumbnail.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/workout_plan_models.dart';
import '../../services/workout_plan_service.dart';

/// Target sets for one planned exercise: how many, how many reps, how much
/// weight, how long to rest.
///
/// Every set is its own row rather than a "3 × 10" pair of numbers, because a
/// real working set list is rarely uniform - 10 / 10 / 8 with the weight going
/// up is the normal shape, and a count-and-reps model cannot say it.
///
/// Edits are written straight through and the local list is patched from the
/// server's answer. Popping returns true when anything changed, so the caller
/// knows whether to reload.
class WorkoutSetsView extends StatefulWidget {
  final PlannedExercise exercise;

  const WorkoutSetsView({super.key, required this.exercise});

  @override
  State<WorkoutSetsView> createState() => _WorkoutSetsViewState();
}

class _WorkoutSetsViewState extends State<WorkoutSetsView> {
  late List<TargetSet> _sets = List<TargetSet>.from(widget.exercise.sets);
  bool _busy = false;
  bool _changed = false;

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException ? error.message : '$error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    // Seeded from the last set: sets in a row usually repeat, and typing the
    // same three numbers again is the most common thing this screen would ask
    // for otherwise.
    final previous = _sets.isEmpty ? null : _sets.last;
    final values = await _editDialog(
      title: tr('addSet'),
      reps: previous?.targetReps,
      weight: previous?.targetWeightKg,
      rest: previous?.restSeconds,
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      final created = await WorkoutPlanService.instance.addSet(
        widget.exercise.workoutExerciseId,
        targetReps: values.reps,
        targetWeightKg: values.weight,
        restSeconds: values.rest,
      );
      if (!mounted) return;
      setState(() {
        _sets.add(created);
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _edit(int index) async {
    final target = _sets[index];
    final values = await _editDialog(
      title: tr('setNumber').replaceFirst('{n}', '${index + 1}'),
      reps: target.targetReps,
      weight: target.targetWeightKg,
      rest: target.restSeconds,
    );
    if (values == null) return;

    setState(() => _busy = true);
    try {
      final updated = await WorkoutPlanService.instance.updateSet(
        target.id,
        targetReps: values.reps,
        targetWeightKg: values.weight,
        restSeconds: values.rest,
        // Clearing a field is a real edit: "any weight you like" is a valid
        // instruction, and only an explicit null says it.
        clearWeight: values.weight == null,
        clearRest: values.rest == null,
      );
      if (!mounted) return;
      setState(() {
        _sets[index] = updated;
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _delete(int index) async {
    final target = _sets[index];
    setState(() => _busy = true);
    try {
      await WorkoutPlanService.instance.deleteSet(target.id);
      if (!mounted) return;
      setState(() {
        _sets.removeAt(index);
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final previous = List<TargetSet>.from(_sets);
    setState(() {
      final moved = _sets.removeAt(oldIndex);
      _sets.insert(newIndex, moved);
      _busy = true;
    });

    try {
      // The whole list goes up, not just the moved row - the server rejects a
      // partial reorder, and one request keeps every intermediate position
      // inside a single transaction.
      final refreshed = await WorkoutPlanService.instance.reorderSets(
        widget.exercise.workoutExerciseId,
        _sets.map((s) => s.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _sets = List<TargetSet>.from(refreshed.sets);
        _busy = false;
        _changed = true;
      });
    } catch (e) {
      // Put the list back: the drag already moved it on screen, and leaving it
      // there would show an order the server does not have.
      if (mounted) {
        setState(() {
          _sets = previous;
          _busy = false;
        });
      }
      _showError(e);
    }
  }

  Future<_SetValues?> _editDialog({
    required String title,
    int? reps,
    double? weight,
    int? rest,
  }) {
    return showDialog<_SetValues>(
      context: context,
      builder: (_) => _SetDialog(
        title: title,
        reps: reps,
        weight: weight,
        rest: rest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.textPrimary),
          title: Text(
            widget.exercise.name ?? '#${widget.exercise.exerciseId}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_busy)
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    color: colors.primary1,
                    backgroundColor: Colors.transparent,
                  ),
                )
              else
                const SizedBox(height: 2),
              _buildSummary(),
              Expanded(child: _buildList()),
              _buildAddButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          ExerciseThumbnail(
            url: widget.exercise.listImageUrl,
            cacheKey: widget.exercise.listImageCacheKey,
            size: 52,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _sets.isEmpty
                  ? tr('noTargetSets')
                  : tr('setsTotal').replaceFirst('{n}', '${_sets.length}'),
              style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final colors = context.colors;

    if (_sets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, color: colors.textSecondary, size: 34),
              const SizedBox(height: 12),
              Text(
                tr('noTargetSetsHint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _sets.length,
      onReorderItem: _reorder,
      itemBuilder: (_, i) => _SetRow(
        // Keyed by set id, not index: a reorder that reused index keys would
        // animate the wrong rows.
        key: ValueKey(_sets[i].id),
        index: i,
        set: _sets[i],
        onTap: () => _edit(i),
        onDelete: () => _delete(i),
      ),
    );
  }

  Widget _buildAddButton() {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _add,
            icon: Icon(Icons.add, color: colors.onPrimary, size: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary1,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            label: Text(tr('addSet'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int index;
  final TargetSet set;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget field(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 10)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );

    String number(num? value, String suffix) {
      if (value == null) return '—';
      // 40.0 is how a double prints; 40 is what a weight looks like.
      final text = value is double && value == value.roundToDouble()
          ? '${value.round()}'
          : '$value';
      return '$text$suffix';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: colors.surface, shape: BoxShape.circle),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: colors.primary1,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                field(tr('reps'), number(set.targetReps, '')),
                field(tr('weight'), number(set.targetWeightKg, ' kg')),
                field(tr('rest'), number(set.restSeconds, 's')),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close,
                      color: Color(0xFFE74C3C), size: 18),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_handle,
                        color: colors.textSecondary, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the dialog hands back. A null field means "clear this", which is
/// different from the field being absent - see updateSet's clear flags.
class _SetValues {
  final int? reps;
  final double? weight;
  final int? rest;

  const _SetValues({this.reps, this.weight, this.rest});
}

class _SetDialog extends StatefulWidget {
  final String title;
  final int? reps;
  final double? weight;
  final int? rest;

  const _SetDialog({
    required this.title,
    this.reps,
    this.weight,
    this.rest,
  });

  @override
  State<_SetDialog> createState() => _SetDialogState();
}

class _SetDialogState extends State<_SetDialog> {
  late final _reps =
      TextEditingController(text: widget.reps?.toString() ?? '');
  late final _weight = TextEditingController(
      text: widget.weight == null ? '' : _trimZeros(widget.weight!));
  late final _rest =
      TextEditingController(text: widget.rest?.toString() ?? '');

  /// 40.00 kg reads badly in a text field; 40 does.
  static String _trimZeros(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget input(String label, TextEditingController controller,
            {bool decimal = false, bool autofocus = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              labelStyle:
                  TextStyle(color: colors.textSecondary, fontSize: 13),
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

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(widget.title,
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          input(tr('reps'), _reps, autofocus: true),
          input(tr('targetWeightKg'), _weight, decimal: true),
          input(tr('restSeconds'), _rest),
          Text(
            tr('emptyFieldMeansUnset'),
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text(tr('cancel'), style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _SetValues(
              reps: int.tryParse(_reps.text.trim()),
              // Accepts "42,5" as well: a Vietnamese keyboard offers a comma.
              weight: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
              rest: int.tryParse(_rest.text.trim()),
            ),
          ),
          child: Text(tr('save'), style: TextStyle(color: colors.primary1)),
        ),
      ],
    );
  }
}
