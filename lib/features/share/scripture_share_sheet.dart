import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/mwb_tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/sheets.dart';
import '../../data/models/bible.dart';
import '../../data/models/scripture_reference.dart';
import '../../data/repositories/bible_repository.dart';
import '../personalisation/application/scripture_presentation.dart';
import '../personalisation/domain/presentation_layer_resolver.dart';
import '../personalisation/domain/rendered_verse.dart';
import '../social/presentation/send_scripture_screen.dart';
import 'export/card_export.dart';
import 'export/card_export_flow.dart';
import 'scripture_image_composer.dart';
import 'share_service.dart';
import 'studio/card_studio_screen.dart';

/// Builds what is shared from rendered verses, keeping the reader's name
/// marked so it can be set in gold.
ShareScripture shareScriptureFrom({
  required List<RenderedVerse> verses,
  required String reference,
  required String translation,
  String? title,
  String? titleName,
  bool numbered = false,
  bool preview = false,
  List<ScriptureReference> sources = const [],
  String? sourceVersionId,
  String? reception,
  String? receptionName,
}) => ShareScripture(
  reference: reference,
  translation: translation,
  title: title,
  titleName: titleName,
  numbered: numbered,
  preview: preview,
  sources: sources,
  sourceVersionId: sourceVersionId,
  reception: reception,
  receptionName: receptionName,
  personalised: verses.any((v) => v.segments.any((s) => s.kind == SegmentKind.personalisation)),
  verses: [
    for (final v in verses.where((v) => !v.source.isOmitted))
      ShareVerse(v.source.number, [
        for (final s in v.segments) ShareSpan(s.text, isName: s.kind == SegmentKind.personalisation),
      ]),
  ],
);

/// Canonical verses (no personalisation) as shareable Scripture.
ShareScripture shareScriptureFromVerses({
  required List<Verse> verses,
  required String reference,
  required String translation,
  String? title,
  String? sourceVersionId,
}) => ShareScripture(
  reference: reference,
  translation: translation,
  title: title,
  numbered: verses.length > 1,
  sources: referencesOf(verses),
  sourceVersionId: sourceVersionId,
  verses: [
    for (final v in verses.where((v) => !v.isOmitted)) ShareVerse(v.number, [ShareSpan(v.text)]),
  ],
);

/// Contiguous verses collapsed into references ("Romans 15:13–14", "15:16").
List<ScriptureReference> referencesOf(List<Verse> verses) {
  final out = <ScriptureReference>[];
  for (final v in verses) {
    final last = out.isEmpty ? null : out.last;
    final end = last?.verseEnd ?? last?.verseStart;
    if (last != null && last.bookId == v.bookId && last.chapter == v.chapter && end != null && end + 1 == v.number) {
      out[out.length - 1] = ScriptureReference(
        bookId: last.bookId,
        chapter: last.chapter,
        verseStart: last.verseStart,
        verseEnd: v.number,
      );
    } else {
      out.add(ScriptureReference(bookId: v.bookId, chapter: v.chapter, verseStart: v.number));
    }
  }
  return out;
}

/// A presented passage (Daily Word, Home) as shareable Scripture.
ShareScripture shareScriptureFromPresentation(ScripturePresentation p) => shareScriptureFrom(
  verses: p.verses,
  reference: p.reference.label,
  translation: p.translationLabel,
  title: p.title,
  titleName: p.titleName,
  numbered: p.verses.length > 1,
  preview: p.isPreview,
  sources: [p.reference],
  sourceVersionId: p.source.id,
  reception: p.receptions.isEmpty ? null : p.receptions.map((r) => r.text).join('\n\n'),
  receptionName: p.receptions.map((r) => r.name).nonNulls.firstOrNull,
);

/// Canonical Scripture for a reference (Discover, profiles, received shares).
Future<ShareScripture> loadShareScripture(BibleRepository bible, ScriptureReference reference, String versionId) async {
  final passage = await bible.passage(versionId, reference);
  final abbreviation = bible.versions.where((v) => v.id == versionId).firstOrNull?.abbreviation ?? versionId;
  final s = shareScriptureFromVerses(
    verses: passage.verses,
    reference: reference.label,
    translation: abbreviation,
    sourceVersionId: versionId,
  );
  return ShareScripture(
    verses: s.verses,
    reference: s.reference,
    translation: s.translation,
    numbered: s.numbered,
    sources: [reference],
    sourceVersionId: versionId,
  );
}

/// The text that accompanies shared images (and "Share as text").
SharePayload sharePayloadFor(ShareScripture s) {
  final body = s.verses.length == 1
      ? s.verses.single.text
      : s.verses.map((v) => v.number > 0 ? '${v.number} ${v.text}' : v.text).join(' ');
  final head = s.title == null ? '' : '${s.title}\n\n';
  final preview = s.preview ? '\n(Review preview — not an approved rendering)' : '';
  final reception = s.reception == null ? '' : '\n\nPersonal reception: ${s.reception}';
  return SharePayload(
    subject: '${s.reference} (${s.translation})',
    text: '$head“$body”\n— ${s.reference} (${s.translation})$preview$reception\n\nShared from My Word Bible',
  );
}

/// Share flow: the images are composed automatically from the selection and
/// shown for a moment before the native share sheet. No template step.
///
/// Quick share is unchanged. Below it, optional extras open the same
/// sharing engine in more depth: the Card Studio, sending to an MWB user,
/// saving the image, links, and sharing with encouragement.
Future<void> showScriptureShareSheet(BuildContext context, ShareScripture scripture) {
  return showMwbSheet<void>(
    context,
    title: scripture.reference,
    subtitle: scripture.translation,
    builder: (ctx) => _ShareSheetBody(scripture: scripture),
  );
}

class _ShareSheetBody extends ConsumerStatefulWidget {
  const _ShareSheetBody({required this.scripture});
  final ShareScripture scripture;

  @override
  ConsumerState<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends ConsumerState<_ShareSheetBody> {
  ShareFormat _format = ShareFormat.portrait;
  final Map<ShareFormat, Future<List<ShareImagePage>>> _pages = {};
  final _controller = PageController(viewportFraction: 0.86);
  int _page = 0;
  bool _sharing = false;

  Future<List<ShareImagePage>> _pagesFor(ShareFormat f) => _pages.putIfAbsent(
    f,
    () => const ScriptureImageComposer().compose(widget.scripture, f, ShareStyle.fromPalette(context.mwb.colors)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fileName(int i, int n) {
    final base = 'my-word-bible-${widget.scripture.reference.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    return n == 1 ? '$base.png' : '$base-${i + 1}-of-$n.png';
  }

  Future<void> _share(List<ShareImagePage> pages) async {
    setState(() => _sharing = true);
    try {
      final outcome = await ref
          .read(shareServiceProvider)
          .shareImages(
            [for (final p in pages) p.png],
            fileNames: [for (var i = 0; i < pages.length; i++) _fileName(i, pages.length)],
            payload: sharePayloadFor(widget.scripture),
          );
      if (!mounted) return;
      if (outcome == ShareOutcome.unavailable) showMwbSnack(context, 'Sharing is not available on this device.');
    } catch (_) {
      if (mounted) showMwbSnack(context, 'The images could not be shared. Please try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareText() async {
    try {
      await ref.read(shareServiceProvider).shareText(sharePayloadFor(widget.scripture));
    } catch (_) {
      if (mounted) showMwbSnack(context, 'This passage could not be shared.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final maxPreview = MediaQuery.sizeOf(context).height * 0.46;
    return FutureBuilder<List<ShareImagePage>>(
      key: ValueKey(_format),
      future: _pagesFor(_format),
      builder: (context, snap) {
        final pages = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: maxPreview,
              child: snap.hasError
                  ? Center(child: Text('The images could not be created.', style: t.supporting))
                  : pages == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                          ),
                          const SizedBox(height: MwbSpace.sm),
                          Text('Composing…', style: t.supporting),
                        ],
                      ),
                    )
                  : PageView.builder(
                      key: const Key('share.preview'),
                      controller: _controller,
                      itemCount: pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(borderRadius: MwbRadius.lgAll, boxShadow: c.softShadow),
                            child: ClipRRect(
                              borderRadius: MwbRadius.lgAll,
                              child: AspectRatio(
                                aspectRatio: pages[i].width / pages[i].height,
                                child: Image.memory(pages[i].png, fit: BoxFit.contain, gaplessPlayback: true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: MwbSpace.sm),
            Text(
              pages == null
                  ? ' '
                  : pages.length == 1
                  ? '1 image'
                  : 'Image ${_page + 1} of ${pages.length} · the whole passage is included',
              key: const Key('share.pageCount'),
              style: t.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MwbSpace.md),
            Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 6,
              children: [
                for (final f in ShareFormat.quick)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      key: Key('share.format.${f.name}'),
                      label: Text(f.label),
                      selected: _format == f,
                      showCheckmark: false,
                      labelStyle: t.label.copyWith(
                        color: _format == f ? c.primaryStrong : c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: c.selected,
                      backgroundColor: c.surfaceElevated,
                      side: BorderSide(color: _format == f ? c.primary.withValues(alpha: 0.4) : c.border),
                      shape: const StadiumBorder(),
                      onSelected: (_) => setState(() {
                        _format = f;
                        _page = 0;
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MwbSpace.md),
            MwbPrimaryButton(
              key: const Key('share.go'),
              label: pages != null && pages.length > 1 ? 'Share ${pages.length} images' : 'Share',
              icon: Icons.ios_share_rounded,
              loading: _sharing,
              onPressed: pages == null || _sharing ? null : () => _share(pages),
            ),
            const SizedBox(height: MwbSpace.xs),
            Center(
              child: TextButton(
                key: const Key('share.text'),
                onPressed: _shareText,
                child: Text(
                  'Share as text',
                  style: t.label.copyWith(color: c.primaryStrong, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: MwbSpace.sm),
            _MoreWaysToShare(scripture: widget.scripture, pages: pages, format: _format),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        );
      },
    );
  }
}

/// Optional extras under quick share. None is required to share.
class _MoreWaysToShare extends ConsumerStatefulWidget {
  const _MoreWaysToShare({required this.scripture, required this.pages, required this.format});
  final ShareScripture scripture;
  final List<ShareImagePage>? pages;
  final ShareFormat format;

  @override
  ConsumerState<_MoreWaysToShare> createState() => _MoreWaysToShareState();
}

class _MoreWaysToShareState extends ConsumerState<_MoreWaysToShare> {
  /// Inline result: snackbars would appear behind this sheet.
  String? _status;

  ShareScripture get scripture => widget.scripture;
  List<ShareImagePage>? get pages => widget.pages;
  ShareFormat get format => widget.format;

  Future<void> _save() async {
    setState(() => _status = 'Saving…');
    final result = await CardExportFlow.save(context, ref, pages: pages!, scripture: scripture);
    if (!mounted) return;
    setState(
      () => _status = switch (result.status) {
        ExportStatus.saved => pages!.length == 1
            ? 'Saved to Photos · Pictures/My Word Bible'
            : 'Saved ${pages!.length} images to Photos · Pictures/My Word Bible',
        ExportStatus.permissionNeeded => 'Allow storage access, then tap Save image again.',
        ExportStatus.unsupported => null,
        _ => 'The image could not be saved.',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final navigator = Navigator.of(context, rootNavigator: true);

    void openStudio({bool encouragement = false}) {
      Navigator.of(context).pop();
      navigator.push(CardStudioScreen.route(scripture, format: format, encouragement: encouragement));
    }

    void sendInApp() {
      if (!scripture.isResolvable) {
        showMwbSnack(context, 'This passage can be shared as an image or text, but not sent in the app.');
        return;
      }
      Navigator.of(context).pop();
      navigator.push(SendScriptureScreen.route(scripture));
    }

    final items = <(Key, IconData, String, String, VoidCallback?)>[
      (const Key('share.studio'), Icons.auto_awesome_rounded, 'Card Studio', 'Premium designs', () => openStudio()),
      (const Key('share.toUser'), Icons.person_add_alt_1_rounded, 'Send to someone', 'An MWB user', sendInApp),
      (
        const Key('share.save'),
        Icons.download_rounded,
        'Save image',
        'To your Photos',
        pages == null
            ? null
            : _save,
      ),
      (
        const Key('share.encourage'),
        Icons.volunteer_activism_outlined,
        'With encouragement',
        'Add a personal note',
        () => openStudio(encouragement: true),
      ),
      (
        const Key('share.link'),
        Icons.link_rounded,
        'Share link',
        'Coming with accounts',
        () => showMwbInfoSheet(
          context,
          icon: Icons.link_rounded,
          title: 'Share links are not live yet',
          message:
              'Each Scripture you send in the app gets its own link (mywordbible.com/s/…). Links will open for '
              'other people once the My Word Bible sharing service and website are connected. Until then, send '
              'the card itself, or send it to someone in the app.',
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MORE WAYS TO SHARE', style: t.overline.copyWith(color: c.textSecondary)),
        const SizedBox(height: MwbSpace.xs),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MwbSpace.sm),
            child: Row(
              children: [
                Icon(
                  _status!.startsWith('Saved') ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: _status!.startsWith('Saved') ? c.success : c.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(_status!, key: const Key('share.saveStatus'), style: t.caption)),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - MwbSpace.xs) / 2;
            return Wrap(
              spacing: MwbSpace.xs,
              runSpacing: MwbSpace.xs,
              children: [
                for (final (key, icon, label, sub, onTap) in items)
                  SizedBox(
                    width: w,
                    child: Material(
                      color: c.surfaceElevated,
                      shape: RoundedRectangleBorder(borderRadius: MwbRadius.mdAll, side: BorderSide(color: c.border)),
                      child: InkWell(
                        key: key,
                        borderRadius: MwbRadius.mdAll,
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: MwbSpace.sm, vertical: 10),
                          child: Row(
                            children: [
                              Icon(icon, size: 20, color: onTap == null ? c.disabled : c.primary),
                              const SizedBox(width: MwbSpace.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: t.label.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      sub,
                                      style: t.caption.copyWith(fontSize: 11.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// [s] with the approved personal title and receptions of its verses
/// (from the shared r3 layer engine). Scripture is unchanged.
ShareScripture withEditorialLayers(ShareScripture s, List<VerseEditorialLayers> layers) {
  final title = layers.map((l) => l.title).nonNulls.firstOrNull;
  final receptions = layers.map((l) => l.reception).nonNulls.toList();
  if (title == null && receptions.isEmpty) return s;
  return ShareScripture(
    verses: s.verses,
    reference: s.reference,
    translation: s.translation,
    title: title?.text ?? s.title,
    titleName: title?.name ?? s.titleName,
    numbered: s.numbered,
    preview: s.preview,
    sources: s.sources,
    sourceVersionId: s.sourceVersionId,
    personalised: s.personalised,
    reception: receptions.isEmpty ? s.reception : receptions.map((r) => r.text).join('\n\n'),
    receptionName: receptions.map((r) => r.name).nonNulls.firstOrNull ?? s.receptionName,
  );
}
