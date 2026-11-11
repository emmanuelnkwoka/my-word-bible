import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_palette.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/bible_canon.dart';
import '../../../data/models/library_items.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/models/user_profile.dart';
import '../../library/application/library_controllers.dart';
import '../../library/presentation/note_editor.dart';
import '../../profile/application/profile_controllers.dart';
import '../application/bible_providers.dart';
import 'reader_sheets.dart';

/// Colours for the reader, which can differ from the app theme.
({Color background, Color text, Color secondary}) readerColors(ReadingSurface s, MwbPalette p) => switch (s) {
  ReadingSurface.theme => (background: p.background, text: p.textPrimary, secondary: p.textSecondary),
  ReadingSurface.paper => (
    background: const Color(0xFFFFFFFF),
    text: const Color(0xFF1E1A17),
    secondary: const Color(0xFF7A716A),
  ),
  ReadingSurface.sepia => (
    background: const Color(0xFFF4E8D4),
    text: const Color(0xFF45331F),
    secondary: const Color(0xFF8A735A),
  ),
  ReadingSurface.night => (
    background: const Color(0xFF0E0E10),
    text: const Color(0xFFD9D3CA),
    secondary: const Color(0xFF8C867E),
  ),
};

/// Contiguous runs of verse numbers → references ("John 3:16–18").
List<ScriptureReference> groupSelection(String bookId, int chapter, Set<int> verses) {
  final sorted = verses.toList()..sort();
  final out = <ScriptureReference>[];
  int? start;
  int? prev;
  for (final v in sorted) {
    if (start == null) {
      start = v;
    } else if (v != prev! + 1) {
      out.add(
        ScriptureReference(bookId: bookId, chapter: chapter, verseStart: start, verseEnd: prev == start ? null : prev),
      );
      start = v;
    }
    prev = v;
  }
  if (start != null) {
    out.add(
      ScriptureReference(bookId: bookId, chapter: chapter, verseStart: start, verseEnd: prev == start ? null : prev),
    );
  }
  return out;
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId, required this.chapter, this.focusVerse});

  final String bookId;
  final int chapter;
  final int? focusVerse;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late ScriptureReference _chapter;
  int? _focus;
  final Set<int> _selected = {};
  final Map<int, GlobalKey> _verseKeys = {};
  final _scroll = ScrollController();
  bool _pendingScroll = false;

  @override
  void initState() {
    super.initState();
    final book = BibleCanon.byId(widget.bookId);
    final ch = book == null ? 1 : widget.chapter.clamp(1, book.chapterCount);
    _chapter = ScriptureReference(bookId: book?.id ?? 'JHN', chapter: ch);
    _focus = widget.focusVerse;
    _pendingScroll = _focus != null;
    _recordHistory();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _recordHistory() {
    final version = ref.read(activeVersionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(readingHistoryProvider.notifier).record(_chapter, versionId: version.id);
    });
  }

  void _goTo(String bookId, int chapter, {int? verse}) {
    setState(() {
      _chapter = ScriptureReference(bookId: bookId, chapter: chapter);
      _selected.clear();
      _verseKeys.clear();
      _focus = verse;
      _pendingScroll = verse != null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _recordHistory();
  }

  ScriptureReference? get _previous {
    if (_chapter.chapter > 1) return ScriptureReference(bookId: _chapter.bookId, chapter: _chapter.chapter - 1);
    final i = BibleCanon.indexOf(_chapter.bookId);
    if (i <= 0) return null;
    final b = BibleCanon.books[i - 1];
    return ScriptureReference(bookId: b.id, chapter: b.chapterCount);
  }

  ScriptureReference? get _next {
    final book = BibleCanon.bookOrThrow(_chapter.bookId);
    if (_chapter.chapter < book.chapterCount) {
      return ScriptureReference(bookId: _chapter.bookId, chapter: _chapter.chapter + 1);
    }
    final i = BibleCanon.indexOf(_chapter.bookId);
    if (i >= BibleCanon.books.length - 1) return null;
    return ScriptureReference(bookId: BibleCanon.books[i + 1].id, chapter: 1);
  }

  void _toggleVerse(int n) {
    HapticFeedback.selectionClick();
    setState(() {
      _focus = null;
      _selected.contains(n) ? _selected.remove(n) : _selected.add(n);
    });
  }

  void _maybeScrollToFocus() {
    if (!_pendingScroll || _focus == null) return;
    _pendingScroll = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _verseKeys[_focus]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.25, duration: MwbMotion.slow, curve: MwbMotion.curve);
      }
    });
  }

  List<ScriptureReference> get _selectionRefs => groupSelection(_chapter.bookId, _chapter.chapter, _selected);

  @override
  Widget build(BuildContext context) {
    final palette = context.mwb.colors;
    final t = context.mwb.text;
    final prefs = ref.watch(readingPreferencesProvider);
    final colors = readerColors(prefs.surface, palette);
    final verses = ref.watch(chapterVersesProvider(_chapter));
    final version = ref.watch(activeVersionProvider);
    final book = BibleCanon.bookOrThrow(_chapter.bookId);
    final bookmarked = ref.watch(bookmarksProvider).any((b) => b.reference == _chapter);
    final darkSurface =
        prefs.surface == ReadingSurface.night || (prefs.surface == ReadingSurface.theme && palette.isDark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkSurface ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: _selected.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(_selected.clear);
        },
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            foregroundColor: colors.text,
            systemOverlayStyle: darkSurface ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            titleSpacing: 0,
            title: Semantics(
              button: true,
              label: '${_chapter.label}. Choose another book or chapter',
              excludeSemantics: true,
              child: TextButton(
                onPressed: () async {
                  final target = await showChapterPicker(context, current: _chapter);
                  if (target != null) _goTo(target.bookId, target.chapter);
                },
                style: TextButton.styleFrom(foregroundColor: colors.text, minimumSize: const Size(48, 48)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(_chapter.label, style: t.cardTitle.copyWith(color: colors.text, fontSize: 17)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more_rounded, size: 20, color: colors.secondary),
                  ],
                ),
              ),
            ),
            actions: [
              MwbIconButton(
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
                selected: bookmarked,
                tooltip: bookmarked ? 'Remove chapter bookmark' : 'Bookmark this chapter',
                onPressed: () async {
                  final now = await ref.read(bookmarksProvider.notifier).toggle(_chapter, versionId: version.id);
                  if (context.mounted) showMwbSnack(context, now ? '${_chapter.label} bookmarked' : 'Bookmark removed');
                },
              ),
              MwbIconButton(
                icon: Icons.text_fields_rounded,
                tooltip: 'Reading settings',
                onPressed: () => showReadingSettingsSheet(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: AsyncValueView<List<Verse>>(
            value: verses,
            loadingMessage: 'Opening ${_chapter.label}…',
            onRetry: () => ref.invalidate(chapterVersesProvider(_chapter)),
            data: (list) {
              _maybeScrollToFocus();
              return _ChapterBody(
                key: ValueKey(_chapter.key),
                scroll: _scroll,
                chapter: _chapter,
                book: book,
                verses: list,
                prefs: prefs,
                colors: colors,
                selected: _selected,
                focus: _focus,
                keyFor: (n) => _verseKeys.putIfAbsent(n, GlobalKey.new),
                onVerseTap: _toggleVerse,
                versionName: version.name,
                previous: _previous,
                next: _next,
                onNavigate: (r) => _goTo(r.bookId, r.chapter),
              );
            },
          ),
          bottomNavigationBar: AnimatedSwitcher(
            duration: MwbMotion.medium,
            transitionBuilder: (child, a) =>
                SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: child),
            child: _selected.isEmpty
                ? const SizedBox.shrink(key: ValueKey('none'))
                : _SelectionBar(
                    key: const ValueKey('bar'),
                    references: _selectionRefs,
                    versionId: version.id,
                    versionAbbreviation: version.abbreviation,
                    verses: verses.value ?? const [],
                    selected: _selected,
                    onDone: () => setState(_selected.clear),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ChapterBody extends ConsumerWidget {
  const _ChapterBody({
    super.key,
    required this.scroll,
    required this.chapter,
    required this.book,
    required this.verses,
    required this.prefs,
    required this.colors,
    required this.selected,
    required this.focus,
    required this.keyFor,
    required this.onVerseTap,
    required this.versionName,
    required this.previous,
    required this.next,
    required this.onNavigate,
  });

  final ScrollController scroll;
  final ScriptureReference chapter;
  final CanonBook book;
  final List<Verse> verses;
  final ReadingPreferences prefs;
  final ({Color background, Color text, Color secondary}) colors;
  final Set<int> selected;
  final int? focus;
  final GlobalKey Function(int) keyFor;
  final ValueChanged<int> onVerseTap;
  final String versionName;
  final ScriptureReference? previous;
  final ScriptureReference? next;
  final ValueChanged<ScriptureReference> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final p = context.mwb.colors;
    final highlights = ref.watch(chapterHighlightsProvider(chapter));
    final notes = ref.watch(chapterNotesProvider(chapter));
    final tones = (prefs.surface == ReadingSurface.night ? MwbPalette.darkHighlightTones : p.highlightTones);
    final fontSize = prefs.textSize.fontSize;

    return SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: MwbSpace.xxxl),
      child: MwbConstrained(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: MwbSpace.lg),
            Text(book.name.toUpperCase(), style: t.overline.copyWith(color: p.primary)),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text('Chapter ${chapter.chapter}', style: t.display.copyWith(color: colors.text)),
            ),
            const SizedBox(height: MwbSpace.xs),
            const MwbRule(),
            const SizedBox(height: MwbSpace.xl),
            for (final v in verses)
              _VerseView(
                key: keyFor(v.number),
                verse: v,
                fontSize: fontSize,
                showNumber: prefs.showVerseNumbers,
                textColor: colors.text,
                numberColor: p.primary,
                highlight: highlights[v.number] == null ? null : tones[highlights[v.number]!.index],
                selected: selected.contains(v.number),
                focused: focus == v.number,
                hasNote: notes.contains(v.number),
                selectionColor: p.primary,
                onTap: () => onVerseTap(v.number),
                onNoteTap: () => _openNotes(context, ref, v),
              ),
            const SizedBox(height: MwbSpace.xl),
            Text('$versionName · Public domain', style: t.caption.copyWith(color: colors.secondary)),
            const SizedBox(height: MwbSpace.xl),
            Row(
              children: [
                Expanded(
                  child: previous == null
                      ? const SizedBox.shrink()
                      : _ChapterNavButton(
                          label: previous!.label,
                          caption: 'Previous',
                          alignEnd: false,
                          color: colors.text,
                          onTap: () => onNavigate(previous!),
                        ),
                ),
                const SizedBox(width: MwbSpace.sm),
                Expanded(
                  child: next == null
                      ? const SizedBox.shrink()
                      : _ChapterNavButton(
                          label: next!.label,
                          caption: 'Next',
                          alignEnd: true,
                          color: colors.text,
                          onTap: () => onNavigate(next!),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openNotes(BuildContext context, WidgetRef ref, Verse v) {
    final notes = ref
        .read(notesProvider)
        .where(
          (n) =>
              n.reference.bookId == v.bookId && n.reference.chapter == v.chapter && n.reference.verseStart == v.number,
        )
        .toList();
    if (notes.isEmpty) return;
    showNoteEditor(context, reference: notes.first.reference, existing: notes.first);
  }
}

class _VerseView extends StatelessWidget {
  const _VerseView({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.showNumber,
    required this.textColor,
    required this.numberColor,
    required this.highlight,
    required this.selected,
    required this.focused,
    required this.hasNote,
    required this.selectionColor,
    required this.onTap,
    required this.onNoteTap,
  });

  final Verse verse;
  final double fontSize;
  final bool showNumber;
  final Color textColor;
  final Color numberColor;
  final Color? highlight;
  final bool selected;
  final bool focused;
  final bool hasNote;
  final Color selectionColor;
  final VoidCallback onTap;
  final VoidCallback onNoteTap;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final bg = highlight ?? (focused ? selectionColor.withValues(alpha: 0.10) : Colors.transparent);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Verse ${verse.number}. ${verse.text}${hasNote ? '. Has a note' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MwbMotion.fast,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text.rich(
            TextSpan(
              children: [
                if (showNumber)
                  TextSpan(
                    text: '${verse.number}  ',
                    style: t.caption.copyWith(
                      color: numberColor,
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize * 0.62,
                    ),
                  ),
                TextSpan(
                  text: verse.text,
                  style: t.scripture.copyWith(
                    color: textColor,
                    fontSize: fontSize,
                    decoration: selected ? TextDecoration.underline : null,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: selectionColor,
                    decorationThickness: 2,
                  ),
                ),
                if (hasNote)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: onNoteTap,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.sticky_note_2_outlined, size: fontSize * 0.85, color: numberColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterNavButton extends StatelessWidget {
  const _ChapterNavButton({
    required this.label,
    required this.caption,
    required this.alignEnd,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool alignEnd;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final p = context.mwb.colors;
    return Semantics(
      button: true,
      label: '$caption chapter, $label',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: MwbRadius.mdAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(MwbSpace.sm),
          decoration: BoxDecoration(
            borderRadius: MwbRadius.mdAll,
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!alignEnd) Icon(Icons.arrow_back_rounded, size: 14, color: p.primary),
                  Text(' ${caption.toUpperCase()} ', style: t.overline.copyWith(fontSize: 10)),
                  if (alignEnd) Icon(Icons.arrow_forward_rounded, size: 14, color: p.primary),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: t.cardTitle.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({
    super.key,
    required this.references,
    required this.versionId,
    required this.versionAbbreviation,
    required this.verses,
    required this.selected,
    required this.onDone,
  });

  final List<ScriptureReference> references;
  final String versionId;
  final String versionAbbreviation;
  final List<Verse> verses;
  final Set<int> selected;
  final VoidCallback onDone;

  List<ScriptureReference> get _singleVerses => [
    for (final n in selected)
      ScriptureReference(bookId: references.first.bookId, chapter: references.first.chapter, verseStart: n),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.mwb.colors;
    final t = context.mwb.text;
    final label = references.map((r) => r.label).join(', ');

    Future<void> run(Future<void> Function() action, String message) async {
      await action();
      if (context.mounted) showMwbSnack(context, message);
      onDone();
    }

    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.border_color_outlined,
        'Highlight',
        () async {
          final tone = await showHighlightPicker(context);
          if (tone == null) return;
          if (tone == HighlightPickerResult.remove) {
            await run(() => ref.read(highlightsProvider.notifier).removeAll(_singleVerses), 'Highlight removed');
          } else {
            await run(
              () => ref.read(highlightsProvider.notifier).setTone(_singleVerses, HighlightTone.values[tone.index]),
              'Highlighted',
            );
          }
        },
      ),
      (
        Icons.bookmark_add_outlined,
        'Bookmark',
        () => run(
          () => ref.read(bookmarksProvider.notifier).add(references.first, versionId: versionId),
          '${references.first.label} bookmarked',
        ),
      ),
      (
        Icons.edit_note_rounded,
        'Note',
        () async {
          final first = references.first;
          final last = references.last;
          final range = ScriptureReference(
            bookId: first.bookId,
            chapter: first.chapter,
            verseStart: first.verseStart,
            verseEnd: (last.verseEnd ?? last.verseStart) == first.verseStart
                ? null
                : (last.verseEnd ?? last.verseStart),
          );
          await showNoteEditor(context, reference: range);
          onDone();
        },
      ),
      (
        Icons.favorite_border_rounded,
        'Save',
        () => run(() async {
          final saved = ref.read(savedScriptureProvider.notifier);
          for (final r in references) {
            if (!saved.isSaved(r)) await saved.toggle(r, versionId: versionId);
          }
        }, 'Saved to your library'),
      ),
      (
        Icons.copy_rounded,
        'Copy',
        () async {
          final chosen = verses.where((v) => selected.contains(v.number)).toList();
          final text = chosen.length == 1 ? chosen.first.text : chosen.map((v) => '${v.number} ${v.text}').join(' ');
          await Clipboard.setData(
            ClipboardData(text: '“$text”\n— $label ($versionAbbreviation)\n\nShared from My Word Bible'),
          );
          if (context.mounted) showMwbSnack(context, 'Copied — ready to share');
          onDone();
        },
      ),
    ];

    return Material(
      color: p.surfaceElevated,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MwbSpace.md, MwbSpace.xs, MwbSpace.xs, MwbSpace.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: t.label.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    MwbIconButton(icon: Icons.close_rounded, tooltip: 'Clear selection', onPressed: onDone),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final a in actions)
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: a.$2,
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: MwbRadius.mdAll,
                            onTap: a.$3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: MwbSpace.xs),
                              child: Column(
                                children: [
                                  Icon(a.$1, color: p.primary, size: 22),
                                  const SizedBox(height: 4),
                                  Text(a.$2, style: t.caption.copyWith(color: p.textPrimary), maxLines: 1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
