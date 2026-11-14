import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/daily_word.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../../data/models/scripture_reference.dart';
import '../../bible/application/bible_providers.dart';
import '../../daily_word/application/daily_word_providers.dart';
import '../../library/application/library_controllers.dart';
import '../application/personal_providers.dart';
import 'personal_widgets.dart';

/// Personal Word Rhythm: a private record of readings the user completed and
/// reflections they wrote. Counts only, no scores; empty days are simply empty.
class RhythmScreen extends ConsumerStatefulWidget {
  const RhythmScreen({super.key});

  @override
  ConsumerState<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends ConsumerState<RhythmScreen> {
  late DateTime _month;
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _month = DateTime(now.year, now.month);
    _selectedDay = dateKeyOf(now);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final ready = ref.watch(rhythmRepositoryProvider) != null;
    final week = ref.watch(currentWeekProvider);
    final session = ref.watch(activeSessionProvider);
    final history = ref.watch(completedReadingsProvider);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
        children: [
          const MwbPageTitle(overline: 'Private to you', title: 'Word rhythm'),
          const SizedBox(height: MwbSpace.xs),
          Text(
            'A quiet record of the Scripture you chose to complete and the reflections you wrote. '
            'It stays on this device and is never shared.',
            style: t.supporting,
          ),
          const SizedBox(height: MwbSpace.lg),
          const PersonalStoreNotice(),
          if (ready) ...[
            if (session != null) _SessionCard(session: session) else const _StartSession(),
            const SizedBox(height: MwbSpace.xl),
            if (week != null) ...[
              MwbSectionHeading(overline: 'This week', title: week.isEmpty ? 'A fresh week' : weekSummaryLine(week)),
              const SizedBox(height: MwbSpace.sm),
              MwbCard(
                key: const Key('rhythm.week'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RhythmWeekStrip(week: week),
                    if (!week.isEmpty) ...[
                      const SizedBox(height: MwbSpace.sm),
                      Text(
                        'Time in the Word on ${week.daysWithScripture} '
                        '${week.daysWithScripture == 1 ? 'day' : 'days'} this week.',
                        style: t.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: MwbSpace.xl),
            _MonthCalendar(
              month: _month,
              selected: _selectedDay,
              onMonth: (m) => setState(() => _month = m),
              onDay: (d) => setState(() => _selectedDay = d),
            ),
            if (_selectedDay != null) ...[const SizedBox(height: MwbSpace.md), _DayDetail(dateKey: _selectedDay!)],
            const SizedBox(height: MwbSpace.xl),
            MwbSectionHeading(overline: 'History', title: 'Completed readings'),
            const SizedBox(height: MwbSpace.sm),
            if (history.isEmpty)
              const MwbEmptyState(
                compact: true,
                icon: Icons.menu_book_outlined,
                title: 'No completed readings yet',
                message: 'At the end of a chapter in the reader, choose Complete reading.',
              )
            else
              for (final r in history.take(100)) _ReadingTile(record: r),
            const SizedBox(height: MwbSpace.lg),
            Text(
              'Opening a chapter is never counted. Only readings you mark complete appear here.',
              style: t.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});
  final ReadingSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    return MwbCard(
      key: const Key('rhythm.activeSession'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('READING SESSION', style: t.overline),
          const SizedBox(height: 4),
          Text(session.chapter.label, style: t.cardTitle),
          Text(
            'Started ${clockTime(session.startedAt)}. Choose Complete reading at the end of the chapter.',
            style: t.caption,
          ),
          const SizedBox(height: MwbSpace.sm),
          MwbPrimaryButton(
            label: 'Continue reading',
            icon: Icons.menu_book_rounded,
            onPressed: () => context.push(AppRoutes.reader(session.chapter.bookId, session.chapter.chapter)),
          ),
          const SizedBox(height: MwbSpace.xs),
          Center(
            child: MwbTextButton(
              key: const Key('rhythm.endSession'),
              label: 'End session',
              onPressed: () {
                ref.read(personalActionsProvider).endSession(session.id);
                showMwbSnack(context, 'Reading session ended');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StartSession extends ConsumerWidget {
  const _StartSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MwbPrimaryButton(
      key: const Key('rhythm.startSession'),
      label: 'Start a reading session',
      icon: Icons.play_arrow_rounded,
      onPressed: () => _chooseChapter(context, ref),
    );
  }

  Future<void> _chooseChapter(BuildContext context, WidgetRef ref) async {
    final history = ref.read(readingHistoryProvider);
    final today = dailyWordTodayReference(ref);
    final options = <(String, String, ScriptureReference)>[
      if (history.isNotEmpty) ('Continue where you were', history.first.reference.label, history.first.reference),
      if (today != null) ("Today's Daily Word passage", today.chapterOnly.label, today.chapterOnly),
      if (history.isEmpty)
        ('Begin with the Gospel of John', 'John 1', const ScriptureReference(bookId: 'JHN', chapter: 1)),
    ];
    final chosen = await showMwbSheet<ScriptureReference>(
      context,
      title: 'Start a reading session',
      subtitle: 'Choose Complete reading at the end of the chapter when you are done.',
      builder: (ctx) => Column(
        children: [
          for (final o in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.menu_book_outlined, color: ctx.mwb.colors.primary),
              title: Text(o.$2, style: ctx.mwb.text.label.copyWith(fontSize: 15)),
              subtitle: Text(o.$1, style: ctx.mwb.text.caption),
              onTap: () => Navigator.of(ctx).pop(o.$3),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.travel_explore_rounded, color: ctx.mwb.colors.primary),
            title: Text('Another chapter', style: ctx.mwb.text.label.copyWith(fontSize: 15)),
            subtitle: Text(
              'Open a chapter, then choose Start reading session from the reader menu',
              style: ctx.mwb.text.caption,
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.bible);
            },
          ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    ref
        .read(personalActionsProvider)
        .startSession(chosen, versionId: ref.read(textVersionProvider).id, origin: PersonalOrigin.rhythm);
    context.push(AppRoutes.reader(chosen.bookId, chosen.chapter));
  }
}

/// Today's Daily Word reference if it has been delivered (never triggers a delivery).
ScriptureReference? dailyWordTodayReference(WidgetRef ref) {
  final today = dateKeyOf(ref.read(clockProvider)());
  return ref.read(dailyWordHistoryProvider).where((e) => e.dateKey == today).firstOrNull?.reference;
}

class _MonthCalendar extends ConsumerWidget {
  const _MonthCalendar({required this.month, required this.selected, required this.onMonth, required this.onDay});

  final DateTime month;
  final String? selected;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<String> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final days = ref.watch(rhythmMonthProvider(month));
    final today = dateKeyOf(ref.watch(clockProvider)());
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - DateTime.monday;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return MwbCard(
      key: const Key('rhythm.calendar'),
      child: Column(
        children: [
          Row(
            children: [
              MwbIconButton(
                key: const Key('rhythm.prevMonth'),
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous month',
                onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Center(child: Text('${monthName(month.month)} ${month.year}', style: t.cardTitle)),
              ),
              MwbIconButton(
                key: const Key('rhythm.nextMonth'),
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: MwbSpace.xs),
          Row(
            children: [
              for (final l in letters)
                Expanded(
                  child: Center(
                    child: Text(l, style: t.caption.copyWith(color: c.textSecondary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row * 7 < lead + count; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final n = row * 7 + col - lead + 1;
                        if (n < 1 || n > count) return const SizedBox(height: 44);
                        final key = dateKeyOf(DateTime(month.year, month.month, n));
                        final day = days[key];
                        final active = day?.hasActivity ?? false;
                        final isSelected = key == selected;
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label: '$n ${monthName(month.month)}${active ? ', time in the Word' : ''}',
                          excludeSemantics: true,
                          child: InkWell(
                            key: Key('rhythm.day.$key'),
                            borderRadius: MwbRadius.mdAll,
                            onTap: () => onDay(key),
                            child: SizedBox(
                              height: 44,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? c.primary.withValues(alpha: 0.14) : null,
                                      border: key == today ? Border.all(color: c.primary, width: 1.4) : null,
                                    ),
                                    child: Text('$n', style: t.label.copyWith(color: c.textPrimary)),
                                  ),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: active ? c.primary : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.dateKey});
  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final items = ref.watch(rhythmDayActivityProvider(dateKey));
    return Column(
      key: Key('rhythm.dayDetail.$dateKey'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(longDate(dateFromKey(dateKey)), style: t.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text('Nothing recorded.', style: t.caption.copyWith(color: c.textSecondary))
        else
          for (final r in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r.kind == ActivityKind.readingCompleted ? Icons.check_circle_outline_rounded : Icons.edit_note_rounded,
                color: c.primary,
              ),
              title: Text(
                r.kind == ActivityKind.readingCompleted
                    ? 'Completed ${r.reference?.label ?? ''}'
                    : r.reference == null
                    ? 'Wrote a reflection'
                    : 'Reflected on ${r.reference!.label}',
                style: t.label,
              ),
              subtitle: Text(clockTime(r.occurredAt), style: t.caption),
              onTap: r.kind == ActivityKind.reflectionWritten && r.journalId != null
                  ? () => context.push(AppRoutes.journalEntry(r.journalId!))
                  : null,
            ),
      ],
    );
  }
}

class _ReadingTile extends ConsumerWidget {
  const _ReadingTile({required this.record});
  final ActivityRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final r = record.reference!;
    final d = dateFromKey(record.localDate);
    return ListTile(
      key: Key('rhythm.reading.${record.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.check_circle_outline_rounded, color: c.primary),
      title: Text(r.label, style: t.label.copyWith(fontSize: 15)),
      subtitle: Text(
        '${d.day} ${monthName(d.month)} ${d.year} · ${clockTime(record.occurredAt)} · ${record.versionId}',
        style: t.caption,
      ),
      onTap: () => context.push(AppRoutes.reader(r.bookId, r.chapter)),
      trailing: MwbIconButton(
        icon: Icons.remove_circle_outline_rounded,
        tooltip: 'Remove from history',
        onPressed: () async {
          final ok = await showMwbConfirmDialog(
            context,
            title: 'Remove this reading?',
            message: '${r.label} will be removed from your rhythm.',
            confirmLabel: 'Remove',
            destructive: true,
          );
          if (ok) ref.read(personalActionsProvider).removeCompletion(record.id);
        },
      ),
    );
  }
}
