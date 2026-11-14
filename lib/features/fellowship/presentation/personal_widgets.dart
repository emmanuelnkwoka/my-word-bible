import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/local/personal_database.dart';
import '../../../data/models/daily_word.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../bible/application/bible_providers.dart';
import '../application/personal_providers.dart';

String twoDigits(int n) => n.toString().padLeft(2, '0');
String clockTime(DateTime t) {
  final l = t.toLocal();
  return '${twoDigits(l.hour)}:${twoDigits(l.minute)}';
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String monthName(int month) => _months[month - 1];
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

/// Shown where personal data would appear when the encrypted store cannot be
/// used. States the situation plainly; offers a fresh start only when the
/// old file can never be read again.
class PersonalStoreNotice extends ConsumerWidget {
  const PersonalStoreNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(personalStoreProvider);
    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const MwbNotice(
        icon: Icons.lock_outline_rounded,
        title: 'Private store unavailable',
        message: 'Your reflections and reading rhythm could not be opened on this device right now.',
      ),
      data: (s) => switch (s) {
        PersonalStoreReady() => const SizedBox.shrink(),
        PersonalStoreUnavailable(:final failure)
            when failure == PersonalStoreFailure.keyLost || failure == PersonalStoreFailure.wrongKey =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MwbNotice(
                key: Key('personal.keyLost'),
                icon: Icons.key_off_outlined,
                title: 'Your earlier reflections cannot be opened',
                message:
                    'They were encrypted with a key that is no longer on this device (this happens after '
                    'restoring app data to a new phone or resetting secure storage). No one, including '
                    'My Word Bible, can recover them. The encrypted file is kept until you choose to start again.',
              ),
              const SizedBox(height: MwbSpace.sm),
              MwbSecondaryButton(
                key: const Key('personal.startAgain'),
                label: 'Start a new private journal',
                icon: Icons.restart_alt_rounded,
                onPressed: () async {
                  final ok = await showMwbConfirmDialog(
                    context,
                    title: 'Start a new private journal?',
                    message: 'The unreadable encrypted file will be deleted permanently. This cannot be undone.',
                    confirmLabel: 'Delete and start again',
                    destructive: true,
                  );
                  if (ok) await ref.read(personalActionsProvider).startNewPersonalStore();
                },
              ),
            ],
          ),
        PersonalStoreUnavailable(:final failure) => MwbNotice(
          key: const Key('personal.unavailable'),
          icon: Icons.lock_outline_rounded,
          title: 'Private store unavailable',
          message: switch (failure) {
            PersonalStoreFailure.keyStoreUnavailable =>
              'Secure storage could not be read just now. Nothing has been changed; please try again later.',
            PersonalStoreFailure.encryptionUnavailable =>
              'Encryption is not available in this build, so reflections are not stored.',
            PersonalStoreFailure.newerSchema =>
              'Your reflections were saved by a newer version of My Word Bible. Update the app to open them.',
            _ => 'Your reflections and reading rhythm could not be opened on this device right now.',
          },
        ),
      },
    );
  }
}

/// Seven quiet markers, Monday to Sunday. No numbers, no comparisons.
class RhythmWeekStrip extends ConsumerWidget {
  const RhythmWeekStrip({super.key, required this.week});
  final RhythmWeek week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final today = dateKeyOf(ref.watch(clockProvider)());
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Semantics(
              label: '${_weekdays[i]}: ${week.days[i].hasActivity ? 'time in the Word' : 'nothing recorded'}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(letters[i], style: t.caption.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: week.days[i].hasActivity ? c.primary : Colors.transparent,
                      border: Border.all(
                        color: week.days[i].dateKey == today ? c.primary : c.border,
                        width: week.days[i].dateKey == today ? 1.6 : 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String weekSummaryLine(RhythmWeek w) {
  if (w.isEmpty) return 'Nothing recorded yet this week.';
  String n(int v, String one, String many) => '$v ${v == 1 ? one : many}';
  return [
    if (w.readingsCompleted > 0) n(w.readingsCompleted, 'reading completed', 'readings completed'),
    if (w.reflectionsWritten > 0) n(w.reflectionsWritten, 'reflection', 'reflections'),
  ].join(' · ');
}

/// Home: a calm summary of the private rhythm.
class RhythmHomeCard extends ConsumerWidget {
  const RhythmHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(rhythmRepositoryProvider) == null) return const SizedBox.shrink();
    final week = ref.watch(currentWeekProvider);
    final session = ref.watch(activeSessionProvider);
    if (week == null) return const SizedBox.shrink();
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home.rhythm'),
        borderRadius: MwbRadius.xlAll,
        onTap: () => context.push(AppRoutes.rhythm),
        child: Ink(
          padding: const EdgeInsets.all(MwbSpace.md),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: MwbRadius.xlAll,
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('YOUR WORD RHYTHM', style: t.overline)),
                  Icon(Icons.lock_outline_rounded, size: 14, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text('Private', style: t.caption.copyWith(color: c.textSecondary)),
                ],
              ),
              const SizedBox(height: MwbSpace.xs),
              if (session != null) ...[
                Text('Reading ${session.chapter.label}', style: t.cardTitle),
                Text(
                  'Session started ${clockTime(session.startedAt)}. Choose Complete reading when you finish.',
                  style: t.caption,
                ),
                const SizedBox(height: MwbSpace.sm),
                MwbSecondaryButton(
                  key: const Key('home.rhythm.continue'),
                  label: 'Continue reading',
                  icon: Icons.menu_book_rounded,
                  onPressed: () => context.push(AppRoutes.reader(session.chapter.bookId, session.chapter.chapter)),
                ),
              ] else ...[
                Text(week.isEmpty ? 'Begin a reading session whenever you are ready' : 'This week', style: t.cardTitle),
                if (!week.isEmpty) Text(weekSummaryLine(week), style: t.caption),
              ],
              const SizedBox(height: MwbSpace.sm),
              RhythmWeekStrip(week: week),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small label that marks text as the user's own words, never Scripture.
class ReflectionLabel extends StatelessWidget {
  const ReflectionLabel({super.key, this.text = 'Your reflection'});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.edit_note_rounded, size: 16, color: c.textSecondary),
        const SizedBox(width: 4),
        Text(text.toUpperCase(), style: context.mwb.text.overline.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
