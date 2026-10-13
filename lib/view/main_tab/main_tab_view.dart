import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/fade_indexed_stack.dart';
import 'package:bodify/common_widget/tab_button.dart';
import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/refresh_flags.dart';
import '../ai_coach/ai_coach_view.dart';
import '../exercise/catalog_explorer_view.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';
import '../tracker/tracker_view.dart';

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int selectTab = 0;

  // Built once and kept alive for the life of this screen, rather than a
  // fresh `HomeView()` / `TrackerView()` swapped in on every tap. The old
  // approach destroyed and recreated the whole subtree on every switch, so
  // each tab's initState() re-ran and every one of its network calls fired
  // again - the lag was every screen paying its full load cost on every
  // visit, not just the first. IndexedStack keeps all four mounted and just
  // toggles which one paints, so state (and the data already fetched) survive
  // a round trip through the other tabs.
  final _homeKey = GlobalKey<HomeViewState>();
  final _profileKey = GlobalKey<ProfileViewState>();
  late final List<Widget> _tabs = [
    HomeView(key: _homeKey),
    const TrackerView(),
    const AiCoachView(),
    ProfileView(key: _profileKey),
  ];

  static const _centerWidth = 80.0;

  Future<void> _openExplorer() async {
    // Keep the returned destination inside its existing tab and mounted state.
    final tab = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => const CatalogExplorerView()),
    );
    if (tab == null || !mounted) return;
    setState(() => selectTab = tab);
  }

  void _selectHome() {
    if (RefreshFlags.homeActivity) {
      RefreshFlags.homeActivity = false;
      _homeKey.currentState?.refreshActivity();
    }
    if (RefreshFlags.homeProfile) {
      RefreshFlags.homeProfile = false;
      _homeKey.currentState?.refreshProfile();
    }
    // Health readings change without a network refresh flag.
    _homeKey.currentState?.refreshHealth();
    setState(() => selectTab = 0);
  }

  void _selectProfile() {
    if (RefreshFlags.profileAchievements) {
      RefreshFlags.profileAchievements = false;
      _profileKey.currentState?.refresh();
    }
    setState(() => selectTab = 3);
  }

  double _navigationHeight(List<String> labels, String exploreLabel) {
    final media = MediaQuery.of(context);
    final tabLabelWidth =
        (media.size.width - media.padding.horizontal - 16 - _centerWidth) / 4 -
            8;
    final style = TabButton.labelStyle(context);
    var labelHeight = 0.0;
    for (var index = 0; index <= labels.length; index++) {
      final painter = TextPainter(
        text: TextSpan(
          text: index == labels.length ? exploreLabel : labels[index],
          style: style,
        ),
        textDirection: Directionality.of(context),
        textScaler: TabButton.labelTextScaler(context),
      )..layout(
          maxWidth: index == labels.length ? _centerWidth - 8 : tabLabelWidth,
        );
      if (painter.height > labelHeight) labelHeight = painter.height;
      painter.dispose();
    }
    // Labels start 38 dp below the bar's top, just below the search button.
    // Keep the ordinary 56 dp bar, then grow it for translated/scaled text.
    final required = (38 + labelHeight + 5).ceilToDouble();
    return required > kToolbarHeight ? required : kToolbarHeight;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labels = [
      tr('nav_home'),
      tr('nav_tracker'),
      tr('nav_ai_coach'),
      tr('title_profile'),
    ];
    final exploreLabel = tr('nav_explore');
    final navigationHeight = _navigationHeight(labels, exploreLabel);

    return Scaffold(
      backgroundColor: colors.surface,
      body: FadeIndexedStack(index: selectTab, children: _tabs),
      floatingActionButtonLocation: _PinnedCenterDocked(navigationHeight),
      floatingActionButton: Semantics(
        label: exploreLabel,
        button: true,
        onTap: _openExplorer,
        child: ExcludeSemantics(
          child: Tooltip(
            message: exploreLabel,
            excludeFromSemantics: true,
            child: SizedBox(
              width: 70,
              height: 70,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors.primaryGradient),
                    ),
                    child: InkWell(
                      onTap: _openExplorer,
                      customBorder: const CircleBorder(),
                      child:
                          Icon(Icons.search, color: colors.onPrimary, size: 30),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        // BottomAppBar's own height stops at kToolbarHeight, which leaves a
        // gap between the bar and the true bottom edge on any phone with a
        // home-indicator inset (or, on Android, the gesture-nav strip) - the
        // background colour behind that gap is whatever the page underneath
        // is, so the bar reads as a plain rectangle floating short of the
        // device's rounded corners instead of one that actually reaches them.
        // Painting the surface colour on a plain Container first and only
        // then reserving the inset (via SafeArea) for the tappable row keeps
        // the colour flush with the physical edge while the icons still sit
        // above the unsafe zone.
        decoration: BoxDecoration(color: colors.surface, boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))
        ]),
        child: SafeArea(
          top: false,
          child: Material(
            color: colors.surface,
            child: SizedBox(
              height: navigationHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TabButton(
                        icon: 'assets/img/home_tab.png',
                        selectIcon: 'assets/img/home_tab_select.png',
                        label: labels[0],
                        isActive: selectTab == 0,
                        onTap: _selectHome,
                      ),
                    ),
                    Expanded(
                      child: TabButton(
                        icon: 'assets/img/activity_tab.png',
                        selectIcon: 'assets/img/activity_tab_select.png',
                        label: labels[1],
                        isActive: selectTab == 1,
                        onTap: () => setState(() => selectTab = 1),
                      ),
                    ),
                    SizedBox(
                      width: _centerWidth,
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: _openExplorer,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 38, 0, 5),
                              child: Text(
                                exploreLabel,
                                textAlign: TextAlign.center,
                                textScaler: TabButton.labelTextScaler(context),
                                style: TabButton.labelStyle(context)
                                    .copyWith(color: colors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabButton(
                        iconData: Icons.auto_awesome,
                        label: labels[2],
                        isActive: selectTab == 2,
                        onTap: () => setState(() => selectTab = 2),
                      ),
                    ),
                    Expanded(
                      child: TabButton(
                        icon: 'assets/img/profile_tab.png',
                        selectIcon: 'assets/img/profile_tab_select.png',
                        label: labels[3],
                        isActive: selectTab == 3,
                        onTap: _selectProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The search button, docked on the bottom bar and never anywhere else.
///
/// Flutter's `centerDocked` places the button on the top edge of the page
/// content, and that edge moves: a SnackBar ("Meal deleted") lifts it, and so
/// does the keyboard on the AI Coach tab, so the button jumped up and back
/// down under the user's thumb. This measures from the bottom of the screen
/// instead - the bar is its measured height above the device's own inset
/// (`minViewPadding`, which the keyboard does not change) - so nothing that
/// happens above the bar can move it.
class _PinnedCenterDocked extends FloatingActionButtonLocation {
  final double navigationHeight;

  const _PinnedCenterDocked(this.navigationHeight);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final fab = geometry.floatingActionButtonSize;
    final barTop = geometry.scaffoldSize.height -
        geometry.minViewPadding.bottom -
        navigationHeight;
    return Offset(
      (geometry.scaffoldSize.width - fab.width) / 2,
      barTop - fab.height / 2,
    );
  }
}
