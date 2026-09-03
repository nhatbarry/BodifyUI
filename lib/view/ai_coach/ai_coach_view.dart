import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/app_strings.dart';

/// Replaces the kit's Photo Progress tab. Placeholder until the AI coach
/// feature is designed.
class AiCoachView extends StatelessWidget {
  const AiCoachView({super.key});

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
          tr('aiCoach'),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: context.colors.primaryGradient),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: context.colors.surface, size: 38),
              ),
              const SizedBox(height: 20),
              Text(
                tr('aiCoach'),
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                "${tr('aiCoachSubtitle')}\n${tr('featureInProgress')}",
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
