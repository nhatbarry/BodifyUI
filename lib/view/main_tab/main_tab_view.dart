import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/tab_button.dart';
import 'package:flutter/material.dart';

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
  final PageStorageBucket pageBucket = PageStorageBucket(); 
  Widget currentTab = const HomeView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: PageStorage(bucket: pageBucket, child: currentTab),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: InkWell(
          onTap: () async {
            // The explorer can ask to be closed onto a tab - "you have no
            // schedule yet, go make one". Returning the tab index rather than
            // pushing ScheduleListView itself keeps that screen inside the
            // Tracker tab it belongs to, chrome and all.
            final tab = await Navigator.push<int>(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExerciseExplorerView()),
            );
            if (tab == null || !context.mounted) return;
            setState(() {
              selectTab = tab;
              currentTab = const TrackerView();
            });
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
      bottomNavigationBar: BottomAppBar(
          child: Container(
        decoration: BoxDecoration(color: context.colors.surface, boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, -2))
        ]),
        height: kToolbarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TabButton(
                icon: "assets/img/home_tab.png",
                selectIcon: "assets/img/home_tab_select.png",
                isActive: selectTab == 0,
                onTap: () {
                  selectTab = 0;
                  currentTab = const HomeView();
                  if (mounted) {
                    setState(() {});
                  }
                }),
            TabButton(
                icon: "assets/img/activity_tab.png",
                selectIcon: "assets/img/activity_tab_select.png",
                isActive: selectTab == 1,
                onTap: () {
                  selectTab = 1;
                  currentTab = const TrackerView();
                  if (mounted) {
                    setState(() {});
                  }
                }),

              const  SizedBox(width: 40,),
            TabButton(
                // The kit ships no AI-coach artwork, so this tab uses a
                // Material icon instead of the asset pair.
                iconData: Icons.auto_awesome,
                isActive: selectTab == 2,
                onTap: () {
                  selectTab = 2;
                   currentTab = const AiCoachView();
                  if (mounted) {
                    setState(() {});
                  }
                }),
            TabButton(
                icon: "assets/img/profile_tab.png",
                selectIcon: "assets/img/profile_tab_select.png",
                isActive: selectTab == 3,
                onTap: () {
                  selectTab = 3;
                   currentTab = const ProfileView();
                  if (mounted) {
                    setState(() {});
                  }
                })
          ],
        ),
      )),
    );
  }
}
