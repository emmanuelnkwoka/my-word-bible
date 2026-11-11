import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/scripture_reference.dart';
import '../../library/application/library_controllers.dart';
import '../application/bible_providers.dart';

/// Text used when sharing Scripture. Always includes reference and version.
String scriptureShareText(Passage passage, String versionAbbreviation) {
  final text = passage.verses.length == 1
      ? passage.verses.first.text
      : passage.verses.map((v) => '${v.number} ${v.text}').join(' ');
  return '“$text”\n— ${passage.reference.label} ($versionAbbreviation)\n\nShared from My Word Bible';
}

Future<void> copyScripture(BuildContext context, Passage passage, String version) async {
  await Clipboard.setData(ClipboardData(text: scriptureShareText(passage, version)));
  if (context.mounted) showMwbSnack(context, '${passage.reference.label} copied — ready to share');
}

/// Displays canonical Scripture with its source.
///
/// [personalLine] is an optional personal framing ("For you today, Ada")
/// shown *above* the passage. The canonical text itself is never altered.
class ScriptureCard extends ConsumerWidget {
  const ScriptureCard({
    super.key,
    required this.reference,
    this.overline,
    this.personalLine,
    this.footer,
    this.showActions = true,
    this.large = false,
    this.maxLines,
  });

  final ScriptureReference reference;
  final String? overline;
  final String? personalLine;
  final Widget? footer;
  final bool showActions;
  final bool large;
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final version = ref.watch(activeVersionProvider);
    final passage = ref.watch(passageProvider(reference));
    return MwbCard(
      padding: EdgeInsets.all(large ? MwbSpace.xl : MwbSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Text(overline!.toUpperCase(), style: t.overline),
            const SizedBox(height: MwbSpace.sm),
          ],
          if (personalLine != null) ...[
            Text(personalLine!, style: t.supporting.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: MwbSpace.sm),
          ],
          AsyncValueView<Passage>(
            value: passage,
            compact: true,
            onRetry: () => ref.invalidate(passageProvider(reference)),
            data: (p) => Semantics(
              label: '${p.reference.label}, ${version.abbreviation}. ${p.text}',
              excludeSemantics: true,
              child: Text(
                p.verses.length == 1 ? p.verses.first.text : p.verses.map((v) => '${v.number} ${v.text}').join('  '),
                style: t.scripture.copyWith(fontSize: large ? 21 : 18, height: large ? 1.6 : 1.65),
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: MwbSpace.md),
          Row(
            children: [
              const MwbRule(width: 18),
              const SizedBox(width: MwbSpace.xs),
              Expanded(
                child: Text(
                  '${reference.label.toUpperCase()} · ${version.abbreviation}',
                  style: t.scriptureReference,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showActions && passage.hasValue) ...[
                _SaveScriptureButton(reference: reference, versionId: version.id),
                MwbIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Copy to share',
                  size: 20,
                  onPressed: () => copyScripture(context, passage.requireValue, version.abbreviation),
                ),
                MwbIconButton(
                  icon: Icons.arrow_outward_rounded,
                  tooltip: 'Open in Bible',
                  size: 20,
                  onPressed: () =>
                      context.push(AppRoutes.reader(reference.bookId, reference.chapter, verse: reference.verseStart)),
                ),
              ],
            ],
          ),
          if (footer != null) ...[Divider(height: MwbSpace.xl, color: c.divider), footer!],
        ],
      ),
    );
  }
}

class _SaveScriptureButton extends ConsumerWidget {
  const _SaveScriptureButton({required this.reference, required this.versionId});

  final ScriptureReference reference;
  final String versionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedScriptureProvider).any((s) => s.reference == reference);
    return MwbIconButton(
      icon: Icons.bookmark_border_rounded,
      selectedIcon: Icons.bookmark_rounded,
      selected: saved,
      size: 20,
      tooltip: saved ? 'Remove saved verse' : 'Save verse',
      onPressed: () async {
        HapticFeedback.lightImpact();
        final now = await ref.read(savedScriptureProvider.notifier).toggle(reference, versionId: versionId);
        if (context.mounted) {
          showMwbSnack(context, now ? 'Verse saved to your library' : 'Verse removed from your library');
        }
      },
    );
  }
}

/// A short reference + snippet row (topic pages, search results).
class ScriptureSnippetTile extends ConsumerWidget {
  const ScriptureSnippetTile({super.key, required this.reference, this.text});

  final ScriptureReference reference;

  /// Provide verse text when already loaded (e.g. search hits).
  final String? text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final version = ref.watch(activeVersionProvider);
    final loaded = text ?? ref.watch(passageProvider(reference)).value?.text;
    return Semantics(
      button: true,
      label: '${reference.label}. ${loaded ?? ''}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: MwbRadius.mdAll,
        onTap: () => context.push(AppRoutes.reader(reference.bookId, reference.chapter, verse: reference.verseStart)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${reference.label.toUpperCase()} · ${version.abbreviation}', style: t.scriptureReference),
              const SizedBox(height: 4),
              Text(
                loaded ?? '…',
                style: t.scripture.copyWith(fontSize: 16, height: 1.55),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
