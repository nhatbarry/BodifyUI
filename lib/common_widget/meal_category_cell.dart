import 'package:bodify/common_widget/round_button.dart';
import 'package:flutter/material.dart';

import '../common/app_colors.dart';

class MealCategoryCell extends StatelessWidget {
  final Map cObj;
  final int index;
  const MealCategoryCell({super.key, required this.index, required this.cObj});

  @override
  Widget build(BuildContext context) {
    bool isEvent = index % 2 == 0;
    return Container(
      margin: const EdgeInsets.all(4),
      width: 80,
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEvent
                ? [
                    context.colors.primary2.withOpacity(0.5),
                    context.colors.primary1.withOpacity(0.5)
                  ]
                : [
                    context.colors.secondary2.withOpacity(0.5),
                    context.colors.secondary1.withOpacity(0.5)
                  ],
          ),
          borderRadius:  BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          ClipRRect(
            borderRadius: BorderRadius.circular(17.5) ,
            child: Container(
              
              decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius:  BorderRadius.circular(17.5)),
          
              child: Image.asset(
                  cObj["image"].toString(),
                  width: 35,
                  height: 35,
                  fit: BoxFit.contain,
                ),),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4,horizontal: 8),
            child: Text(
              cObj["name"],
              maxLines: 1,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        
        ],
      ),
    );
  }
}
