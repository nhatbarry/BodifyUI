import 'package:bodify/common_widget/on_boarding_page.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/view/login/signup_view.dart';
import 'package:flutter/material.dart';

import '../../common/app_colors.dart';

/// How many intro pages there are. Also used to precache their pictures from
/// the screen before this one - see [precacheOnBoardingImages].
const int kOnBoardingPageCount = 4;

String _onBoardingImage(int page) => 'assets/img/on_$page.png';

/// Decodes the intro pictures ahead of time.
///
/// `Image.asset` decodes on first paint, off the UI thread, and paints nothing
/// until that finishes. On the intro that meant each picture popped in part way
/// through its page sliding across - which reads as a stutter even though no
/// frame was dropped. Called from the screen *before* the intro, so the first
/// page is ready by the time the route transition shows it.
void precacheOnBoardingImages(BuildContext context) {
  for (var i = 1; i <= kOnBoardingPageCount; i++) {
    precacheImage(AssetImage(_onBoardingImage(i)), context);
  }
}

class OnBoardingView extends StatefulWidget {
  const OnBoardingView({super.key});

  @override
  State<OnBoardingView> createState() => _OnBoardingViewState();
}

class _OnBoardingViewState extends State<OnBoardingView> {
  final PageController controller = PageController();

  /// The page the user is on, or heading to. Not state: nothing is rebuilt
  /// from it - the progress ring reads the controller directly.
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Harmless if the previous screen already did it; needed when this one is
    // reached some other way.
    precacheOnBoardingImages(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Read on every build rather than held in a field: the language can change
  // while the app is running, and a `List` built once in initState would keep
  // showing whichever language happened to be active then.
  List<Map<String, String>> get pageArr => [
        for (var i = 1; i <= kOnBoardingPageCount; i++)
          {
            "title": tr('title_onboarding_$i'),
            "subtitle": tr('desc_onboarding_$i'),
            "image": _onBoardingImage(i),
          },
      ];

  void _next() {
    if (_page < kOnBoardingPageCount - 1) {
      _page += 1;
      // An ease, not the kit's bounceInOut: a bounce curve overshoots and
      // comes back several times, so the page visibly shook back and forth on
      // its way across.
      controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignUpView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = pageArr;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Stack(
        alignment: Alignment.bottomRight,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: pages.length,
            onPageChanged: (index) => _page = index,
            // Each page is a still picture and two lines of text. Its own
            // layer means sliding it only moves an already-drawn texture
            // instead of repainting the page on every frame of the swipe.
            itemBuilder: (context, index) =>
                RepaintBoundary(child: OnBoardingPage(pObj: pages[index])),
          ),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Follows the swipe itself rather than jumping a quarter at a
                // time. This used to be a setState on every scroll tick, which
                // rebuilt the whole screen - both pages included - sixty times
                // a second while the user dragged, just to move this ring.
                SizedBox(
                  width: 70,
                  height: 70,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final page = controller.hasClients &&
                              controller.position.haveDimensions
                          ? controller.page ?? 0
                          : 0.0;
                      return CircularProgressIndicator(
                        color: context.colors.primary1,
                        value: (page + 1) / kOnBoardingPageCount,
                        strokeWidth: 2,
                      );
                    },
                  ),
                ),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: context.colors.primary1,
                      borderRadius: BorderRadius.circular(35)),
                  child: IconButton(
                    icon: Icon(
                      Icons.navigate_next,
                      color: context.colors.surface,
                    ),
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
