import 'package:flutter/material.dart';
import '../common/app_colors.dart';

class TitleSubtitleCell extends StatelessWidget {
  final String title;
  final String subtitle;
  const TitleSubtitleCell(
      {super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    return Semantics(
      label: '$subtitle: $title',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              textAlign: TextAlign.center,
              style: type.titleMedium?.copyWith(
                  color: colors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: type.bodySmall?.copyWith(color: colors.textSecondary)),
        ]),
      ),
    );
  }
}
