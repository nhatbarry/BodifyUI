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
  ProfileViewState createState() => ProfileViewState();
}

/// Public so [MainTabView] can call [refresh] when the Profile tab is tapped.
/// The achievement strip and recent-exercises section both already exposed a
/// public `reload()` for exactly this, but nothing ever called it - the tab
/// switch used to tear this whole screen down and rebuild it on every visit,
/// which reloaded everything by accident. Now that switching tabs keeps this
/// screen alive, something has to ask these two for fresh numbers instead.
class ProfileViewState extends State<ProfileView> {
  final _achievementsKey = GlobalKey<AchievementStripState>();
  final _recentExercisesKey = GlobalKey<RecentExercisesSectionState>();

  Profile? _profile;

  void refresh() {
    _loadProfile();
    _achievementsKey.currentState?.reload();
    _recentExercisesKey.currentState?.reload();
  }

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
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            tooltip: tr('btn_open_settings'),
            icon: Icon(Icons.settings_outlined,
                color: context.colors.textPrimary),
          ),
        ],
      ),
      backgroundColor: context.colors.surface,
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _profileHeader(),
              const SizedBox(height: 20),
              _profileStats(),
              const SizedBox(height: 26),
              // The badges and the history both belong to the person, not to
              // the settings: this is the screen about who you are and what
              // you have done.
              AchievementStrip(key: _achievementsKey),
              const SizedBox(height: 22),
              RecentExercisesSection(key: _recentExercisesKey),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final colors = context.colors;
    final type = Theme.of(context).textTheme;
    final identity = Row(
      children: [
        // Preserve the editor's avatar cache identity so a new upload refreshes.
        ClipOval(
          child: SizedBox(
            width: 50,
            height: 50,
            child: _profile?.avatarUrl == null
                ? Image.asset('assets/img/u2.png', fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: _profile!.avatarUrl!,
                    cacheKey:
                        'avatar-${_profile!.userId}-${_profile!.updatedAt.toIso8601String()}',
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: colors.surfaceVariant),
                    errorWidget: (_, __, ___) =>
                        Image.asset('assets/img/u2.png', fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ValueListenableBuilder<CurrentUser?>(
            valueListenable: AuthService.instance.currentUser,
            builder: (context, user, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? tr('label_bodify_user'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.user.email ?? tr('error_not_signed_in'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final edit = ConstrainedBox(
      constraints:
          const BoxConstraints(minWidth: 88, maxWidth: 120, minHeight: 48),
      child: RoundButton(
        title: tr('btn_edit_profile'),
        type: RoundButtonType.bgGradient,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        onPressed: _openPersonalData,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 18.2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 16), edit],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 16),
            edit,
          ],
        );
      },
    );
  }

  Widget _profileStats() {
    // The values still come from GET /profile. Age's label already supplies
    // its context; repeating 'years old' made the third tile unnecessarily tall.
    final cells = [
      TitleSubtitleCell(
        title: _profile?.heightCm == null
            ? '–'
            : '${_num(_profile!.heightCm!)} cm',
        subtitle: tr('label_height'),
      ),
      TitleSubtitleCell(
        title: _profile?.weightKg == null
            ? '–'
            : '${_num(_profile!.weightKg!)} kg',
        subtitle: tr('label_weight_short'),
      ),
      TitleSubtitleCell(
        title: _profile?.age?.toString() ?? '–',
        subtitle: tr('label_age'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        const gap = 12.0;
        final columns = ((constraints.maxWidth + gap) / (120 * scale + gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cell in cells) SizedBox(width: width, child: cell)
          ],
        );
      },
    );
  }
}
