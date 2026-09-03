import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/api_exception.dart';
import '../../models/exercise_models.dart';
import '../../services/exercise_service.dart';

class ExerciseDetailView extends StatefulWidget {
  final int exerciseId;

  const ExerciseDetailView({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailView> createState() => _ExerciseDetailViewState();
}

class _ExerciseDetailViewState extends State<ExerciseDetailView> {
  ExerciseDetail? _exercise;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await ExerciseService.instance.getExercise(widget.exerciseId);
      if (!mounted) return;
      setState(() {
        _exercise = detail;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

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
          tr('exerciseDetail'),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: context.colors.primary1));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: context.colors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
            TextButton(
              onPressed: _load,
              child: Text(tr('retry'), style: TextStyle(color: context.colors.primary1)),
            ),
          ],
        ),
      );
    }

    final exercise = _exercise!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exercise.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  exercise.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: context.colors.surfaceVariant,
                    child: Icon(Icons.fitness_center, color: context.colors.textSecondary, size: 40),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            exercise.name ?? "#${exercise.exerciseId}",
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in [
                exercise.experienceLevel,
                exercise.exerciseType,
                exercise.mechanics,
                exercise.forceType,
              ].where((e) => e != null && e.isNotEmpty))
                _tag(tag!),
            ],
          ),
          if (exercise.videoUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.play_circle_outline,
                    color: context.colors.primary1, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('hasVideo'),
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          _section(tr('muscles'), exercise.muscles.isEmpty
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final muscle in exercise.muscles)
                      _tag("${muscle.name} (${muscle.role})",
                          highlight: muscle.role == "primary"),
                  ],
                )),
          _section(tr('equipment'), exercise.equipment.isEmpty
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in exercise.equipment) _tag(item.name),
                  ],
                )),
          _section(tr('overview'), _text(exercise.overview)),
          _section(tr('instructions'), _text(exercise.instructions)),
          _section(tr('tips'), _text(exercise.tips)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget? _text(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return Text(
      value,
      style: TextStyle(color: context.colors.textSecondary, fontSize: 13, height: 1.5),
    );
  }

  /// Sections with nothing to show are dropped rather than left as empty
  /// headings - the data has gaps (some exercises have no overview).
  Widget _section(String title, Widget? child) {
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _tag(String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: highlight ? LinearGradient(colors: context.colors.primaryGradient) : null,
        color: highlight ? null : context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlight ? context.colors.surface : context.colors.textSecondary,
          fontSize: 11,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
