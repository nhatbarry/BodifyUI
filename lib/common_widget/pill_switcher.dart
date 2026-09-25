import 'package:flutter/material.dart';

import '../common/app_colors.dart';

/// The two-or-more-way pill switch (Workout / Meal Planner, Exercises /
/// Foods). The gradient highlight slides to the chosen option instead of
/// jumping there, so the switch shows which way the screen moved.
class PillSwitcher extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;

  const PillSwitcher({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = labels.length;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(25),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: duration,
              curve: Curves.easeOutCubic,
              // -1 is the left edge and 1 the right, so option i of n sits at
              // -1 + 2i/(n-1).
              alignment: Alignment(
                count == 1 ? 0 : -1 + 2 * selected / (count - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors.primaryGradient),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: TextStyle(
                            color: i == selected
                                ? colors.surface
                                : colors.textSecondary,
                            fontSize: 13,
                            fontWeight:
                                i == selected ? FontWeight.w700 : FontWeight.w500,
                            fontFamily:
                                DefaultTextStyle.of(context).style.fontFamily,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
