import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../common/app_colors.dart';

/// A segmented control that grows with its localized labels.
class PillSwitcher extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Minimum inner height; text scaling may increase it.
  final double height;
  const PillSwitcher(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onChanged,
      this.height = 40})
      : assert(labels.length > 0);

  static TextStyle _labelStyle(BuildContext context) =>
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
          .copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25);

  static double heightFor(
      BuildContext context, List<String> labels, double width,
      {double minimumHeight = 40}) {
    final labelWidth = math.max(1.0, (width - 8) / labels.length - 24);
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
          text: TextSpan(text: label, style: _labelStyle(context)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout(maxWidth: labelWidth);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    return math.max(math.max(48, minimumHeight), labelHeight + 20) + 8;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return LayoutBuilder(builder: (context, constraints) {
      final totalHeight = heightFor(context, labels, constraints.maxWidth,
          minimumHeight: height);
      return Material(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            height: totalHeight - 8,
            child: Stack(children: [
              AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                    labels.length == 1
                        ? 0
                        : -1 + 2 * selected / (labels.length - 1),
                    0),
                child: FractionallySizedBox(
                    widthFactor: 1 / labels.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: colors.primaryGradient),
                            borderRadius: BorderRadius.circular(21)))),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                      child: Semantics(
                    label: labels[i],
                    button: true,
                    selected: selected == i,
                    inMutuallyExclusiveGroup: true,
                    onTap: () => onChanged(i),
                    child: ExcludeSemantics(
                        child: InkWell(
                      onTap: () => onChanged(i),
                      borderRadius: BorderRadius.circular(21),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Center(
                            child: AnimatedDefaultTextStyle(
                                duration: duration,
                                style: _labelStyle(context).copyWith(
                                    color: selected == i
                                        ? colors.onPrimary
                                        : colors.textSecondary,
                                    fontWeight: selected == i
                                        ? FontWeight.w700
                                        : FontWeight.w500),
                                child: Text(labels[i],
                                    textAlign: TextAlign.center))),
                      ),
                    )),
                  )),
              ]),
            ]),
          ),
        ),
      );
    });
  }
}
