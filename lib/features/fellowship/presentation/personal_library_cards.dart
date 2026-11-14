import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../../data/models/scripture_reference.dart';
import '../application/personal_providers.dart';
import 'journal_screen.dart';

/// Library → Scripture: the Reflections section (latest two, then "See all").
class ReflectionsLibrarySection extends ConsumerWidget {
  const ReflectionsLibrarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(journalRepositoryProvider) == null) return const SizedBox.shrink();
    final count = ref.watch(journalCountProvider);
    final latest = ref.watch(journalSearchProvider(const JournalQuery())).take(2).toList();
    final t = context.mwb.text;
    return Column(
      key: const Key('library.reflections'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MwbSectionHeading(
          title: 'Reflections',
          subtitle: count == 0 ? 'Private, encrypted on this device' : '$count · private, encrypted on this device',
          actionLabel: 'See all',
          onAction: () => context.push(AppRoutes.journal),
        ),
        const SizedBox(height: MwbSpace.sm),
        if (latest.isEmpty)
          Text('Choose Reflect in the reader, the Daily Word or a saved verse.', style: t.caption)
        else
          for (final e in latest) ...[ReflectionTile(entry: e), const SizedBox(height: MwbSpace.xs)],
        const SizedBox(height: MwbSpace.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: MwbTextButton(
            key: const Key('library.newReflection'),
            label: 'New reflection',
            icon: Icons.add_rounded,
            onPressed: () => context.push(AppRoutes.newReflection()),
          ),
        ),
      ],
    );
  }
}

/// Library → History: completed readings from the Word rhythm.
class RhythmLibraryCard extends ConsumerWidget {
  const RhythmLibraryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(rhythmRepositoryProvider) == null) return const SizedBox.shrink();
    final n = ref.watch(completedReadingsProvider).length;
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: const Key('library.rhythm'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.event_available_outlined, color: c.primary),
        title: Text('Completed readings', style: t.cardTitle),
        subtitle: Text(
          n == 0 ? 'Readings you mark complete appear in your Word rhythm' : '$n in your Word rhythm',
          style: t.caption,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.rhythm),
      ),
    );
  }
}

/// Saved Scripture row action: reflect on this verse, with a count of
/// existing reflections on it.
class ReflectOnSavedButton extends ConsumerWidget {
  const ReflectOnSavedButton({super.key, required this.reference, required this.versionId});
  final ScriptureReference reference;
  final String versionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(journalRepositoryProvider) == null) return const SizedBox.shrink();
    final existing = ref.watch(reflectionsForReferenceProvider(reference));
    return Align(
      alignment: Alignment.centerLeft,
      child: MwbTextButton(
        key: Key('saved.reflect.${reference.key}'),
        icon: existing.isEmpty ? Icons.edit_note_rounded : Icons.speaker_notes_outlined,
        label: existing.isEmpty
            ? 'Reflect'
            : '${existing.length} ${existing.length == 1 ? 'reflection' : 'reflections'}',
        onPressed: () async {
          final newRoute = AppRoutes.newReflection(
            reference: reference,
            versionId: versionId,
            source: PersonalOrigin.savedScripture,
          );
          if (existing.isEmpty) {
            context.push(newRoute);
            return;
          }
          final route = await showMwbSheet<String>(
            context,
            title: 'Reflections on ${reference.label}',
            builder: (ctx) => Column(
              children: [
                for (final e in existing)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_note_rounded),
                    title: Text(e.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(ctx).pop(AppRoutes.journalEntry(e.id)),
                  ),
                ListTile(
                  key: const Key('saved.reflect.new'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Write another reflection'),
                  onTap: () => Navigator.of(ctx).pop(newRoute),
                ),
              ],
            ),
          );
          if (route != null && context.mounted) context.push(route);
        },
      ),
    );
  }
}
