import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/creator.dart';
import '../../content/widgets/content_cards.dart';
import '../../discovery/application/content_providers.dart';

/// Creator profile preview: identity, focus topics and shared content.
class CreatorScreen extends ConsumerWidget {
  const CreatorScreen({super.key, required this.creatorId});

  final String creatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creator = ref.watch(creatorProvider(creatorId));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncValueView<Creator>(
        value: creator,
        onRetry: () => ref.invalidate(creatorProvider(creatorId)),
        data: (c) => _CreatorBody(creator: c),
      ),
    );
  }
}

class _CreatorBody extends ConsumerWidget {
  const _CreatorBody({required this.creator});
  final Creator creator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final content = ref.watch(creatorContentProvider(creator.id));
    final topics = (ref.watch(topicsProvider).value ?? const []).where((x) => creator.topicIds.contains(x.id)).toList();

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: t.sectionHeading.copyWith(fontSize: 22)),
          Text(label, style: t.caption),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: MwbSpace.xxxl),
      child: MwbConstrained(
        child: Column(
          children: [
            const SizedBox(height: MwbSpace.md),
            MwbAvatar(initials: creator.initials, size: 88),
            const SizedBox(height: MwbSpace.md),
            Semantics(
              header: true,
              child: Text(creator.displayName, style: t.pageHeading, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Text(creator.role, style: t.supporting),
            if (creator.isSample) ...[const SizedBox(height: MwbSpace.xs), const SampleBadge(label: 'Sample creator')],
            const SizedBox(height: MwbSpace.lg),
            MwbCard(
              child: Row(
                children: [
                  stat(content.value == null ? '–' : '${content.value!.length}', 'Messages'),
                  Container(width: 1, height: 32, color: c.divider),
                  stat(creator.followerCount == 0 ? '–' : formatCompact(creator.followerCount), 'Followers'),
                  Container(width: 1, height: 32, color: c.divider),
                  stat('${creator.topicIds.length}', 'Topics'),
                ],
              ),
            ),
            const SizedBox(height: MwbSpace.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(creator.bio, style: t.body),
            ),
            const SizedBox(height: MwbSpace.md),
            const MwbNotice(
              message:
                  'Following creators and creator verification arrive with MWB accounts. '
                  'Sample creators are fictional and illustrate the experience.',
            ),
            if (topics.isNotEmpty) ...[
              const SizedBox(height: MwbSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: MwbSpace.xs,
                  runSpacing: MwbSpace.xs,
                  children: [
                    for (final topic in topics)
                      MwbChip(label: topic.name, onTap: () => context.push(AppRoutes.topic(topic.id))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MwbSpace.xl),
            const MwbSectionHeading(overline: 'Library', title: 'Shared messages'),
            const SizedBox(height: MwbSpace.xs),
            AsyncValueView(
              value: content,
              compact: true,
              onRetry: () => ref.invalidate(creatorContentProvider(creator.id)),
              data: (items) => items.isEmpty
                  ? const MwbEmptyState(
                      compact: true,
                      title: 'No messages yet',
                      message: 'Shared messages will appear here.',
                    )
                  : Column(children: [for (final i in items) ContentListTile(item: i)]),
            ),
          ],
        ),
      ),
    );
  }
}
