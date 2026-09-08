import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/tab_button.dart';
import 'package:flutter/material.dart';

import '../../core/refresh_flags.dart';
import '../ai_coach/ai_coach_view.dart';
import '../exercise/exercise_explorer_view.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: IndexedStack(index: selectTab, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: InkWell(
          onTap: () async {
            // The explorer can ask to be closed onto a tab - "you have no
            // schedule yet, go make one". Returning the tab index rather than
            // pushing ScheduleListView itself keeps that screen inside the
            // Tracker tab it belongs to, chrome and all - and since Tracker
            // is already alive in the stack, it reappears exactly as the user
            // left it rather than as a fresh instance.
            final tab = await Navigator.push<int>(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExerciseExplorerView()),
            );
            if (tab == null || !context.mounted) return;
            setState(() => selectTab = tab);
          },
          child: Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.colors.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,)
                ]),
            child: Icon(Icons.search,color: context.colors.surface, size: 35, ),
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
        decoration: BoxDecoration(color: context.colors.surface, boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, -2))
        ]),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
            TabButton(
                icon: "assets/img/home_tab.png",
                selectIcon: "assets/img/home_tab_select.png",
                isActive: selectTab == 0,
                onTap: () {
                  // Home no longer rebuilds on every visit, so it needs to be
                  // told when something it shows changed elsewhere - only
                  // then, not on every idle tap between tabs.
                  if (RefreshFlags.homeActivity) {
                    RefreshFlags.homeActivity = false;
                    _homeKey.currentState?.refreshActivity();
                  }
                  if (RefreshFlags.homeProfile) {
                    RefreshFlags.homeProfile = false;
                    _homeKey.currentState?.refreshProfile();
                  }
                  setState(() => selectTab = 0);
                }),
            TabButton(
                icon: "assets/img/activity_tab.png",
                selectIcon: "assets/img/activity_tab_select.png",
                isActive: selectTab == 1,
                onTap: () => setState(() => selectTab = 1)),

              const  SizedBox(width: 40,),
            TabButton(
                // The kit ships no AI-coach artwork, so this tab uses a
                // Material icon instead of the asset pair.
                iconData: Icons.auto_awesome,
                isActive: selectTab == 2,
                onTap: () => setState(() => selectTab = 2)),
            TabButton(
                icon: "assets/img/profile_tab.png",
                selectIcon: "assets/img/profile_tab_select.png",
                isActive: selectTab == 3,
                onTap: () {
                  // Same reasoning as Home: only reload when a finish since
                  // the last visit could actually have changed something.
                  // Profile's own header refreshes itself on its own
                  // push/pop path, so it needs no entry here.
                  if (RefreshFlags.profileAchievements) {
                    RefreshFlags.profileAchievements = false;
                    _profileKey.currentState?.refresh();
                  }
                  setState(() => selectTab = 3);
                })
              ],
            ),
          ),
        ),
      ),
    );
  }
}
