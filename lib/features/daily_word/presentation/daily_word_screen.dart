import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/daily_word.dart';
import '../../../data/models/intelligence.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../../data/models/scripture_reference.dart';
import '../../bible/application/bible_providers.dart';
import '../../library/application/library_controllers.dart';
import '../application/daily_word_providers.dart';
import 'daily_word_hero.dart';

/// The full Daily Word for one date: Scripture first, then why it was
/// chosen, its context, and related Scripture and intelligence.
class DailyWordScreen extends ConsumerStatefulWidget {
  const DailyWordScreen({super.key, this.dateKey});

  /// `yyyy-mm-dd`; today when null.
  final String? dateKey;

  @override
  ConsumerState<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends ConsumerState<DailyWordScreen> {
  bool _markedOpen = false;

  String get _key => widget.dateKey ?? ref.read(todayKeyProvider);

  @override
  Widget build(BuildContext context) {
    final key = _key;
    final detail = ref.watch(dailyWordDetailProvider(key));
    if (!_markedOpen && detail.hasValue) {
      _markedOpen = true;
      Future.microtask(() => ref.read(dailyWordHistoryProvider.notifier).markOpened(key, ref.read(clockProvider)()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Word'),
        actions: [
          MwbIconButton(
            key: const Key('dailyWord.history'),
            icon: Icons.history_rounded,
            tooltip: 'Daily Word history',
            onPressed: () => context.push(AppRoutes.dailyWordHistory),
          ),
          const SizedBox(width: MwbSpace.xs),
        ],
      ),
      // Fill the body so loading and error states are centred.
      body: SizedBox.expand(
        child: AsyncValueView<DailyWordDetail>(
          value: detail,
          loadingMessage: 'Opening the Daily Word…',
          onRetry: () => ref.invalidate(dailyWordDetailProvider(key)),
          data: (d) => _DailyWordBody(detail: d, isToday: key == ref.watch(todayKeyProvider)),
        ),
      ),
    );
  }
}

class _DailyWordBody extends ConsumerWidget {
  const _DailyWordBody({required this.detail, required this.isToday});
  final DailyWordDetail detail;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final e = detail.entry;
    final ctx = detail.context;
    final hasRelated =
        detail.promises.isNotEmpty ||
        detail.identityThemes.isNotEmpty ||
        detail.commands.isNotEmpty ||
        detail.worshipThemes.isNotEmpty;
    return ListView(
      key: const Key('dailyWord.body'),
      padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxxl),
      children: [
        MwbConstrained(
          padded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isToday) ...[
                Align(alignment: Alignment.centerLeft, child: _Pill(label: 'Today', color: c.primary)),
                const SizedBox(height: MwbSpace.sm),
              ],
              DailyWordHero(detail: detail, showQuickActions: false),
              const SizedBox(height: MwbSpace.md),
              _Actions(detail: detail),
              if (ctx != null) ...[
                const SizedBox(height: MwbSpace.xl),
                _Section(title: 'About this passage', child: _ContextFacts(context: ctx)),
              ],
              if (detail.surrounding.length > detail.verses.length) ...[
                const SizedBox(height: MwbSpace.xl),
                _Section(title: 'Read it in context', child: _Surrounding(detail: detail)),
              ],
              if (detail.related.isNotEmpty) ...[
                const SizedBox(height: MwbSpace.xl),
                _Section(
                  title: 'Related Scripture',
                  child: Column(children: [for (final r in detail.related) _RelatedScriptureTile(item: r)]),
                ),
              ],
              if (hasRelated) ...[
                const SizedBox(height: MwbSpace.xl),
                _Section(title: 'Go deeper', child: _RelatedRecords(detail: detail)),
              ],
              const SizedBox(height: MwbSpace.xl),
              _HistoryNav(current: e),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(MwbRadius.pill),
    ),
    child: Text(
      label,
      style: context.mwb.text.label.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

void _openReader(BuildContext context, ScriptureReference r) =>
    context.push(AppRoutes.reader(r.bookId, r.chapter, verse: r.verseStart));

class _Actions extends ConsumerWidget {
  const _Actions({required this.detail});
  final DailyWordDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = detail.entry;
    final saved = ref.watch(savedScriptureProvider).any((s) => s.reference == e.reference);
    final favourite =
        ref.watch(
          dailyWordHistoryProvider.select((h) => h.where((x) => x.dateKey == e.dateKey).firstOrNull?.favourite),
        ) ??
        false;
    return Wrap(
      spacing: MwbSpace.xs,
      runSpacing: MwbSpace.xs,
      children: [
        _ActionChip(
          key: const Key('dailyWord.save'),
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
          label: saved ? 'Saved' : 'Save',
          active: saved,
          onTap: () async {
            final now = await ref
                .read(savedScriptureProvider.notifier)
                .toggle(e.reference, versionId: detail.version.id);
            if (context.mounted) showMwbSnack(context, now ? 'Saved to your Library' : 'Removed from your Library');
          },
        ),
        _ActionChip(
          key: const Key('dailyWord.favourite'),
          icon: favourite ? Icons.star_rounded : Icons.star_border_rounded,
          label: favourite ? 'Favourited' : 'Favourite',
          active: favourite,
          onTap: () async {
            final now = await ref.read(dailyWordHistoryProvider.notifier).toggleFavourite(e.dateKey);
            if (context.mounted) {
              showMwbSnack(context, now ? 'Added to favourite Daily Words' : 'Removed from favourites');
            }
          },
        ),
        _ActionChip(
          key: const Key('dailyWord.reflect'),
          icon: Icons.edit_note_rounded,
          label: 'Reflect',
          onTap: () => context.push(
            AppRoutes.newReflection(
              reference: e.reference,
              versionId: detail.version.id,
              source: PersonalOrigin.dailyWord,
              dailyWordDate: e.dateKey,
            ),
          ),
        ),
        _ActionChip(
          key: const Key('dailyWord.read'),
          icon: Icons.menu_book_rounded,
          label: 'Read ${e.reference.chapterOnly.label}',
          onTap: () => _openReader(context, e.reference),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({super.key, required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final fg = active ? c.primary : c.textPrimary;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: active ? c.primary.withValues(alpha: 0.12) : c.surface,
        shape: StadiumBorder(side: BorderSide(color: active ? c.primary : c.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MwbSpace.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: MwbSpace.xs),
                  Text(
                    label,
                    style: t.label.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: t.sectionHeading)),
        const SizedBox(height: MwbSpace.sm),
        child,
      ],
    );
  }
}

class _ContextFacts extends StatelessWidget {
  const _ContextFacts({required this.context});
  final IntelContext context;

  @override
  Widget build(BuildContext buildContext) {
    final t = buildContext.mwb.text;
    final x = context;
    final rows = <(String, String)>[
      ('Voice', x.voice.label),
      ('Speaker', x.speaker),
      ('Author', x.author),
      ('First addressed to', x.originalAudience),
      (
        'Form',
        x.literaryForm == x.classification.label ? x.literaryForm : '${x.literaryForm} · ${x.classification.label}',
      ),
      if (x.isConditional && x.conditionNote.isNotEmpty) ('Condition in the text', x.conditionNote),
      if (x.historicalContext.isNotEmpty) ('Historical context', x.historicalContext),
      if (x.literaryContext.isNotEmpty) ('Literary context', x.literaryContext),
    ];
    return Column(
      key: const Key('dailyWord.context'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: MwbSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.toUpperCase(), style: t.overline.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(v, style: t.body),
              ],
            ),
          ),
        if (x.contextNote.isNotEmpty) Text(x.contextNote, style: t.supporting.copyWith(fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _Surrounding extends StatelessWidget {
  const _Surrounding({required this.detail});
  final DailyWordDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final r = detail.entry.reference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (final v in detail.surrounding) ...[
                TextSpan(
                  text: '${v.number} ',
                  style: t.caption.copyWith(color: c.primary, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '${v.text} ',
                  style: t.scripture.copyWith(
                    fontSize: 17,
                    color: r.containsVerse(v.number) ? c.textPrimary : c.textSecondary,
                    fontWeight: r.containsVerse(v.number) ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RelatedRecords extends StatelessWidget {
  const _RelatedRecords({required this.detail});
  final DailyWordDetail detail;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final p in detail.promises)
        _RecordCard(
          kind: 'Promise · ${p.category}',
          title: p.title,
          lines: [
            'First given to: ${p.originalAudience}',
            for (final cond in p.conditions) 'Condition: $cond',
            p.receptionGuidance,
          ],
          reference: p.references.first,
        ),
      for (final i in detail.identityThemes)
        _RecordCard(
          kind: 'Identity',
          title: i.title,
          lines: ['Describes: ${i.holder}', i.note],
          reference: i.references.first,
        ),
      for (final m in detail.commands)
        _RecordCard(
          kind: 'Command',
          title: m.title,
          lines: ['First addressed to: ${m.addressedTo}', if (m.contextNote.isNotEmpty) m.contextNote],
          reference: m.references.first,
        ),
      for (final w in detail.worshipThemes)
        _RecordCard(
          kind: 'Worship · ${w.worshipKind.name}',
          title: w.title,
          lines: const [],
          reference: w.references.first,
        ),
    ];
    return Column(key: const Key('dailyWord.related'), children: items);
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.kind, required this.title, required this.lines, required this.reference});
  final String kind;
  final String title;
  final List<String> lines;
  final ScriptureReference reference;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: MwbSpace.sm),
      child: MwbCard(
        color: c.surface,
        onTap: () => _openReader(context, reference),
        semanticLabel: '$kind: $title. ${reference.label}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind.toUpperCase(), style: t.overline.copyWith(fontSize: 11)),
            const SizedBox(height: 4),
            Text(title, style: t.cardTitle),
            for (final l in lines.where((l) => l.isNotEmpty)) ...[
              const SizedBox(height: 4),
              Text(l, style: t.supporting),
            ],
            const SizedBox(height: 6),
            Text(reference.label.toUpperCase(), style: t.scriptureReference),
          ],
        ),
      ),
    );
  }
}

class _RelatedScriptureTile extends StatelessWidget {
  const _RelatedScriptureTile({required this.item});
  final RelatedScripture item;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Semantics(
      button: true,
      label: '${item.reference.label}. ${item.label}. Opens the reader.',
      excludeSemantics: true,
      child: InkWell(
        key: Key('dailyWord.related.${item.reference.key}'),
        borderRadius: MwbRadius.mdAll,
        onTap: () => _openReader(context, item.reference),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.reference.label.toUpperCase()} · ${item.label}', style: t.scriptureReference),
                    if (item.text != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.text!,
                        style: t.scripture.copyWith(fontSize: 16),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.explanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.explanation, style: t.caption),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryNav extends ConsumerWidget {
  const _HistoryNav({required this.current});
  final DailyWordHistoryEntry current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(dailyWordHistoryProvider);
    final older = history.where((h) => h.dateKey.compareTo(current.dateKey) < 0).firstOrNull;
    final newer = history.reversed.where((h) => h.dateKey.compareTo(current.dateKey) > 0).firstOrNull;
    return Row(
      children: [
        Expanded(
          child: older == null
              ? const SizedBox.shrink()
              : MwbSecondaryButton(
                  key: const Key('dailyWord.previous'),
                  label: formatShortDate(older.date),
                  icon: Icons.chevron_left_rounded,
                  onPressed: () => context.replace(AppRoutes.dailyWord(older.dateKey)),
                ),
        ),
        const SizedBox(width: MwbSpace.sm),
        Expanded(
          child: newer == null
              ? const SizedBox.shrink()
              : MwbSecondaryButton(
                  key: const Key('dailyWord.next'),
                  label: formatShortDate(newer.date),
                  icon: Icons.chevron_right_rounded,
                  onPressed: () => context.replace(AppRoutes.dailyWord(newer.dateKey)),
                ),
        ),
      ],
    );
  }
}
