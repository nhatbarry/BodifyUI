import 'package:bodify/common/app_colors.dart';
import 'package:flutter/material.dart';

class TabButton extends StatelessWidget {
  /// Asset paths for tabs that ship with an image in the kit.
  final String? icon;
  final String? selectIcon;

  /// Alternative to the asset pair, for tabs the kit has no artwork for.
  final IconData? iconData;

  final VoidCallback onTap;
  final bool isActive;
  final String label;

  const TabButton({
    super.key,
    this.icon,
    this.selectIcon,
    this.iconData,
    required this.label,
    required this.isActive,
    required this.onTap,
  }) : assert(iconData != null || (icon != null && selectIcon != null),
            'Provide either iconData or both icon and selectIcon');

  /// Also used by the bar to reserve enough space for translated, scaled labels.
  static TextStyle labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            fontSize: 11,
            height: 1.15,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
          );

  // Material navigation keeps destination labels compact while its tooltips
  // follow the system text scale. Allow a modest label increase without
  // breaking destination names into fragments; body text remains unrestricted.
  static TextScaler labelTextScaler(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = isActive ? colors.textPrimary : colors.textSecondary;

    return Semantics(
      label: label,
      button: true,
      selected: isActive,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 5),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.secondary1.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: iconData != null
                            ? Icon(iconData, size: 22, color: foreground)
                            : Image.asset(
                                isActive ? selectIcon! : icon!,
                                width: 22,
                                height: 22,
                                color: foreground,
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        textScaler: labelTextScaler(context),
                        style: labelStyle(context).copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
