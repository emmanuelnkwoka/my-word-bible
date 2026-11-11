import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/section_heading.dart';
import '../../bible/application/bible_providers.dart';
import '../../settings/application/appearance_controller.dart';
import '../application/profile_controllers.dart';
import 'sign_in_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final appearance = ref.watch(appearanceProvider);
    final reading = ref.watch(readingPreferencesProvider);
    final daily = ref.watch(dailyExperienceProvider);
    final version = ref.watch(activeVersionProvider);
    final session = ref.watch(sessionProvider).value;
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final storedName = profile?.firstName.trim() ?? '';
    final name = storedName.isEmpty ? 'Friend' : storedName;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: MwbLayout.pagePadding(context, top: MwbSpace.lg, bottom: MwbSpace.xxxl),
          children: [
            const MwbPageTitle(overline: 'Your space', title: 'Profile'),
            const SizedBox(height: MwbSpace.lg),
            MwbCard(
              padding: const EdgeInsets.all(MwbSpace.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: 'Profile image placeholder',
                        child: MwbAvatar(initials: name.substring(0, 1).toUpperCase(), size: 64),
                      ),
                      const SizedBox(width: MwbSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: t.sectionHeading.copyWith(fontSize: 26)),
                            const SizedBox(height: 2),
                            Text(
                              session?.isSignedIn ?? false ? session!.email ?? '' : 'Guest · saved on this device',
                              style: t.caption,
                            ),
                          ],
                        ),
                      ),
                      MwbIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit personal information',
                        onPressed: () => context.push(AppRoutes.personalInfo),
                      ),
                    ],
                  ),
                  if (!(session?.isSignedIn ?? false)) ...[
                    const SizedBox(height: MwbSpace.md),
                    MwbSecondaryButton(
                      label: 'Sign in or create account',
                      icon: Icons.login_rounded,
                      onPressed: () => showSignInSheet(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MwbSpace.xl),
            _Group(
              title: 'Preferences',
              tiles: [
                _Tile(
                  Icons.palette_outlined,
                  'Theme & appearance',
                  '${appearance.themeId.label} · ${appearance.mode.label}',
                  AppRoutes.appearance,
                ),
                _Tile(
                  Icons.text_fields_rounded,
                  'Reading preferences',
                  '${version.abbreviation} · ${reading.textSize.label} text',
                  AppRoutes.readingSettings,
                ),
                _Tile(
                  Icons.notifications_none_rounded,
                  'Notifications',
                  daily.reminderEnabled ? 'Daily reminder on' : 'Daily reminder off',
                  AppRoutes.notifications,
                ),
                _Tile(
                  Icons.tune_rounded,
                  'Content preferences',
                  'Interests and discovery',
                  AppRoutes.contentPreferences,
                ),
              ],
            ),
            _Group(
              title: 'Your content',
              tiles: [
                _Tile(
                  Icons.bookmarks_outlined,
                  'Saved content',
                  'Scripture, messages and collections',
                  AppRoutes.library,
                  switchTab: true,
                ),
                _Tile(
                  Icons.add_circle_outline_rounded,
                  'Share a message',
                  'Prepare a short video or audio excerpt',
                  AppRoutes.upload,
                ),
              ],
            ),
            _Group(
              title: 'Account',
              tiles: [
                _Tile(
                  Icons.person_outline_rounded,
                  'Personal information',
                  'Name and gender preference',
                  AppRoutes.personalInfo,
                ),
                _Tile(Icons.manage_accounts_outlined, 'Account settings', 'Sign-in and session', AppRoutes.account),
                _Tile(Icons.shield_outlined, 'Privacy & data', 'What is stored and how to clear it', AppRoutes.privacy),
              ],
            ),
            _Group(
              title: 'Support',
              tiles: [
                _Tile(Icons.help_outline_rounded, 'Help & support', 'Answers to common questions', AppRoutes.help),
                _Tile(
                  Icons.info_outline_rounded,
                  'About My Word Bible',
                  'Mission, version and licences',
                  AppRoutes.about,
                ),
              ],
            ),
            const SizedBox(height: MwbSpace.md),
            Center(
              child: Text('My Word Bible · Foundation V1', style: t.caption.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.icon, this.title, this.subtitle, this.route, {this.switchTab = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool switchTab;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.tiles});
  final String title;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: MwbSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: MwbSpace.xs),
            child: Text(title.toUpperCase(), style: t.overline.copyWith(color: c.textSecondary)),
          ),
          MwbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 56, color: c.divider),
                  ListTile(
                    leading: Icon(tiles[i].icon, color: c.primary),
                    title: Text(tiles[i].title, style: t.label.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
                    subtitle: Text(tiles[i].subtitle, style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                    onTap: () => tiles[i].switchTab ? context.go(tiles[i].route) : context.push(tiles[i].route),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-export for settings screens that show the same honest note.
const accountsNotice = MwbNotice(
  icon: Icons.cloud_off_outlined,
  message:
      'MWB accounts and sync are not available yet. Your profile, preferences and library are stored '
      'securely on this device and will be transferable once accounts launch.',
);
