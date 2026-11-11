import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/segmented.dart';
import '../../../core/widgets/selection.dart';
import '../../../data/models/content.dart';
import '../../../data/models/interest.dart';
import '../../../data/models/user_profile.dart';
import '../../bible/widgets/version_picker.dart';
import '../application/onboarding_controller.dart';

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: t.display.copyWith(fontSize: 36))),
        const SizedBox(height: MwbSpace.sm),
        Text(subtitle, style: t.body.copyWith(color: context.mwb.colors.textSecondary)),
        const SizedBox(height: MwbSpace.xl),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: MwbSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: t.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (hint != null) Text(hint!, style: t.caption),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: MwbSpace.xs),
      child: Text(message, style: context.mwb.text.caption.copyWith(color: context.mwb.colors.error)),
    ),
  );
}

// ── Step 1 ──────────────────────────────────────────────────────────────

class PersonalStep extends ConsumerWidget {
  const PersonalStep({super.key, required this.nameController});

  final TextEditingController nameController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final nameError = draft.showErrors ? OnboardingValidation.firstName(draft.firstName) : null;
    final genderError = draft.showErrors ? OnboardingValidation.gender(draft.gender) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Let’s start with you',
          subtitle: 'Your name and preferences help us make your Scripture experience more personal.',
        ),
        const _FieldLabel('First name'),
        TextField(
          key: const Key('onboarding.firstName'),
          controller: nameController,
          onChanged: ctrl.setFirstName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.givenName],
          maxLength: 30,
          style: t.body,
          decoration: InputDecoration(hintText: 'e.g. Grace', errorText: nameError, counterText: ''),
        ),
        const SizedBox(height: MwbSpace.xl),
        const _FieldLabel('Gender'),
        MwbRadioGroup<GenderPreference>(
          options: GenderPreference.values,
          value: draft.gender,
          onChanged: ctrl.setGender,
          labelOf: (g) => g.label,
          dense: true,
        ),
        if (genderError != null) _ErrorText(genderError),
        const SizedBox(height: MwbSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: c.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Stored only on this device. Your choice never changes the words of Scripture.',
                style: t.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Step 2 ──────────────────────────────────────────────────────────────

class InterestsStep extends ConsumerWidget {
  const InterestsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final error = draft.showErrors ? OnboardingValidation.interests(draft.interests) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'What would you like to grow in?',
          subtitle: 'Choose as many as you like. We’ll shape your daily Scripture and recommendations around them.',
        ),
        _FieldLabel('Spiritual interests', hint: '${draft.interests.length} selected'),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 520 ? 2 : 1;
            final w = (constraints.maxWidth - MwbSpace.xs * (cols - 1)) / cols;
            return Wrap(
              spacing: MwbSpace.xs,
              runSpacing: MwbSpace.xs,
              children: [
                for (final i in spiritualInterests)
                  SizedBox(
                    width: w,
                    child: MwbSelectionCard(
                      key: Key('interest.${i.id}'),
                      title: i.label,
                      subtitle: i.description,
                      multiSelect: true,
                      dense: true,
                      selected: draft.interests.contains(i.id),
                      onTap: () => ctrl.toggleInterest(i.id),
                    ),
                  ),
              ],
            );
          },
        ),
        if (error != null) _ErrorText(error),
      ],
    );
  }
}

// ── Step 3 ──────────────────────────────────────────────────────────────

class ReadingStep extends ConsumerWidget {
  const ReadingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final t = context.mwb.text;
    final reading = draft.reading;
    final typesError = draft.showErrors ? OnboardingValidation.contentTypes(reading.preferredContentTypes) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'How do you like to read?',
          subtitle: 'Set up a comfortable reading experience. You can change any of this later in Profile.',
        ),
        const _FieldLabel('Bible version'),
        BibleVersionPicker(
          catalogue: ref.watch(versionCatalogueProvider),
          selectedId: reading.versionId,
          onSelected: (v) => ctrl.updateReading((r) => r.copyWith(versionId: v.id)),
        ),
        const SizedBox(height: MwbSpace.xl),
        const _FieldLabel('Reading text size'),
        MwbSegmentedControl<ReadingTextSize>(
          options: ReadingTextSize.values,
          value: reading.textSize,
          onChanged: (s) => ctrl.updateReading((r) => r.copyWith(textSize: s)),
          labelOf: (s) => s == ReadingTextSize.extraLarge ? 'XL' : s.label,
        ),
        const SizedBox(height: MwbSpace.sm),
        AnimatedDefaultTextStyle(
          duration: MwbMotion.fast,
          style: t.scripture.copyWith(fontSize: reading.textSize.fontSize),
          child: const Text('In the beginning God created the heaven and the earth.'),
        ),
        const SizedBox(height: 4),
        Text('GENESIS 1:1 · KJV · PREVIEW', style: t.scriptureReference.copyWith(fontSize: 11)),
        const SizedBox(height: MwbSpace.xl),
        const _FieldLabel('Daily reading goal'),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final g in DailyReadingGoal.values)
              MwbChip(
                label: g.label,
                selected: reading.dailyGoal == g,
                onTap: () => ctrl.updateReading((r) => r.copyWith(dailyGoal: g)),
              ),
          ],
        ),
        const SizedBox(height: MwbSpace.xl),
        const _FieldLabel('Content you enjoy'),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final type in const [ContentType.scriptureReference, ContentType.audio, ContentType.video])
              MwbChip(
                label: type.label,
                icon: switch (type) {
                  ContentType.audio => Icons.headphones_outlined,
                  ContentType.video => Icons.play_circle_outline_rounded,
                  _ => Icons.menu_book_outlined,
                },
                selected: reading.preferredContentTypes.contains(type),
                onTap: () => ctrl.toggleContentType(type),
              ),
          ],
        ),
        if (typesError != null) _ErrorText(typesError),
      ],
    );
  }
}

// ── Step 4 ──────────────────────────────────────────────────────────────

class DailyStep extends ConsumerWidget {
  const DailyStep({super.key});

  Future<void> _pickTime(BuildContext context, WidgetRef ref, ReminderTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Daily Scripture reminder',
    );
    if (picked != null) {
      ref
          .read(onboardingControllerProvider.notifier)
          .updateDaily((d) => d.copyWith(reminderTime: ReminderTime(picked.hour, picked.minute)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final daily = draft.daily;
    final c = context.mwb.colors;
    final t = context.mwb.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Shape your daily rhythm',
          subtitle: 'A few gentle habits help Scripture become part of every day.',
        ),
        MwbSwitchTile(
          key: const Key('onboarding.reminder'),
          icon: Icons.notifications_none_rounded,
          title: 'Daily Scripture reminder',
          subtitle: 'A quiet nudge to spend time in the Word',
          value: daily.reminderEnabled,
          onChanged: (v) => ctrl.updateDaily((d) => d.copyWith(reminderEnabled: v)),
        ),
        AnimatedSize(
          duration: MwbMotion.medium,
          curve: MwbMotion.curve,
          child: daily.reminderEnabled
              ? Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.schedule_rounded, color: c.textSecondary),
                      title: Text('Reminder time', style: t.label.copyWith(fontSize: 15)),
                      trailing: Text(
                        formatTimeOfDay(daily.reminderTime.hour, daily.reminderTime.minute),
                        style: t.bodyStrong.copyWith(color: c.primary),
                      ),
                      onTap: () => _pickTime(context, ref, daily.reminderTime),
                    ),
                    const MwbNotice(
                      message:
                          'Your reminder time is saved now. Notification delivery arrives in an upcoming '
                          'update, and we will ask for permission only when it is ready.',
                    ),
                    const SizedBox(height: MwbSpace.xs),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: MwbSpace.lg),
        const _FieldLabel('Daily time with God'),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final g in DevotionGoal.values)
              MwbChip(
                label: g.label,
                selected: daily.devotionGoal == g,
                onTap: () => ctrl.updateDaily((d) => d.copyWith(devotionGoal: g)),
              ),
          ],
        ),
        const SizedBox(height: MwbSpace.xl),
        const _FieldLabel('Discovery'),
        MwbSwitchTile(
          icon: Icons.auto_awesome_outlined,
          title: 'Personalised recommendations',
          subtitle: 'Suggest content based on your interests',
          value: daily.personalisedDiscovery,
          onChanged: (v) => ctrl.updateDaily((d) => d.copyWith(personalisedDiscovery: v)),
        ),
        MwbSwitchTile(
          icon: Icons.headphones_outlined,
          title: 'Audio messages',
          subtitle: 'Show recommended audio on Home',
          value: daily.includeAudioInDiscovery,
          onChanged: (v) => ctrl.updateDaily((d) => d.copyWith(includeAudioInDiscovery: v)),
        ),
        MwbSwitchTile(
          icon: Icons.play_circle_outline_rounded,
          title: 'Video excerpts',
          subtitle: 'Show recommended videos on Home',
          value: daily.includeVideoInDiscovery,
          onChanged: (v) => ctrl.updateDaily((d) => d.copyWith(includeVideoInDiscovery: v)),
        ),
      ],
    );
  }
}
