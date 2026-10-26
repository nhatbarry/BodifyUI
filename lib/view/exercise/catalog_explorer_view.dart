import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/fade_indexed_stack.dart';
import '../../common_widget/pill_switcher.dart';
import '../../core/app_strings.dart';
import '../meal_planner/food_explorer_view.dart';
import 'exercise_explorer_view.dart';

/// What the search button opens: both catalogs, exercises and foods, behind
/// one switch - the same pill control the Tracker tab uses for Workout /
/// Meal Planner.
///
/// Both halves stay alive in an IndexedStack, so a search typed on one side
/// survives a look at the other. The exercise explorer can still close this
/// route onto a tab ("no schedule yet, go make one"): its Navigator.pop runs
/// inside this route and returns through it to MainTabView.
class CatalogExplorerView extends StatefulWidget {
  const CatalogExplorerView({super.key});

  @override
  State<CatalogExplorerView> createState() => _CatalogExplorerViewState();
}

class _CatalogExplorerViewState extends State<CatalogExplorerView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labels = [tr('title_exercises'), tr('title_foods')];
    final switchWidth =
        (MediaQuery.sizeOf(context).width - 112).clamp(160.0, 280.0);
    final switchHeight = PillSwitcher.heightFor(context, labels, switchWidth);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        toolbarHeight: switchHeight + 8,
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: SizedBox(
          width: switchWidth,
          child: PillSwitcher(
            labels: labels,
            selected: _tab,
            height: 34,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
      ),
      body: FadeIndexedStack(
        index: _tab,
        children: const [
          ExerciseExplorerView(embedded: true),
          FoodExplorerView(),
        ],
      ),
    );
  }
}
