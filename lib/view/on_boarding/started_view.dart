import 'package:bodify/common/app_colors.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/view/on_boarding/on_boarding_view.dart';
import 'package:flutter/material.dart';

import '../../common_widget/round_button.dart';

class StartedView extends StatefulWidget {
  const StartedView({super.key});

  @override
  State<StartedView> createState() => _StartedViewState();
}

class _StartedViewState extends State<StartedView> {
  bool isChangeColor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The intro is the only place this screen leads, so decode its pictures
    // now, while the user is still reading the title.
    precacheOnBoardingImages(context);
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Stack(
        children: [
          // The gradient fades in rather than snapping on. It is its own layer
          // under the content, so the fade repaints one rectangle and not the
          // text and button above it.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isChangeColor ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: context.colors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
              ),
            ),
          ),
          SizedBox(
            width: media.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text(
                  tr('app_name'),
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  tr('app_tagline'),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: RoundButton(
                      title: tr('btn_get_started'),
                      type: isChangeColor
                          ? RoundButtonType.textGradient
                          : RoundButtonType.bgGradient,
                      onPressed: () {
                        if (isChangeColor) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const OnBoardingView()));
                        } else {
                          setState(() {
                            isChangeColor = true;
                          });
                        }
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
