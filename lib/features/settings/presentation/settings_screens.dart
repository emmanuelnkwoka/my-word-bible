import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_themes.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/segmented.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/theme_selector.dart';
import '../../../data/models/content.dart';
import '../../../data/models/interest.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../bible/widgets/version_picker.dart';
import '../../personalisation/presentation/mwb_review_widgets.dart';
import '../../library/application/library_controllers.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../profile/application/profile_controllers.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/sign_in_sheet.dart';
import '../application/appearance_controller.dart';

/// Shared scaffold for settings pages.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children, this.bottom});

  final String title;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
        children: [
          Semantics(header: true, child: Text(title, style: t.pageHeading)),
          const SizedBox(height: MwbSpace.lg),
          ...children,
        ],
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: MwbConstrained(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MwbSpace.lg, bottom: MwbSpace.xs),
    child: Text(text.toUpperCase(), style: context.mwb.text.overline.copyWith(color: context.mwb.colors.textSecondary)),
  );
}

// ── Personal information ────────────────────────────────────────────────

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late final TextEditingController _name;
  late GenderPreference _gender;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final p = ref.read(userProfileProvider);
    _name = TextEditingController(text: p?.firstName ?? '');
    _gender = p?.gender ?? GenderPreference.preferNotToSay;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final existing = ref.read(userProfileProvider);
    final name = _name.text.trim();
    await ref
        .read(userProfileProvider.notifier)
        .save(existing?.copyWith(firstName: name, gender: _gender) ?? UserProfile(firstName: name, gender: _gender));
    if (!mounted) return;
    showMwbSnack(context, 'Personal information saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Personal information',
      bottom: MwbPrimaryButton(label: 'Save changes', onPressed: _save),
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _name,
            validator: OnboardingValidation.firstName,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'First name', counterText: ''),
          ),
        ),
        const _Label('Gender'),
        MwbRadioGroup<GenderPreference>(
          options: GenderPreference.values,
          value: _gender,
          labelOf: (g) => g.label,
          dense: true,
          onChanged: (g) => setState(() => _gender = g),
        ),
        const SizedBox(height: MwbSpace.md),
        const MwbNotice(
          message:
              'Your name is used for greetings and personal framing around Scripture. '
              'Neither your name nor your gender ever changes the words of a Bible translation.',
        ),
      ],
    );
  }
}

// ── Appearance ──────────────────────────────────────────────────────────

class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  MwbThemeId? _preview;

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final ctrl = ref.read(appearanceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final preview = _preview ?? appearance.themeId;
    final changed = preview != appearance.themeId;

    return SettingsPage(
      title: 'Theme & appearance',
      bottom: AnimatedSwitcher(
        duration: MwbMotion.fast,
        child: changed
            ? MwbPrimaryButton(
                key: const Key('appearance.apply'),
                label: 'Use ${preview.label}',
                onPressed: () async {
                  await ctrl.setTheme(preview);
                  setState(() => _preview = null);
                  if (context.mounted) showMwbSnack(context, '${preview.label} applied');
                },
              )
            : const SizedBox.shrink(),
      ),
      children: [
        const _Label('Appearance'),
        MwbSegmentedControl<AppearanceMode>(
          options: AppearanceMode.values,
          value: appearance.mode,
          onChanged: ctrl.setMode,
          labelOf: (m) => m.label,
          iconOf: (m) => switch (m) {
            AppearanceMode.system => Icons.brightness_auto_outlined,
            AppearanceMode.light => Icons.light_mode_outlined,
            AppearanceMode.dark => Icons.dark_mode_outlined,
          },
        ),
        const _Label('Preview'),
        _ThemePreview(themeId: preview, brightness: brightness),
        const _Label('Colour theme'),
        MwbThemeSelector(
          selected: preview,
          applied: appearance.themeId,
          brightness: brightness,
          onSelected: (id) => setState(() => _preview = id),
        ),
        const SizedBox(height: MwbSpace.sm),
        Text(preview.description, style: context.mwb.text.caption),
      ],
    );
  }
}

/// Renders sample UI with a theme's actual ThemeData before applying it.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.themeId, required this.brightness});
  final MwbThemeId themeId;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final data = AppThemeBuilder.build(themeId, brightness);
    return AnimatedTheme(
      data: data,
      duration: MwbMotion.medium,
      child: Builder(
        builder: (context) {
          final c = context.mwb.colors;
          final t = context.mwb.text;
          return Container(
            padding: const EdgeInsets.all(MwbSpace.md),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: MwbRadius.lgAll,
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOOD MORNING', style: t.overline),
                const SizedBox(height: 4),
                Text(themeId.label, style: t.pageHeading.copyWith(fontSize: 28)),
                const SizedBox(height: MwbSpace.sm),
                MwbCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('The LORD is my shepherd; I shall not want.', style: t.scripture),
                      const SizedBox(height: 6),
                      Text('PSALM 23:1 · KJV', style: t.scriptureReference),
                    ],
                  ),
                ),
                const SizedBox(height: MwbSpace.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const MwbChip(label: 'Faith', selected: true),
                    const MwbChip(label: 'Prayer'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: c.primaryStrong, borderRadius: MwbRadius.mdAll),
                      child: Text('Continue', style: t.button.copyWith(color: c.onPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Reading preferences ─────────────────────────────────────────────────

class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPreferencesProvider);
    final ctrl = ref.read(readingPreferencesProvider.notifier);
    final t = context.mwb.text;
    return SettingsPage(
      title: 'Reading preferences',
      children: [
        const _Label('Bible version'),
        BibleVersionPicker(
          catalogue: ref.watch(versionCatalogueProvider),
          selectedId: prefs.versionId,
          onSelected: (v) => ctrl.update((p) => p.copyWith(versionId: v.id)),
        ),
        const MwbReviewerModeTile(),
        const _Label('Text size'),
        MwbSegmentedControl<ReadingTextSize>(
          options: ReadingTextSize.values,
          value: prefs.textSize,
          onChanged: (s) => ctrl.update((p) => p.copyWith(textSize: s)),
          labelOf: (s) => s == ReadingTextSize.extraLarge ? 'XL' : s.label,
        ),
        const SizedBox(height: MwbSpace.sm),
        Text(
          'The LORD is my shepherd; I shall not want.',
          style: t.scripture.copyWith(fontSize: prefs.textSize.fontSize),
        ),
        Text('PSALM 23:1 · KJV · PREVIEW', style: t.scriptureReference.copyWith(fontSize: 11)),
        const _Label('Reading surface'),
        MwbSegmentedControl<ReadingSurface>(
          options: ReadingSurface.values,
          value: prefs.surface,
          onChanged: (s) => ctrl.update((p) => p.copyWith(surface: s)),
          labelOf: (s) => s.label,
        ),
        MwbSwitchTile(
          title: 'Show verse numbers',
          value: prefs.showVerseNumbers,
          onChanged: (v) => ctrl.update((p) => p.copyWith(showVerseNumbers: v)),
        ),
        const _Label('Daily reading goal'),
        MwbRadioGroup<DailyReadingGoal>(
          options: DailyReadingGoal.values,
          value: prefs.dailyGoal,
          labelOf: (g) => g.label,
          dense: true,
          onChanged: (g) => ctrl.update((p) => p.copyWith(dailyGoal: g)),
        ),
      ],
    );
  }
}

// ── Notifications ───────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref, bool on) async {
    final ctrl = ref.read(dailyExperienceProvider.notifier);
    if (!on) {
      await ctrl.update((d) => d.copyWith(reminderEnabled: false));
      return;
    }
    // Contextual permission request: only when the user turns it on.
    await ctrl.enableReminder();
    final canDeliver = ref.read(notificationServiceProvider).canDeliver;
    if (!canDeliver && context.mounted) {
      await showMwbInfoSheet(
        context,
        title: 'Reminder saved',
        icon: Icons.notifications_active_outlined,
        message:
            'Your daily Scripture reminder preference and time are saved. Notification delivery is '
            'being added in an upcoming update; MWB will ask for permission at that point.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(dailyExperienceProvider);
    final notif = ref.watch(notificationPreferencesProvider);
    final nCtrl = ref.read(notificationPreferencesProvider.notifier);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final canDeliver = ref.watch(notificationServiceProvider).canDeliver;

    return SettingsPage(
      title: 'Notifications',
      children: [
        if (!canDeliver)
          const MwbNotice(
            title: 'Preferences only for now',
            message:
                'These choices are saved on your device. Notifications will be delivered once the '
                'notification service is added in an upcoming update.',
          ),
        const _Label('Daily Scripture'),
        MwbSwitchTile(
          key: const Key('settings.reminder'),
          icon: Icons.notifications_none_rounded,
          title: 'Daily Scripture reminder',
          value: daily.reminderEnabled,
          onChanged: (v) => _toggleReminder(context, ref, v),
        ),
        if (daily.reminderEnabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_rounded, color: c.textSecondary),
            title: Text('Reminder time', style: t.label.copyWith(fontSize: 15)),
            trailing: Text(
              formatTimeOfDay(daily.reminderTime.hour, daily.reminderTime.minute),
              style: t.bodyStrong.copyWith(color: c.primary),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: daily.reminderTime.hour, minute: daily.reminderTime.minute),
              );
              if (picked != null) {
                await ref
                    .read(dailyExperienceProvider.notifier)
                    .update((d) => d.copyWith(reminderTime: ReminderTime(picked.hour, picked.minute)));
              }
            },
          ),
        const _Label('Updates'),
        MwbSwitchTile(
          icon: Icons.auto_awesome_outlined,
          title: 'New content in my interests',
          value: notif.newContentInInterests,
          onChanged: (v) => nCtrl.save(notif.copyWith(newContentInInterests: v)),
        ),
        MwbSwitchTile(
          icon: Icons.people_outline_rounded,
          title: 'Updates from creators',
          value: notif.creatorUpdates,
          onChanged: (v) => nCtrl.save(notif.copyWith(creatorUpdates: v)),
        ),
        MwbSwitchTile(
          icon: Icons.flag_outlined,
          title: 'Reading goal encouragement',
          value: notif.readingGoalNudges,
          onChanged: (v) => nCtrl.save(notif.copyWith(readingGoalNudges: v)),
        ),
      ],
    );
  }
}

// ── Content preferences ─────────────────────────────────────────────────

class ContentPreferencesScreen extends ConsumerWidget {
  const ContentPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(interestsProvider);
    final reading = ref.watch(readingPreferencesProvider);
    final daily = ref.watch(dailyExperienceProvider);
    final dCtrl = ref.read(dailyExperienceProvider.notifier);
    return SettingsPage(
      title: 'Content preferences',
      children: [
        const _Label('Spiritual interests'),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final i in spiritualInterests)
              MwbChip(
                label: i.label,
                selected: interests.contains(i.id),
                onTap: () => ref.read(interestsProvider.notifier).toggle(i.id),
              ),
          ],
        ),
        const _Label('Preferred content'),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final type in const [ContentType.scriptureReference, ContentType.audio, ContentType.video])
              MwbChip(
                label: type.label,
                selected: reading.preferredContentTypes.contains(type),
                onTap: () {
                  final next = {...reading.preferredContentTypes};
                  if (next.contains(type)) {
                    if (next.length == 1) {
                      showMwbSnack(context, 'Keep at least one type of content');
                      return;
                    }
                    next.remove(type);
                  } else {
                    next.add(type);
                  }
                  ref.read(readingPreferencesProvider.notifier).update((p) => p.copyWith(preferredContentTypes: next));
                },
              ),
          ],
        ),
        const _Label('Discovery'),
        MwbSwitchTile(
          title: 'Personalised recommendations',
          subtitle: 'Use your interests to order Home and Discover',
          value: daily.personalisedDiscovery,
          onChanged: (v) => dCtrl.update((d) => d.copyWith(personalisedDiscovery: v)),
        ),
        MwbSwitchTile(
          title: 'Recommended audio on Home',
          value: daily.includeAudioInDiscovery,
          onChanged: (v) => dCtrl.update((d) => d.copyWith(includeAudioInDiscovery: v)),
        ),
        MwbSwitchTile(
          title: 'Recommended videos on Home',
          value: daily.includeVideoInDiscovery,
          onChanged: (v) => dCtrl.update((d) => d.copyWith(includeVideoInDiscovery: v)),
        ),
        const _Label('Daily time with God'),
        MwbSegmentedControl<DevotionGoal>(
          options: DevotionGoal.values,
          value: daily.devotionGoal,
          onChanged: (g) => dCtrl.update((d) => d.copyWith(devotionGoal: g)),
          labelOf: (g) => '${g.minutes} min',
        ),
      ],
    );
  }
}

// ── Privacy & data ──────────────────────────────────────────────────────

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return SettingsPage(
      title: 'Privacy & data',
      children: [
        Text(
          'In Foundation V1 everything you enter stays on this device. Nothing is sent to a server: '
          'there is no account, no analytics and no advertising tracking.',
          style: t.body,
        ),
        const _Label('Stored on this device'),
        for (final line in const [
          'Your first name and gender preference',
          'Theme, reading and notification preferences',
          'Bookmarks, highlights, notes and saved Scripture',
          'Saved content, collections and history',
          'Recent searches, drafts and reports',
          'Reflections and Word rhythm, in an encrypted database (managed under Profile → Journal privacy)',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_rounded, size: 16, color: c.primary),
                const SizedBox(width: MwbSpace.xs),
                Expanded(child: Text(line, style: t.supporting)),
              ],
            ),
          ),
        const _Label('Manage'),
        _DangerTile(
          title: 'Clear search history',
          subtitle: 'Remove recent searches',
          onConfirm: () => ref.read(recentSearchesProvider.notifier).clear(),
          confirmTitle: 'Clear search history?',
          confirmMessage: 'Your recent searches will be removed.',
          done: 'Search history cleared',
        ),
        _DangerTile(
          title: 'Clear library',
          subtitle: 'Bookmarks, highlights, notes, saved items, collections and history',
          onConfirm: () => ref.read(libraryActionsProvider).clearLibrary(),
          confirmTitle: 'Clear your entire library?',
          confirmMessage:
              'All bookmarks, highlights, notes, saved items, collections, history and drafts will be '
              'permanently deleted from this device. This cannot be undone.',
          done: 'Library cleared',
        ),
        _DangerTile(
          title: 'Reset onboarding',
          subtitle: 'Start the welcome journey again',
          onConfirm: () => ref.read(profileActionsProvider).resetOnboarding(),
          confirmTitle: 'Reset onboarding?',
          confirmMessage:
              'Your name, interests and reading preferences will be cleared and the welcome steps '
              'will be shown again. Your library and theme are kept.',
          done: null,
        ),
      ],
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.title,
    required this.subtitle,
    required this.onConfirm,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.done,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onConfirm;
  final String confirmTitle;
  final String confirmMessage;
  final String? done;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: context.mwb.text.label.copyWith(fontSize: 15, color: c.error)),
      subtitle: Text(subtitle, style: context.mwb.text.caption),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      onTap: () async {
        final ok = await showMwbConfirmDialog(
          context,
          title: confirmTitle,
          message: confirmMessage,
          confirmLabel: 'Confirm',
          destructive: true,
        );
        if (!ok) return;
        await onConfirm();
        if (done != null && context.mounted) showMwbSnack(context, done!);
      },
    );
  }
}

// ── Account ─────────────────────────────────────────────────────────────

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final t = context.mwb.text;
    final signedIn = session.value?.isSignedIn ?? false;
    return SettingsPage(
      title: 'Account settings',
      children: [
        MwbCard(
          child: Row(
            children: [
              Icon(
                signedIn ? Icons.verified_user_outlined : Icons.person_outline_rounded,
                color: context.mwb.colors.primary,
              ),
              const SizedBox(width: MwbSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(signedIn ? 'Signed in' : 'Guest session', style: t.cardTitle),
                    Text(
                      signedIn ? (session.value?.email ?? '') : 'Data is saved on this device only',
                      style: t.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MwbSpace.md),
        accountsNotice,
        const SizedBox(height: MwbSpace.lg),
        if (signedIn)
          MwbSecondaryButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () async {
              final ok = await showMwbConfirmDialog(
                context,
                title: 'Sign out?',
                message: 'You will return to a guest session on this device.',
                confirmLabel: 'Sign out',
              );
              if (!ok) return;
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(sessionProvider);
            },
          )
        else
          MwbPrimaryButton(label: 'Sign in', onPressed: () => showSignInSheet(context)),
      ],
    );
  }
}
