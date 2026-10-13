import 'package:flutter/material.dart';
import '../common/app_colors.dart';

enum RoundButtonType { bgGradient, bgSGradient, textGradient }

class RoundButton extends StatelessWidget {
  final String title;
  final RoundButtonType type;
  final VoidCallback? onPressed;
  final double fontSize;
  final double elevation;
  final FontWeight fontWeight;
  const RoundButton(
      {super.key,
      required this.title,
      required this.onPressed,
      this.type = RoundButtonType.bgGradient,
      this.fontSize = 16,
      this.elevation = 1,
      this.fontWeight = FontWeight.w700});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = type != RoundButtonType.textGradient;
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(25);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: filled && enabled
                ? LinearGradient(
                    colors: type == RoundButtonType.bgSGradient
                        ? colors.secondaryGradient
                        : colors.primaryGradient)
                : null,
            color: filled
                ? (enabled ? null : colors.surfaceVariant)
                : colors.surface,
            borderRadius: radius,
            border: filled
                ? null
                : Border.all(
                    color: colors.textSecondary.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  minWidth: double.infinity, minHeight: 50),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: enabled
                              ? (filled ? colors.onPrimary : colors.textPrimary)
                              : colors.textSecondary,
                          fontSize: fontSize,
                          fontWeight: fontWeight,
                          height: 1.3)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
