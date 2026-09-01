import 'package:bodify/common/colo_extension.dart';
import 'package:flutter/material.dart';

class TabButton extends StatelessWidget {
  /// Asset paths for tabs that ship with an image in the kit.
  final String? icon;
  final String? selectIcon;

  /// Alternative to the asset pair, for tabs the kit has no artwork for.
  final IconData? iconData;

  final VoidCallback onTap;
  final bool isActive;

  const TabButton({
    super.key,
    this.icon,
    this.selectIcon,
    this.iconData,
    required this.isActive,
    required this.onTap,
  }) : assert(iconData != null || (icon != null && selectIcon != null),
            'Provide either iconData or both icon and selectIcon');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (iconData != null)
          Icon(
            iconData,
            size: 25,
            color: isActive ? TColor.primaryColor1 : TColor.gray,
          )
        else
          Image.asset(isActive ? selectIcon! : icon!,
              width: 25, height: 25, fit: BoxFit.fitWidth),
         SizedBox(
          height: isActive ?  8: 12,
        ),
        if(isActive)
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: TColor.secondaryG,
              ),
              borderRadius: BorderRadius.circular(2)),
        )
      ]),
    );
  }
}
