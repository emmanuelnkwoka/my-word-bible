import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/content.dart';
import '../../../data/models/topic.dart';
import '../../bible/widgets/scripture_card.dart';
import '../../content/widgets/content_cards.dart';
import '../../creator/widgets/creator_widgets.dart';
import '../application/content_providers.dart';
import '../application/discover_filter.dart';

/// A topic page brings together Scripture, audio, video, articles,
/// creators and related topics — the core MWB discovery pattern.
class TopicScreen extends ConsumerStatefulWidget {
  const TopicScreen({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends ConsumerState<TopicScreen> {
  ContentFilter _filter = ContentFilter.all;

  @override
  Widget build(BuildContext context) {
    final topic = ref.watch(topicProvider(widget.topicId));
    return Scaffold(
      appBar: AppBar(title: Text(topic.value?.name ?? '')),
      body: AsyncValueView<Topic>(
        value: topic,
        onRetry: () => ref.invalidate(topicProvider(widget.topicId)),
        data: (t) => _TopicBody(topic: t, filter: _filter, onFilter: (f) => setState(() => _filter = f)),
      ),
    );
  }
}

class _TopicBody extends ConsumerWidget {
  const _TopicBody({required this.topic, required this.filter, required this.onFilter});

  final Topic topic;
  final ContentFilter filter;
  final ValueChanged<ContentFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final gutter = MwbLayout.pagePadding(context);
    final content = ref.watch(topicContentProvider(topic.id));
    final creators = ref.watch(creatorsProvider);
    final allTopics = ref.watch(topicsProvider).value ?? const <Topic>[];
    final related = allTopics.where((x) => topic.relatedTopicIds.contains(x.id)).toList();

    return CustomScrollView(
      slivers: [
        MwbSliverPadding(
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOPIC', style: t.overline),
                const SizedBox(height: 4),
                Semantics(header: true, child: Text(topic.name, style: t.display)),
                const SizedBox(height: MwbSpace.xs),
                Text(topic.summary, style: t.body.copyWith(color: context.mwb.colors.textSecondary)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: MwbSpace.lg),
            child: MwbChipRow(
              padding: gutter,
              children: [
                for (final f in ContentFilter.values)
                  MwbChip(
                    key: Key('topic.filter.${f.name}'),
                    label: f.label,
                    selected: filter == f,
                    count: _countFor(f, content.value),
                    onTap: () => onFilter(f),
                  ),
              ],
            ),
          ),
        ),
        if (filter.showsScripture) ...[
          MwbSliverPadding(
            top: MwbSpace.xl,
            sliver: SliverToBoxAdapter(
              child: MwbSectionHeading(
                overline: 'Scripture',
                title: 'What the Bible says',
                subtitle: '${topic.keyScriptures.length} passages · King James Version',
              ),
            ),
          ),
          MwbSliverPadding(
            top: MwbSpace.xs,
            sliver: SliverList.separated(
              itemCount: topic.keyScriptures.length,
              separatorBuilder: (_, _) => Divider(color: context.mwb.colors.divider, height: 1),
              itemBuilder: (_, i) => ScriptureSnippetTile(reference: topic.keyScriptures[i]),
            ),
          ),
        ],
        ...switch (content) {
          AsyncData(:final value) => [
            for (final type in [
              ContentType.audio,
              ContentType.video,
              ContentType.article,
              ContentType.scriptureReference,
            ])
              if ((filter.type == null || filter.type == type) && value.any((c) => c.type == type)) ...[
                MwbSliverPadding(
                  top: MwbSpace.xl,
                  sliver: SliverToBoxAdapter(
                    child: MwbSectionHeading(
                      overline: type.label,
                      title: switch (type) {
                        ContentType.audio => 'Audio messages',
                        ContentType.video => 'Video excerpts',
                        ContentType.article => 'Articles',
                        ContentType.scriptureReference => 'Scripture collections',
                      },
                    ),
                  ),
                ),
                MwbSliverPadding(
                  top: MwbSpace.xs,
                  sliver: SliverList.list(
                    children: [for (final c in value.where((c) => c.type == type)) ContentListTile(item: c)],
                  ),
                ),
              ],
            if (filter.type != null && filter.type != ContentType.scriptureReference && !value.any(filter.matches))
              const SliverToBoxAdapter(
                child: MwbEmptyState(
                  compact: true,
                  title: 'Nothing here yet',
                  message: 'There is no content of this type for this topic yet.',
                ),
              ),
          ],
          AsyncError(:final error) => [
            SliverToBoxAdapter(
              child: MwbErrorState(error: error, onRetry: () => ref.invalidate(topicContentProvider(topic.id))),
            ),
          ],
          _ => [const SliverToBoxAdapter(child: MwbLoadingState(compact: true))],
        },
        if (filter == ContentFilter.all) ...[
          if (creators.value case final list?)
            if (list.where((c) => c.topicIds.contains(topic.id)).isNotEmpty) ...[
              const MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(
                  child: MwbSectionHeading(overline: 'Voices', title: 'Teachers on this topic'),
                ),
              ),
              MwbSliverPadding(
                top: MwbSpace.xs,
                sliver: SliverList.list(
                  children: [for (final c in list.where((c) => c.topicIds.contains(topic.id))) CreatorTile(creator: c)],
                ),
              ),
            ],
          if (related.isNotEmpty) ...[
            const MwbSliverPadding(
              top: MwbSpace.xl,
              sliver: SliverToBoxAdapter(
                child: MwbSectionHeading(overline: 'Keep exploring', title: 'Related topics'),
              ),
            ),
            MwbSliverPadding(
              top: MwbSpace.sm,
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: MwbSpace.xs,
                  runSpacing: MwbSpace.xs,
                  children: [
                    for (final r in related) MwbChip(label: r.name, onTap: () => context.push(AppRoutes.topic(r.id))),
                  ],
                ),
              ),
            ),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: MwbSpace.xxxl)),
      ],
    );
  }

  int? _countFor(ContentFilter f, List<ContentItem>? items) {
    if (items == null) return null;
    if (f == ContentFilter.all) return items.length + topic.keyScriptures.length;
    if (f == ContentFilter.scripture) {
      return topic.keyScriptures.length + items.where((c) => c.type == ContentType.scriptureReference).length;
    }
    return items.where(f.matches).length;
  }
}
