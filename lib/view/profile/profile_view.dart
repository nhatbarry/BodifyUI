import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/achievement_strip.dart';
import '../../common_widget/recent_exercises_section.dart';
import '../../common_widget/round_button.dart';
import '../../common_widget/title_subtitle_cell.dart';
import '../../core/app_strings.dart';
import '../../models/auth_models.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import 'personal_data_view.dart';
import 'settings_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.get();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // The rest of the screen works without the stat row.
    }
  }

  /// Drops a trailing .0 so 175.0 reads as 175.
  static String _num(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  /// Account, Notification and Other all live on the settings screen now.
  ///
  /// They are configuration, not identity: language, theme and logout have
  /// nothing to do with looking at your own name and stats, and keeping them
  /// here left no room for what the profile is actually about.
  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsView()),
    );
    // Personal Data is reachable from in there, so the header and stats may
    // be stale by the time we come back.
    if (mounted) _loadProfile();
  }

  Future<void> _openPersonalData() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PersonalDataView()),
    );
    // The header reads from the cached user, which PUT /profile refreshes;
    // the stat row needs the profile re-fetched.
    if (mounted) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        centerTitle: true,
        elevation: 0,
        leadingWidth: 0,
        title: Text(
          tr('title_profile'),
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          InkWell(
            onTap: _openSettings,
            child: Container(
              margin: const EdgeInsets.all(8),
              height: 40,
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10)),
              child: Image.asset(
                "assets/img/p_setting.png",
                width: 16,
                height: 16,
                fit: BoxFit.contain,
                color: context.colors.textPrimary,
              ),
            ),
          )
        ],
      ),
      backgroundColor: context.colors.surface,
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // The kit's stock portrait, until the user uploads one of
                  // their own. Same cache key as the editor, keyed on
                  // updated_at so a new upload is not served from the old one.
                  ClipOval(
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: _profile?.avatarUrl == null
                          ? Image.asset("assets/img/u2.png", fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: _profile!.avatarUrl!,
                              cacheKey:
                                  'avatar-${_profile!.userId}-${_profile!.updatedAt.toIso8601String()}',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  color: context.colors.surfaceVariant),
                              errorWidget: (_, __, ___) => Image.asset(
                                  "assets/img/u2.png",
                                  fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: ValueListenableBuilder<CurrentUser?>(
                      valueListenable: AuthService.instance.currentUser,
                      builder: (context, user, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? tr('label_bodify_user'),
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              user?.user.email ?? tr('error_not_signed_in'),
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    height: 25,
                    child: RoundButton(
                      title: tr('btn_edit_profile'),
                      type: RoundButtonType.bgGradient,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      onPressed: _openPersonalData,
                    ),
                  )
                ],
              ),
              const SizedBox(
                height: 15,
              ),
              Row(
                children: [
                  Expanded(
                    child: TitleSubtitleCell(
                      // Height and weight come from the latest body metric,
                      // age from the birth date - all via GET /profile.
                      title: _profile?.heightCm == null
                          ? "--"
                          : "${_num(_profile!.heightCm!)}cm",
                      subtitle: tr('label_height'),
                    ),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: TitleSubtitleCell(
                      title: _profile?.weightKg == null
                          ? "--"
                          : "${_num(_profile!.weightKg!)}kg",
                      subtitle: tr('label_weight_short'),
                    ),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: TitleSubtitleCell(
                      title: _profile?.age == null
                          ? "--"
                          : "${_profile!.age}yo",
                      subtitle: tr('label_age'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              // The badges and the history both belong to the person, not to
              // the settings: this is the screen about who you are and what
              // you have done.
              const AchievementStrip(),
              const SizedBox(height: 22),
              const RecentExercisesSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
