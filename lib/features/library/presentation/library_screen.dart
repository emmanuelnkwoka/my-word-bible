import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../content/presentation/content_actions.dart';
import '../application/library_controllers.dart';
import 'library_sections.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MwbConstrained(
                child: Padding(
                  padding: const EdgeInsets.only(top: MwbSpace.lg, bottom: MwbSpace.sm),
                  child: MwbPageTitle(
                    overline: 'Your collection',
                    title: 'Library',
                    trailing: MwbIconButton(
                      icon: Icons.search_rounded,
                      tooltip: 'Search your library and more',
                      filled: true,
                      onPressed: () => context.push(AppRoutes.search()),
                    ),
                  ),
                ),
              ),
              MwbConstrained(
                padded: false,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.symmetric(horizontal: MwbLayout.gutter(context) - 12),
                  tabs: const [
                    Tab(text: 'Scripture'),
                    Tab(text: 'Media'),
                    Tab(text: 'Collections'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _SectionsTab(
                      sections: [
                        LibrarySection.verses,
                        LibrarySection.bookmarks,
                        LibrarySection.highlights,
                        LibrarySection.notes,
                      ],
                    ),
                    _SectionsTab(
                      sections: [
                        LibrarySection.audio,
                        LibrarySection.videos,
                        LibrarySection.messages,
                        LibrarySection.drafts,
                      ],
                      showDownloads: true,
                    ),
                    _CollectionsTab(),
                    _SectionsTab(sections: [LibrarySection.history, LibrarySection.viewed]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionsTab extends ConsumerWidget {
  const _SectionsTab({required this.sections, this.showDownloads = false});

  final List<LibrarySection> sections;
  final bool showDownloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: PageStorageKey(sections.first.slug),
      padding: MwbLayout.pagePadding(context, top: MwbSpace.lg, bottom: MwbSpace.xxxl),
      children: [
        for (final s in sections) ...[_SectionPreview(section: s), const SizedBox(height: MwbSpace.xl)],
        if (showDownloads)
          const MwbNotice(
            icon: Icons.download_for_offline_outlined,
            title: 'Downloads',
            message:
                'Offline downloads of audio and video will be available once MWB media hosting launches. '
                'Scripture (KJV) is already fully available offline.',
          ),
      ],
    );
  }
}

class _SectionPreview extends ConsumerWidget {
  const _SectionPreview({required this.section});
  final LibrarySection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final count = librarySectionCount(ref, section);
    final items = librarySectionItems(context, ref, section, limit: 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MwbSectionHeading(
          title: section.title,
          subtitle: count == 0 ? null : '$count ${count == 1 ? 'item' : 'items'}',
          actionLabel: count > 3 ? 'See all' : null,
          onAction: () => context.push(AppRoutes.librarySection(section.slug)),
        ),
        const SizedBox(height: MwbSpace.xs),
        if (count == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MwbSpace.md),
            decoration: BoxDecoration(
              borderRadius: MwbRadius.mdAll,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(section.icon, color: c.primary, size: 20),
                const SizedBox(width: MwbSpace.sm),
                Expanded(child: Text(section.emptyHint, style: t.supporting)),
              ],
            ),
          )
        else
          ...items,
      ],
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return ListView(
      key: const PageStorageKey('collections'),
      padding: MwbLayout.pagePadding(context, top: MwbSpace.lg, bottom: MwbSpace.xxxl),
      children: [
        MwbSecondaryButton(
          label: 'New collection',
          icon: Icons.add_rounded,
          onPressed: () async {
            final name = await showCollectionNameSheet(context);
            if (name != null) {
              await ref.read(collectionsProvider.notifier).create(name);
              if (context.mounted) showMwbSnack(context, 'Collection created');
            }
          },
        ),
        const SizedBox(height: MwbSpace.lg),
        if (collections.isEmpty)
          const MwbEmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: 'Gather what speaks to you',
            message: 'Create collections for messages on a theme, a study series or a season of prayer.',
          )
        else
          for (final col in collections)
            Padding(
              padding: const EdgeInsets.only(bottom: MwbSpace.sm),
              child: MwbCard(
                onTap: () => context.push(AppRoutes.collection(col.id)),
                semanticLabel: '${col.name}, ${col.contentIds.length} items',
                child: Row(
                  children: [
                    Icon(Icons.collections_bookmark_outlined, color: c.primary),
                    const SizedBox(width: MwbSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(col.name, style: t.cardTitle),
                          Text(
                            '${col.contentIds.length} ${col.contentIds.length == 1 ? 'item' : 'items'}',
                            style: t.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
