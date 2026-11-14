import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible_canon.dart';
import '../../../data/models/personal_rhythm.dart';
import '../../bible/application/bible_providers.dart';
import '../../share/share_service.dart';
import '../application/journal_export.dart';
import '../application/personal_providers.dart';
import 'personal_widgets.dart';

/// Private Reflection Journal: list, search and filters.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _search = TextEditingController();
  var _query = const JournalQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(JournalQuery q) => setState(() => _query = q);

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final ready = ref.watch(journalRepositoryProvider) != null;
    final total = ref.watch(journalCountProvider);
    final entries = ref.watch(journalSearchProvider(_query));
    final books = ref.watch(journalBooksProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (ready && total > 0)
            MwbIconButton(
              key: const Key('journal.export'),
              icon: Icons.ios_share_rounded,
              tooltip: 'Export reflections',
              onPressed: () => exportReflections(context, ref),
            ),
          MwbIconButton(
            icon: Icons.shield_outlined,
            tooltip: 'Journal privacy',
            onPressed: () => context.push(AppRoutes.journalPrivacy),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
        children: [
          const MwbPageTitle(overline: 'Private to you', title: 'Reflections'),
          const SizedBox(height: MwbSpace.xs),
          Text('Your own words, encrypted on this device. Never shared unless you export them.', style: t.supporting),
          const SizedBox(height: MwbSpace.lg),
          const PersonalStoreNotice(),
          if (ready) ...[
            MwbPrimaryButton(
              key: const Key('journal.new'),
              label: 'New reflection',
              icon: Icons.add_rounded,
              onPressed: () => context.push(AppRoutes.newReflection()),
            ),
            if (total > 0) ...[
              const SizedBox(height: MwbSpace.lg),
              MwbSearchField(
                key: const Key('journal.search'),
                controller: _search,
                hint: 'Search your reflections',
                onChanged: (v) => _set(_query.copyWith(text: v)),
                onClear: () {
                  _search.clear();
                  _set(_query.copyWith(text: ''));
                },
              ),
              const SizedBox(height: MwbSpace.sm),
              MwbChipRow(
                padding: EdgeInsets.zero,
                children: [
                  MwbChip(
                    key: const Key('journal.filter.all'),
                    label: 'All',
                    selected: _query.source == null && _query.linked == null && _query.bookId == null,
                    onTap: () => _set(JournalQuery(text: _query.text)),
                  ),
                  MwbChip(
                    key: const Key('journal.filter.linked'),
                    label: 'On Scripture',
                    selected: _query.linked == true,
                    onTap: () => _set(_query.copyWith(linked: _query.linked == true ? null : true)),
                  ),
                  for (final o in const [PersonalOrigin.reader, PersonalOrigin.dailyWord, PersonalOrigin.independent])
                    MwbChip(
                      key: Key('journal.filter.${o.name}'),
                      label: switch (o) {
                        PersonalOrigin.reader => 'From the reader',
                        PersonalOrigin.dailyWord => 'Daily Word',
                        _ => 'Written on its own',
                      },
                      selected: _query.source == o,
                      onTap: () => _set(_query.copyWith(source: _query.source == o ? null : o)),
                    ),
                  if (books.isNotEmpty)
                    MwbChip(
                      key: const Key('journal.filter.book'),
                      icon: Icons.menu_book_outlined,
                      label: _query.bookId == null ? 'Book' : BibleCanon.byId(_query.bookId!)!.name,
                      selected: _query.bookId != null,
                      onTap: () => _pickBook(books),
                    ),
                ],
              ),
            ],
            const SizedBox(height: MwbSpace.lg),
            if (total == 0)
              const MwbEmptyState(
                compact: true,
                icon: Icons.edit_note_rounded,
                title: 'No reflections yet',
                message: 'Reflect from the Bible reader, the Daily Word or a saved verse, or write one on its own.',
              )
            else if (entries.isEmpty)
              const MwbEmptyState(
                compact: true,
                icon: Icons.search_off_rounded,
                title: 'Nothing matches',
                message: 'Try different words or clear the filters.',
              )
            else ...[
              Text(
                '${entries.length} ${entries.length == 1 ? 'reflection' : 'reflections'}',
                style: t.caption.copyWith(color: context.mwb.colors.textSecondary),
              ),
              const SizedBox(height: MwbSpace.xs),
              for (final e in entries) ...[ReflectionTile(entry: e), const SizedBox(height: MwbSpace.sm)],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickBook(List<String> books) async {
    final chosen = await showMwbSheet<String>(
      context,
      title: 'Reflections on',
      builder: (ctx) => Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Any book'),
            onTap: () => Navigator.of(ctx).pop(''),
          ),
          for (final id in books)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(BibleCanon.byId(id)!.name),
              selected: _query.bookId == id,
              onTap: () => Navigator.of(ctx).pop(id),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    _set(_query.copyWith(bookId: chosen.isEmpty ? null : chosen));
  }
}

/// One reflection in a list. Visibly personal writing, never set as Scripture.
class ReflectionTile extends StatelessWidget {
  const ReflectionTile({super.key, required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final d = entry.createdAt.toLocal();
    return MwbCard(
      key: Key('journal.entry.${entry.id}'),
      elevated: false,
      onTap: () => context.push(AppRoutes.journalEntry(entry.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d.day} ${monthName(d.month)} ${d.year}${entry.reference == null ? '' : ' · ${entry.reference!.label}'}',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ),
              Icon(Icons.lock_outline_rounded, size: 13, color: c.textSecondary),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.heading, style: t.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (entry.title.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.body,
              style: t.body.copyWith(color: c.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Exports every reflection after an explicit warning that the file is
/// not encrypted. The user picks the destination in the system share sheet.
Future<void> exportReflections(BuildContext context, WidgetRef ref) async {
  final format = await showMwbSheet<JournalExportFormat>(
    context,
    title: 'Export your reflections',
    subtitle:
        'The exported file is not encrypted. Anyone who can open it can read your reflections. '
        'You choose where it goes next.',
    builder: (ctx) => Column(
      children: [
        for (final f in JournalExportFormat.values)
          ListTile(
            key: Key('journal.export.${f.name}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(f == JournalExportFormat.text ? Icons.description_outlined : Icons.data_object_rounded),
            title: Text(f.label),
            onTap: () => Navigator.of(ctx).pop(f),
          ),
      ],
    ),
  );
  if (format == null || !context.mounted) return;
  final entries = ref.read(journalSearchProvider(const JournalQuery()));
  const exporter = JournalExporter();
  final now = ref.read(clockProvider)();
  final outcome = await ref
      .read(journalExportServiceProvider)
      .shareFile(
        exporter.build(entries, format, exportedAt: now),
        fileName: exporter.fileName(now, format),
        mimeType: format.mimeType,
      );
  if (context.mounted && outcome == ShareOutcome.unavailable) {
    showMwbSnack(context, 'Sharing is not available on this device');
  }
}
