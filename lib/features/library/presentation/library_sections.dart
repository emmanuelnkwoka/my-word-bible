import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/content.dart';
import '../../../data/models/library_items.dart';
import '../../bible/widgets/scripture_card.dart';
import '../../content/widgets/content_cards.dart';
import '../../daily_word/application/daily_word_providers.dart';
import '../../daily_word/presentation/daily_word_history_screen.dart';
import '../../discovery/application/content_providers.dart';
import '../../fellowship/presentation/personal_library_cards.dart';
import '../../personalisation/application/scripture_presentation.dart';
import '../../share/scripture_share_sheet.dart';
import '../application/library_controllers.dart';
import 'note_editor.dart';

/// Every library section, used by the overview and the full-list screen.
enum LibrarySection {
  verses(
    'verses',
    'Saved Scripture',
    Icons.favorite_border_rounded,
    'Save verses from Daily Scripture, topics or the reader.',
  ),
  dailyWords(
    'daily-words',
    'Favourite Daily Words',
    Icons.star_border_rounded,
    'Tap Favourite on a Daily Word to keep it here.',
  ),
  bookmarks('bookmarks', 'Bookmarks', Icons.bookmark_border_rounded, 'Bookmark a chapter or verse while reading.'),
  highlights(
    'highlights',
    'Highlights',
    Icons.border_color_outlined,
    'Select verses in the reader and choose Highlight.',
  ),
  notes('notes', 'Notes', Icons.edit_note_rounded, 'Select verses in the reader and choose Note.'),
  audio('audio', 'Saved audio', Icons.headphones_outlined, 'Save audio messages to listen again.'),
  videos('videos', 'Saved videos', Icons.play_circle_outline_rounded, 'Save video excerpts to watch again.'),
  messages('messages', 'Saved messages & articles', Icons.article_outlined, 'Save articles and Scripture collections.'),
  history('history', 'Reading history', Icons.history_rounded, 'Chapters you read appear here.'),
  dailyHistory(
    'daily-history',
    'Daily Word history',
    Icons.wb_twilight_rounded,
    'Each Daily Word you receive appears here.',
  ),
  viewed('viewed', 'Recently viewed', Icons.visibility_outlined, 'Messages you open appear here.'),
  drafts('drafts', 'My contributions', Icons.upload_file_outlined, 'Messages you prepare to share appear here.');

  const LibrarySection(this.slug, this.title, this.icon, this.emptyHint);
  final String slug;
  final String title;
  final IconData icon;
  final String emptyHint;

  static LibrarySection? fromSlug(String slug) => values.where((s) => s.slug == slug).firstOrNull;
}

int librarySectionCount(WidgetRef ref, LibrarySection s) => switch (s) {
  LibrarySection.verses => ref.watch(savedScriptureProvider).length,
  LibrarySection.dailyWords => ref.watch(dailyWordHistoryProvider).where((e) => e.favourite).length,
  LibrarySection.dailyHistory => ref.watch(dailyWordHistoryProvider).length,
  LibrarySection.bookmarks => ref.watch(bookmarksProvider).length,
  LibrarySection.highlights => ref.watch(highlightsProvider).length,
  LibrarySection.notes => ref.watch(notesProvider).length,
  LibrarySection.audio => ref.watch(savedContentProvider).where((x) => x.type == ContentType.audio).length,
  LibrarySection.videos => ref.watch(savedContentProvider).where((x) => x.type == ContentType.video).length,
  LibrarySection.messages =>
    ref
        .watch(savedContentProvider)
        .where((x) => x.type == ContentType.article || x.type == ContentType.scriptureReference)
        .length,
  LibrarySection.history => ref.watch(readingHistoryProvider).length,
  LibrarySection.viewed => ref.watch(recentlyViewedProvider).length,
  LibrarySection.drafts => ref.watch(uploadDraftsProvider).length,
};

/// Builds rows for a section. [limit] restricts the preview length.
List<Widget> librarySectionItems(BuildContext context, WidgetRef ref, LibrarySection s, {int? limit}) {
  final t = context.mwb.text;
  final c = context.mwb.colors;
  final contentMap = ref.watch(contentMapProvider).value ?? const <String, ContentItem>{};
  Iterable<T> take<T>(Iterable<T> items) => limit == null ? items : items.take(limit);

  Widget removeButton(String tooltip, Future<void> Function() remove, String message) => MwbIconButton(
    icon: Icons.remove_circle_outline_rounded,
    tooltip: tooltip,
    onPressed: () async {
      await remove();
      if (context.mounted) showMwbSnack(context, message);
    },
  );

  List<Widget> savedOfTypes(Set<ContentType> types) => [
    for (final saved in take(ref.watch(savedContentProvider).where((x) => types.contains(x.type))))
      if (contentMap[saved.contentId] case final item?) ContentListTile(item: item),
  ];

  switch (s) {
    case LibrarySection.verses:
      return [
        for (final v in take(ref.watch(savedScriptureProvider))) ...[
          Row(
            children: [
              Expanded(child: ScriptureSnippetTile(reference: v.reference)),
              MwbIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share ${v.reference.label}',
                onPressed: () async {
                  final p = await ref.read(scripturePresentationProvider(PresentationRequest(v.reference)).future);
                  if (context.mounted) showScriptureShareSheet(context, shareScriptureFromPresentation(p));
                },
              ),
              removeButton(
                'Remove saved verse',
                () => ref.read(savedScriptureProvider.notifier).remove(v.reference),
                'Verse removed',
              ),
            ],
          ),
          // F1: reflect on this verse (on its own line so the row keeps its width).
          ReflectOnSavedButton(reference: v.reference, versionId: v.versionId),
        ],
      ];
    case LibrarySection.dailyWords:
      return [
        for (final e in take(ref.watch(dailyWordHistoryProvider).where((e) => e.favourite)))
          DailyWordHistoryTile(entry: e),
      ];
    case LibrarySection.dailyHistory:
      return [for (final e in take(ref.watch(dailyWordHistoryProvider))) DailyWordHistoryTile(entry: e)];
    case LibrarySection.bookmarks:
      return [
        for (final b in take(ref.watch(bookmarksProvider)))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bookmark_rounded, color: c.primary),
            title: Text(b.reference.label, style: t.cardTitle),
            subtitle: Text('${b.versionId} · ${formatRelative(b.createdAt)}', style: t.caption),
            onTap: () =>
                context.push(AppRoutes.reader(b.reference.bookId, b.reference.chapter, verse: b.reference.verseStart)),
            trailing: removeButton(
              'Remove bookmark',
              () => ref.read(bookmarksProvider.notifier).remove(b.reference),
              'Bookmark removed',
            ),
          ),
      ];
    case LibrarySection.highlights:
      final tones = c.highlightTones;
      return [
        for (final h in take(ref.watch(highlightsProvider)))
          Row(
            children: [
              Container(
                width: 4,
                height: 48,
                margin: const EdgeInsets.only(right: MwbSpace.sm),
                decoration: BoxDecoration(color: tones[h.tone.index], borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(child: ScriptureSnippetTile(reference: h.reference)),
              removeButton(
                'Remove highlight',
                () => ref.read(highlightsProvider.notifier).removeAll([h.reference]),
                'Highlight removed',
              ),
            ],
          ),
      ];
    case LibrarySection.notes:
      return [for (final n in take(ref.watch(notesProvider))) _NoteTile(note: n)];
    case LibrarySection.audio:
      return savedOfTypes({ContentType.audio});
    case LibrarySection.videos:
      return savedOfTypes({ContentType.video});
    case LibrarySection.messages:
      return savedOfTypes({ContentType.article, ContentType.scriptureReference});
    case LibrarySection.history:
      return [
        for (final h in take(ref.watch(readingHistoryProvider)))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.menu_book_outlined, color: c.textSecondary),
            title: Text(h.reference.label, style: t.cardTitle),
            subtitle: Text('${h.versionId} · ${formatRelative(h.readAt)}', style: t.caption),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            onTap: () => context.push(AppRoutes.reader(h.reference.bookId, h.reference.chapter)),
          ),
      ];
    case LibrarySection.viewed:
      return [
        for (final v in take(ref.watch(recentlyViewedProvider)))
          if (contentMap[v.contentId] case final item?) ContentListTile(item: item),
      ];
    case LibrarySection.drafts:
      return [
        for (final d in take(ref.watch(uploadDraftsProvider)))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.upload_file_outlined, color: c.primary),
            title: Text(d.title, style: t.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${d.kind.label} · Saved on this device · ${formatRelative(d.createdAt)}', style: t.caption),
            trailing: MwbIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete draft',
              onPressed: () async {
                final ok = await showMwbConfirmDialog(
                  context,
                  title: 'Delete this draft?',
                  message: '“${d.title}” will be removed from this device.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (ok) await ref.read(uploadDraftsProvider.notifier).delete(d.id);
              },
            ),
          ),
      ];
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final VerseNote note;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Semantics(
      button: true,
      label: 'Note on ${note.reference.label}: ${note.text}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: MwbRadius.mdAll,
        onTap: () => showNoteEditor(context, reference: note.reference, existing: note),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(note.reference.label.toUpperCase(), style: t.scriptureReference)),
                  Text(formatRelative(note.updatedAt), style: t.caption),
                ],
              ),
              const SizedBox(height: 4),
              Text(note.text, style: t.body, maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
