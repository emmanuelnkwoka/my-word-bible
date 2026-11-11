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
import '../../../core/widgets/state_views.dart';
import '../../../data/models/content.dart';
import '../../../data/models/topic.dart';
import '../../content/widgets/content_cards.dart';
import '../../creator/widgets/creator_widgets.dart';
import '../../profile/application/profile_controllers.dart';
import '../application/content_providers.dart';
import '../application/discover_filter.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(discoverFilterProvider);
    final gutter = MwbLayout.pagePadding(context);
    final featured = ref.watch(featuredContentProvider);
    final recent = ref.watch(recentContentProvider);
    final all = ref.watch(allContentProvider);
    final interestTopics = ref.watch(interestTopicIdsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allContentProvider);
            ref.invalidate(featuredContentProvider);
            ref.invalidate(recentContentProvider);
            await ref.read(allContentProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              MwbSliverPadding(
                top: MwbSpace.lg,
                sliver: SliverToBoxAdapter(
                  child: MwbPageTitle(
                    overline: 'Explore',
                    title: 'Discover',
                    trailing: MwbIconButton(
                      icon: Icons.add_circle_outline_rounded,
                      tooltip: 'Share a message',
                      filled: true,
                      onPressed: () => context.push(AppRoutes.upload),
                    ),
                  ),
                ),
              ),
              MwbSliverPadding(
                top: MwbSpace.lg,
                sliver: SliverToBoxAdapter(
                  child: MwbSearchField(
                    hint: 'Search topics, messages, Scripture',
                    readOnly: true,
                    onTap: () => context.push(AppRoutes.search()),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: MwbSpace.md),
                  child: MwbChipRow(
                    padding: gutter,
                    children: [
                      for (final f in ContentFilter.values)
                        MwbChip(
                          key: Key('discover.filter.${f.name}'),
                          label: f.label,
                          selected: filter == f,
                          onTap: () => ref.read(discoverFilterProvider.notifier).set(f),
                        ),
                    ],
                  ),
                ),
              ),
              const MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(child: _TrendingTopics()),
              ),
              // Featured
              ..._section(
                context,
                overline: 'Featured',
                title: 'Featured resources',
                value: featured,
                filter: filter,
                padding: gutter,
                builder: (items) => SizedBox(
                  height: _featuredHeight(context),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: gutter,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: MwbSpace.md),
                    itemBuilder: (_, i) => SizedBox(
                      width: (MediaQuery.sizeOf(context).width * 0.82).clamp(260, 380),
                      child: FeaturedContentCard(item: items[i]),
                    ),
                  ),
                ),
              ),
              MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(
                  child: MwbSectionHeading(
                    overline: 'Browse',
                    title: 'Topics',
                    subtitle: 'Find Scripture, messages and teaching by theme',
                  ),
                ),
              ),
              const MwbSliverPadding(top: MwbSpace.md, sliver: _TopicGrid()),
              // Recommended
              ..._section(
                context,
                overline: interestTopics.isEmpty ? 'Popular' : 'For you',
                title: 'Recommended messages',
                value: all.whenData((items) {
                  final scored = [...items]
                    ..sort((a, b) {
                      int score(ContentItem c) =>
                          c.topicIds.where(interestTopics.contains).length * 1000 + c.engagement.amens ~/ 10;
                      return score(b).compareTo(score(a));
                    });
                  return scored.where((c) => c.type != ContentType.scriptureReference).take(6).toList();
                }),
                filter: filter,
                padding: gutter,
                builder: (items) => Padding(
                  padding: gutter,
                  child: Column(children: [for (final i in items) ContentListTile(item: i)]),
                ),
              ),
              ..._section(
                context,
                overline: 'New',
                title: 'Recently added',
                value: recent,
                filter: filter,
                padding: gutter,
                builder: (items) => ContentCarousel(items: items, padding: gutter),
              ),
              if (filter == ContentFilter.all || filter == ContentFilter.scripture)
                ..._section(
                  context,
                  overline: 'Scripture',
                  title: 'Scripture collections',
                  value: all.whenData((items) => items.where((c) => c.type == ContentType.scriptureReference).toList()),
                  filter: ContentFilter.all,
                  padding: gutter,
                  builder: (items) => Padding(
                    padding: gutter,
                    child: Column(children: [for (final i in items) ContentListTile(item: i)]),
                  ),
                ),
              MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: const SliverToBoxAdapter(
                  child: MwbSectionHeading(overline: 'Voices', title: 'Creators and ministries'),
                ),
              ),
              const SliverToBoxAdapter(child: _CreatorsRow()),
              const SliverToBoxAdapter(child: SizedBox(height: MwbSpace.xxxl)),
            ],
          ),
        ),
      ),
    );
  }

  double _featuredHeight(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width * 0.82).clamp(260.0, 380.0);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return w / 2 + 196 * scale;
  }

  List<Widget> _section(
    BuildContext context, {
    required String overline,
    required String title,
    required AsyncValue<List<ContentItem>> value,
    required ContentFilter filter,
    required EdgeInsets padding,
    required Widget Function(List<ContentItem>) builder,
  }) {
    final filtered = value.whenData((items) => applyFilter(items, filter));
    if (filtered case AsyncData(:final value) when value.isEmpty) return const [];
    return [
      MwbSliverPadding(
        top: MwbSpace.xl,
        sliver: SliverToBoxAdapter(
          child: MwbSectionHeading(overline: overline, title: title),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: MwbSpace.md),
          child: AsyncValueView<List<ContentItem>>(value: filtered, compact: true, data: builder),
        ),
      ),
    ];
  }
}

class _TrendingTopics extends ConsumerWidget {
  const _TrendingTopics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingTopicsProvider);
    final t = context.mwb.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRENDING NOW', style: t.overline),
        const SizedBox(height: MwbSpace.sm),
        AsyncValueView<List<Topic>>(
          value: trending,
          compact: true,
          data: (topics) => Wrap(
            spacing: MwbSpace.xs,
            runSpacing: MwbSpace.xs,
            children: [
              for (final topic in topics)
                MwbChip(
                  label: topic.name,
                  icon: Icons.trending_up_rounded,
                  onTap: () => context.push(AppRoutes.topic(topic.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicGrid extends ConsumerWidget {
  const _TopicGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(primaryTopicsProvider);
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return switch (topics) {
      AsyncData(:final value) => SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MwbLayout.gridColumns(context, minTileWidth: 150),
          mainAxisSpacing: MwbSpace.xs,
          crossAxisSpacing: MwbSpace.xs,
          mainAxisExtent: 76 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
        ),
        itemCount: value.length,
        itemBuilder: (context, i) {
          final topic = value[i];
          return MwbCard(
            key: Key('topic.${topic.id}'),
            padding: const EdgeInsets.symmetric(horizontal: MwbSpace.md, vertical: MwbSpace.sm),
            onTap: () => context.push(AppRoutes.topic(topic.id)),
            semanticLabel: '${topic.name} topic',
            child: Row(
              children: [
                Expanded(child: Text(topic.name, style: t.sectionHeading.copyWith(fontSize: 19), maxLines: 2)),
                Icon(Icons.arrow_outward_rounded, size: 16, color: c.primary),
              ],
            ),
          );
        },
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: MwbErrorState(error: error, compact: true, onRetry: () => ref.invalidate(topicsProvider)),
      ),
      _ => const SliverToBoxAdapter(child: MwbLoadingState(compact: true)),
    };
  }
}

class _CreatorsRow extends ConsumerWidget {
  const _CreatorsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creators = ref.watch(creatorsProvider);
    final padding = MwbLayout.pagePadding(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    return Padding(
      padding: const EdgeInsets.only(top: MwbSpace.md),
      child: AsyncValueView(
        value: creators,
        compact: true,
        data: (list) => SizedBox(
          height: 190 * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: MwbSpace.sm),
            itemBuilder: (_, i) => CreatorPreviewCard(creator: list[i]),
          ),
        ),
      ),
    );
  }
}
