import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/content.dart';
import '../../../data/models/creator.dart';
import '../../audio/presentation/audio_player_panel.dart';
import '../../bible/widgets/scripture_card.dart';
import '../../creator/widgets/creator_widgets.dart';
import '../../discovery/application/content_providers.dart';
import '../../library/application/library_controllers.dart';
import '../../video/application/video_playback_controller.dart';
import '../../video/presentation/video_player_view.dart';
import '../widgets/content_artwork.dart';
import '../widgets/content_cards.dart';
import 'content_actions.dart';

class ContentDetailScreen extends ConsumerStatefulWidget {
  const ContentDetailScreen({super.key, required this.contentId});

  final String contentId;

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recentlyViewedProvider.notifier).record(widget.contentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(contentByIdProvider(widget.contentId));
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (item.value case final i?) ...[
            SaveContentButton(item: i),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) {
                final creator = ref.read(creatorMapProvider).value?[i.creatorId];
                switch (v) {
                  case 'collection':
                    showAddToCollectionSheet(context, i);
                  case 'share':
                    shareContent(context, i, creator);
                  case 'report':
                    showReportSheet(context, i);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'collection', child: Text('Add to collection')),
                PopupMenuItem(value: 'share', child: Text('Copy to share')),
                PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
          ],
        ],
      ),
      body: AsyncValueView<ContentItem>(
        value: item,
        onRetry: () => ref.invalidate(contentByIdProvider(widget.contentId)),
        data: (i) => _ContentBody(item: i),
      ),
    );
  }
}

class _ContentBody extends ConsumerStatefulWidget {
  const _ContentBody({required this.item});
  final ContentItem item;

  @override
  ConsumerState<_ContentBody> createState() => _ContentBodyState();
}

class _ContentBodyState extends ConsumerState<_ContentBody> {
  VideoPlaybackController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == ContentType.video) {
      _video = SimulatedVideoPlaybackController(duration: widget.item.duration ?? const Duration(minutes: 2));
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final creator = ref.watch(creatorMapProvider).value?[item.creatorId];
    final topics = ref.watch(topicsProvider).value ?? const [];
    final itemTopics = topics.where((x) => item.topicIds.contains(x.id)).toList();
    final all = ref.watch(allContentProvider).value ?? const <ContentItem>[];
    final audioVersion = all.where((c) => c.sourceContentId == item.id).firstOrNull;
    final sourceVideo = item.sourceContentId == null
        ? null
        : all.where((c) => c.id == item.sourceContentId).firstOrNull;
    final related = all.where((c) => c.id != item.id && c.topicIds.any(item.topicIds.contains)).take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: MwbSpace.xxxl),
      child: MwbConstrained(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: MwbSpace.xs),
            // Media
            switch (item.type) {
              ContentType.video => VideoPlayerView(item: item, controller: _video!),
              ContentType.audio => ContentArtworkView(
                item: item,
                aspectRatio: 16 / 9,
                radius: MwbRadius.lg,
                iconSize: 30,
              ),
              ContentType.article || ContentType.scriptureReference => const SizedBox.shrink(),
            },
            const SizedBox(height: MwbSpace.lg),
            Row(
              children: [
                Text(item.type.singular.toUpperCase(), style: t.overline),
                if (item.isSample) ...[const SizedBox(width: MwbSpace.xs), const SampleBadge()],
              ],
            ),
            const SizedBox(height: 6),
            Semantics(header: true, child: Text(item.title, style: t.pageHeading)),
            const SizedBox(height: MwbSpace.xs),
            Text(
              [
                ?creator?.displayName,
                if (item.durationSeconds != null)
                  formatMinutes(item.durationSeconds!, read: item.type == ContentType.article),
                formatShortDate(item.publishedAt),
              ].join(' · '),
              style: t.supporting,
            ),
            if (item.type == ContentType.audio) ...[const SizedBox(height: MwbSpace.lg), AudioPlayerPanel(item: item)],
            if (item.type == ContentType.video && (_video?.isSimulated ?? false)) ...[
              const SizedBox(height: MwbSpace.sm),
              const MwbNotice(
                icon: Icons.videocam_off_outlined,
                message:
                    'Video preview: no video media is bundled in Foundation V1, so the controls '
                    'run against the listed duration. Creator videos will play once MWB media hosting launches.',
              ),
            ],
            const SizedBox(height: MwbSpace.lg),
            Text(item.description, style: t.body),
            if (item.body != null) ...[
              const SizedBox(height: MwbSpace.lg),
              for (final para in item.body!.split('\n\n'))
                Padding(
                  padding: const EdgeInsets.only(bottom: MwbSpace.md),
                  child: Text(para, style: t.body.copyWith(fontSize: 16.5, height: 1.65)),
                ),
            ],
            if (audioVersion != null || sourceVideo != null) ...[
              const SizedBox(height: MwbSpace.md),
              MwbCard(
                onTap: () => context.push(AppRoutes.content((audioVersion ?? sourceVideo)!.id)),
                child: Row(
                  children: [
                    Icon(
                      audioVersion != null ? Icons.headphones_outlined : Icons.play_circle_outline_rounded,
                      color: c.primary,
                    ),
                    const SizedBox(width: MwbSpace.sm),
                    Expanded(
                      child: Text(
                        audioVersion != null
                            ? 'Listen to the audio version'
                            : 'Audio extracted from a video — watch the excerpt',
                        style: t.label.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ],
                ),
              ),
            ],
            _EngagementRow(item: item),
            if (item.scriptureRefs.isNotEmpty) ...[
              const SizedBox(height: MwbSpace.xl),
              MwbSectionHeading(
                overline: 'Scripture',
                title: item.type == ContentType.scriptureReference ? 'The passage' : 'Scripture in this message',
              ),
              const SizedBox(height: MwbSpace.sm),
              for (final r in item.scriptureRefs)
                Padding(
                  padding: const EdgeInsets.only(bottom: MwbSpace.sm),
                  child: ScriptureCard(reference: r),
                ),
            ],
            if (itemTopics.isNotEmpty) ...[
              const SizedBox(height: MwbSpace.lg),
              Wrap(
                spacing: MwbSpace.xs,
                runSpacing: MwbSpace.xs,
                children: [
                  for (final topic in itemTopics)
                    MwbChip(label: topic.name, onTap: () => context.push(AppRoutes.topic(topic.id))),
                ],
              ),
            ],
            if (creator != null) ...[
              const SizedBox(height: MwbSpace.xl),
              const MwbSectionHeading(overline: 'Shared by', title: 'Creator'),
              const SizedBox(height: MwbSpace.xs),
              CreatorTile(creator: creator),
            ],
            if (related.isNotEmpty) ...[
              const SizedBox(height: MwbSpace.xl),
              const MwbSectionHeading(overline: 'More like this', title: 'Related'),
              const SizedBox(height: MwbSpace.xs),
              for (final r in related) ContentListTile(item: r),
            ],
          ],
        ),
      ),
    );
  }
}

class _EngagementRow extends ConsumerWidget {
  const _EngagementRow({required this.item});
  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final e = item.engagement;
    final Creator? creator = ref.watch(creatorMapProvider).value?[item.creatorId];
    Widget stat(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(right: MwbSpace.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: t.caption),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: MwbSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              runSpacing: 6,
              children: [
                stat(Icons.visibility_outlined, formatCompact(e.views)),
                stat(Icons.bookmark_border_rounded, formatCompact(e.saves)),
                stat(Icons.volunteer_activism_outlined, '${formatCompact(e.amens)} amens'),
              ],
            ),
          ),
          MwbIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: 'Copy to share',
            onPressed: () => shareContent(context, item, creator),
          ),
        ],
      ),
    );
  }
}
