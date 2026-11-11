import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/segmented.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/bible_canon.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/models/user_profile.dart';
import '../../profile/application/profile_controllers.dart';

/// Text size, reading surface and verse number controls. Changes apply
/// immediately and persist.
Future<void> showReadingSettingsSheet(BuildContext context) {
  return showMwbSheet<void>(
    context,
    title: 'Reading settings',
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final prefs = ref.watch(readingPreferencesProvider);
        final ctrl = ref.read(readingPreferencesProvider.notifier);
        final t = ctx.mwb.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Text size', style: t.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: MwbSpace.xs),
            MwbSegmentedControl<ReadingTextSize>(
              options: ReadingTextSize.values,
              value: prefs.textSize,
              onChanged: (s) => ctrl.update((p) => p.copyWith(textSize: s)),
              labelOf: (s) => s == ReadingTextSize.extraLarge ? 'XL' : s.label,
            ),
            const SizedBox(height: MwbSpace.lg),
            Text('Reading surface', style: t.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: MwbSpace.xs),
            MwbSegmentedControl<ReadingSurface>(
              options: ReadingSurface.values,
              value: prefs.surface,
              onChanged: (s) => ctrl.update((p) => p.copyWith(surface: s)),
              labelOf: (s) => s.label,
            ),
            const SizedBox(height: MwbSpace.sm),
            MwbSwitchTile(
              title: 'Verse numbers',
              value: prefs.showVerseNumbers,
              onChanged: (v) => ctrl.update((p) => p.copyWith(showVerseNumbers: v)),
            ),
          ],
        );
      },
    ),
  );
}

enum HighlightPickerResult { gold, sage, sky, rose, remove }

Future<HighlightPickerResult?> showHighlightPicker(BuildContext context) {
  return showMwbSheet<HighlightPickerResult>(
    context,
    title: 'Highlight',
    builder: (ctx) {
      final p = ctx.mwb.colors;
      final tones = p.highlightTones;
      const names = ['Gold', 'Sage', 'Sky', 'Rose'];
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 4; i++)
            _ToneButton(
              color: tones[i],
              label: names[i],
              onTap: () => Navigator.of(ctx).pop(HighlightPickerResult.values[i]),
            ),
          _ToneButton(
            color: p.surface,
            label: 'Remove',
            icon: Icons.format_color_reset_outlined,
            onTap: () => Navigator.of(ctx).pop(HighlightPickerResult.remove),
          ),
        ],
      );
    },
  );
}

class _ToneButton extends StatelessWidget {
  const _ToneButton({required this.color, required this.label, required this.onTap, this.icon});
  final Color color;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mwb.colors;
    return Semantics(
      button: true,
      label: '$label highlight',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.border),
                ),
                child: icon == null ? null : Icon(icon, size: 20, color: p.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(label, style: context.mwb.text.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// Book → chapter quick picker. Returns the chosen chapter reference.
Future<ScriptureReference?> showChapterPicker(BuildContext context, {required ScriptureReference current}) {
  return showModalBottomSheet<ScriptureReference>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) => FractionallySizedBox(heightFactor: 0.85, child: _ChapterPicker(current: current)),
  );
}

class _ChapterPicker extends StatefulWidget {
  const _ChapterPicker({required this.current});
  final ScriptureReference current;

  @override
  State<_ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends State<_ChapterPicker> {
  CanonBook? _book;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final p = context.mwb.colors;
    final book = _book;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MwbSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (book != null)
                IconButton(
                  tooltip: 'Back to books',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _book = null),
                ),
              Expanded(child: Text(book?.name ?? 'Choose a book', style: t.sectionHeading)),
            ],
          ),
          const SizedBox(height: MwbSpace.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: MwbMotion.medium,
              child: book == null
                  ? ListView(
                      key: const ValueKey('books'),
                      children: [
                        for (final section in [
                          ('Old Testament', BibleCanon.oldTestament),
                          ('New Testament', BibleCanon.newTestament),
                        ]) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: MwbSpace.md, bottom: MwbSpace.xs),
                            child: Text(section.$1.toUpperCase(), style: t.overline),
                          ),
                          for (final b in section.$2)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                b.name,
                                style: t.label.copyWith(
                                  fontSize: 15,
                                  color: b.id == widget.current.bookId ? p.primary : p.textPrimary,
                                  fontWeight: b.id == widget.current.bookId ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                              trailing: Text('${b.chapterCount}', style: t.caption),
                              onTap: () => b.chapterCount == 1
                                  ? Navigator.of(context).pop(ScriptureReference(bookId: b.id, chapter: 1))
                                  : setState(() => _book = b),
                            ),
                        ],
                      ],
                    )
                  : GridView.builder(
                      key: ValueKey(book.id),
                      padding: const EdgeInsets.only(bottom: MwbSpace.xl),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 64,
                        mainAxisSpacing: MwbSpace.xs,
                        crossAxisSpacing: MwbSpace.xs,
                      ),
                      itemCount: book.chapterCount,
                      itemBuilder: (ctx, i) {
                        final isCurrent = book.id == widget.current.bookId && i + 1 == widget.current.chapter;
                        return Semantics(
                          button: true,
                          label: '${book.name} chapter ${i + 1}',
                          excludeSemantics: true,
                          child: Material(
                            color: isCurrent ? p.selected : p.surfaceElevated,
                            shape: RoundedRectangleBorder(
                              borderRadius: MwbRadius.mdAll,
                              side: BorderSide(color: isCurrent ? p.primary : p.border),
                            ),
                            child: InkWell(
                              borderRadius: MwbRadius.mdAll,
                              onTap: () =>
                                  Navigator.of(context).pop(ScriptureReference(bookId: book.id, chapter: i + 1)),
                              child: Center(child: Text('${i + 1}', style: t.cardTitle)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
