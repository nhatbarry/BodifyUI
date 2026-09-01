import 'package:flutter/material.dart';

import '../../common/colo_extension.dart';
import '../../core/app_strings.dart';
import 'workout_calendar_tab.dart';

/// Second bottom-tab: one screen holding Workout Tracker and Meal Planner,
/// switched by the segmented control at the top.
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
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          tr('tracker'),
          style: TextStyle(
              color: TColor.black, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabSwitcher(),
            const SizedBox(height: 14),
            Expanded(
              child: _selectedTab == 0
                  ? const WorkoutCalendarTab()
                  : const _MealPlannerTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TColor.lightGray,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _tab(tr('workoutTracker'), 0),
          _tab(tr('mealPlanner'), 1),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(colors: TColor.primaryG) : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? TColor.white : TColor.gray,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MealPlannerTab extends StatelessWidget {
  const _MealPlannerTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TColor.lightGray,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu, color: TColor.gray, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              tr('mealPlanner'),
              style: TextStyle(
                  color: TColor.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              tr('featureInProgress'),
              textAlign: TextAlign.center,
              style: TextStyle(color: TColor.gray, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
