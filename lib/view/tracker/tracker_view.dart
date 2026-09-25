import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/fade_indexed_stack.dart';
import '../../common_widget/pill_switcher.dart';
import '../../core/app_strings.dart';
import 'schedule_list_view.dart';
import '../meal_planner/meal_diary_view.dart';

/// Second bottom-tab: one screen holding Workout Tracker and Meal Planner,
/// switched by the segmented control at the top.
///
/// Both halves stay mounted. Swapping one widget for the other used to
/// destroy the diary on every switch, so it reloaded each time the user came
/// back to it.
class TrackerView extends StatefulWidget {
  const TrackerView({super.key});

  @override
  State<TrackerView> createState() => _TrackerViewState();
}

class _TrackerViewState extends State<TrackerView> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          tr('nav_tracker'),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PillSwitcher(
                labels: [tr('title_workout_tracker'), tr('nav_meal_planner')],
                selected: _selectedTab,
                onChanged: (i) => setState(() => _selectedTab = i),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FadeIndexedStack(
                index: _selectedTab,
                children: const [
                  ScheduleListView(),
                  MealDiaryView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
