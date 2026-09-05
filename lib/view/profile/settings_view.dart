import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/setting_row.dart';
import '../../core/app_locale.dart';
import '../../core/app_strings.dart';
import '../../core/theme_controller.dart';
import '../../services/auth_service.dart';
import '../on_boarding/started_view.dart';
import 'account_security_view.dart';
import 'achievements_view.dart';
import 'personal_data_view.dart';
import 'progress_view.dart';

/// Everything that used to sit directly on the Profile screen - Account,
/// Notification, Other - moved one level deeper.
///
/// The Profile screen kept growing sections that are configuration, not
/// identity: language, theme, logout have nothing to do with looking at your
/// own name and stats. Pulling them into one settings screen leaves Profile
/// free for what is actually about the profile (avatar, stats, and whatever
/// Achievement/Activity History/Workout Progress become).
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Local only - the kit never wired this to a backend, and that has not
  // changed here.
  bool _popupNotification = false;

  // Getters, not fields: `tr` reads the live language, so a list built once at
  // construction would keep whichever language was active then.
  List<Map<String, String>> get _accountRows => [
        {
          "image": "assets/img/p_personal.png",
          "name": tr('title_personal_data'),
          "tag": "personal_data"
        },
        {
          "image": "assets/img/p_privacy.png",
          "name": tr('title_account_security'),
          "tag": "account_security"
        },
        {
          "image": "assets/img/p_achi.png",
          "name": tr('label_achievement'),
          "tag": "achievement"
        },
        {
          "image": "assets/img/p_activity.png",
          "name": tr('label_activity_history'),
          "tag": "activity_history"
        },
        {
          "image": "assets/img/p_workout.png",
          "name": tr('label_workout_progress'),
          "tag": "workout_progress"
        },
      ];

  List<Map<String, String>> get _otherRows => [
        {
          "image": "assets/img/p_contact.png",
          "name": tr('label_contact_us'),
          "tag": "contact"
        },
        {
          "image": "assets/img/p_privacy.png",
          "name": tr('label_privacy_policy'),
          "tag": "privacy"
        },
        {
          "image": "assets/img/p_setting.png",
          "name": "__language__",
          "tag": "language"
        },
        {
          "image": "assets/img/p_setting.png",
          "name": "__appearance__",
          "tag": "appearance"
        },
        {
          "image": "assets/img/p_setting.png",
          "name": tr('btn_logout'),
          "tag": "logout"
        },
      ];

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Future<void> _pickLanguage() async {
    final chosen = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('label_language')),
        children: [
          for (final language in AppLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, language),
              child: Row(
                children: [
                  Expanded(
                    child: Text(language.label,
                        style: TextStyle(
                            color: context.colors.textPrimary, fontSize: 14)),
                  ),
                  if (LocaleController.instance.language == language)
                    Icon(Icons.check, color: context.colors.primary1, size: 18),
                ],
              ),
            ),
        ],
      ),
    );

    if (chosen != null) {
      // Switching also changes the language the exercise API is queried with.
      await LocaleController.instance.setLanguage(chosen);
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickTheme() async {
    const options = {
      ThemeMode.light: 'label_theme_light',
      ThemeMode.dark: 'label_theme_dark',
      ThemeMode.system: 'label_theme_system',
    };

    final chosen = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('label_appearance')),
        children: [
          for (final entry in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr(entry.value),
                        style: TextStyle(
                            color: context.colors.textPrimary, fontSize: 14)),
                  ),
                  if (ThemeController.instance.mode == entry.key)
                    Icon(Icons.check, color: context.colors.primary1, size: 18),
                ],
              ),
            ),
        ],
      ),
    );

    if (chosen != null) {
      await ThemeController.instance.setMode(chosen);
      if (mounted) setState(() {});
    }
  }

  String get _themeLabel {
    switch (ThemeController.instance.mode) {
      case ThemeMode.light:
        return tr('label_theme_light');
      case ThemeMode.dark:
        return tr('label_theme_dark');
      case ThemeMode.system:
        return tr('label_theme_system');
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('btn_logout')),
        content: Text(tr('msg_logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('btn_cancel'),
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('btn_logout'),
                style: TextStyle(color: context.colors.primary1)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const StartedView()),
      (route) => false,
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        title: Text(
          tr('label_setting'),
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionCard(
                title: tr('title_account_section'),
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _accountRows.length,
                  itemBuilder: (context, index) {
                    final row = _accountRows[index];

                    // Achievement and Activity History are still stubs; the
                    // two that are built route to their screens.
                    final destinations = <String, Widget>{
                      'personal_data': const PersonalDataView(),
                      'account_security': const AccountSecurityView(),
                      'workout_progress': const ProgressView(),
                      'achievement': const AchievementsView(),
                    };
                    final destination = destinations[row["tag"]];

                    return SettingRow(
                      icon: row["image"]!,
                      title: row["name"]!,
                      onPressed: destination == null
                          ? () {}
                          : () => _open(destination),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              _sectionCard(
                title: tr('title_notification_section'),
                child: SizedBox(
                  height: 30,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset("assets/img/p_notification.png",
                          height: 15, width: 15, fit: BoxFit.contain),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          tr('label_popup_notification'),
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      CustomAnimatedToggleSwitch<bool>(
                        current: _popupNotification,
                        values: const [false, true],
                        dif: 0.0,
                        indicatorSize: const Size.square(30.0),
                        animationDuration: const Duration(milliseconds: 200),
                        animationCurve: Curves.linear,
                        onChanged: (b) =>
                            setState(() => _popupNotification = b),
                        iconBuilder: (context, local, global) =>
                            const SizedBox(),
                        defaultCursor: SystemMouseCursors.click,
                        onTap: () => setState(
                            () => _popupNotification = !_popupNotification),
                        iconsTappable: false,
                        wrapperBuilder: (context, global, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 10.0,
                                right: 10.0,
                                height: 30.0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        colors:
                                            context.colors.secondaryGradient),
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(50.0)),
                                  ),
                                ),
                              ),
                              child,
                            ],
                          );
                        },
                        foregroundIndicatorBuilder: (context, global) {
                          return SizedBox.fromSize(
                            size: const Size(10, 10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(50.0)),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38,
                                      spreadRadius: 0.05,
                                      blurRadius: 1.1,
                                      offset: Offset(0.0, 0.8))
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _sectionCard(
                title: tr('title_other_section'),
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _otherRows.length,
                  itemBuilder: (context, index) {
                    final row = _otherRows[index];
                    final tag = row["tag"];

                    String title;
                    VoidCallback onPressed;
                    switch (tag) {
                      case "language":
                        title =
                            "${tr('label_language')} · ${LocaleController.instance.language.label}";
                        onPressed = _pickLanguage;
                        break;
                      case "appearance":
                        title = "${tr('label_appearance')} · $_themeLabel";
                        onPressed = _pickTheme;
                        break;
                      case "logout":
                        title = tr('btn_logout');
                        onPressed = _confirmLogout;
                        break;
                      default:
                        title = row["name"]!;
                        onPressed = () {};
                    }

                    return SettingRow(
                      icon: row["image"]!,
                      title: title,
                      onPressed: onPressed,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
