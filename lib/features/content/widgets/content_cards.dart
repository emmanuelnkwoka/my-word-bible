import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/content.dart';
import '../../discovery/application/content_providers.dart';
import '../../library/application/library_controllers.dart';
import 'content_artwork.dart';

/// "Grace Hall Teaching · 32 min".
String contentMeta(ContentItem item, String? creatorName) {
  final parts = <String>[?creatorName];
  final secs = item.durationSeconds;
  if (secs != null) parts.add(formatMinutes(secs, read: item.type == ContentType.article));
  return parts.join(' · ');
}

/// Save/unsave toggle for any content item.
class SaveContentButton extends ConsumerWidget {
  const SaveContentButton({super.key, required this.item, this.filled = false});

  final ContentItem item;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isContentSavedProvider(item.id));
    return MwbIconButton(
      icon: Icons.bookmark_border_rounded,
      selectedIcon: Icons.bookmark_rounded,
      selected: saved,
      filled: filled,
      tooltip: saved ? 'Remove from library' : 'Save to library',
      onPressed: () async {
        HapticFeedback.lightImpact();
        final nowSaved = await ref.read(savedContentProvider.notifier).toggle(item);
        if (context.mounted) {
          showMwbSnack(context, nowSaved ? 'Saved to your library' : 'Removed from your library');
        }
      },
    );
  }
}

/// Vertical card for horizontal carousels.
class ContentCard extends ConsumerWidget {
  const ContentCard({super.key, required this.item, this.width = 240});

  final ContentItem item;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final creator = ref.watch(creatorMapProvider).value?[item.creatorId];
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '${item.type.singular}: ${item.title}${creator == null ? '' : ', by ${creator.displayName}'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: MwbRadius.mdAll,
          onTap: () => context.push(AppRoutes.content(item.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContentArtworkView(item: item),
              const SizedBox(height: MwbSpace.sm),
              Text(item.title, style: t.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                contentMeta(item, creator?.displayName),
                style: t.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row used in lists, search results and the library.
class ContentListTile extends ConsumerWidget {
  const ContentListTile({super.key, required this.item, this.trailing, this.showSave = true, this.onTap});

  final ContentItem item;
  final Widget? trailing;
  final bool showSave;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final creator = ref.watch(creatorMapProvider).value?[item.creatorId];
    return Semantics(
      button: true,
      label: '${item.type.singular}: ${item.title}',
      child: InkWell(
        borderRadius: MwbRadius.mdAll,
        onTap: onTap ?? () => context.push(AppRoutes.content(item.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MwbSpace.xs),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                child: ContentArtworkView(
                  item: item,
                  aspectRatio: 1,
                  showTypeBadge: false,
                  showDuration: false,
                  iconSize: 16,
                ),
              ),
              const SizedBox(width: MwbSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.type.singular.toUpperCase(), style: t.overline.copyWith(fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      style: t.cardTitle.copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contentMeta(item, creator?.displayName),
                      style: t.caption.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              trailing ?? (showSave ? SaveContentButton(item: item) : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal carousel of [ContentCard]s.
class ContentCarousel extends StatelessWidget {
  const ContentCarousel({super.key, required this.items, this.padding, this.cardWidth = 240});

  final List<ContentItem> items;
  final EdgeInsetsGeometry? padding;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: cardWidth / (16 / 10) + 92 * textScale.clamp(1.0, 1.6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: MwbSpace.md),
        itemBuilder: (_, i) => ContentCard(item: items[i], width: cardWidth),
      ),
    );
  }
}

/// Large featured card with description.
class FeaturedContentCard extends ConsumerWidget {
  const FeaturedContentCard({super.key, required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final creator = ref.watch(creatorMapProvider).value?[item.creatorId];
    return Semantics(
      button: true,
      label: 'Featured ${item.type.singular}: ${item.title}',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: MwbRadius.lgAll,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.content(item.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContentArtworkView(item: item, aspectRatio: 16 / 8, radius: 0, iconSize: 26),
              // Fills the remaining height of its slot; text truncates rather
              // than overflowing at large text sizes.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(MwbSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FEATURED ${item.type.label.toUpperCase()}', style: t.overline),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: t.sectionHeading.copyWith(fontSize: 22),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          item.description,
                          style: t.supporting,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: MwbSpace.sm),
                      Text(
                        contentMeta(item, creator?.displayName),
                        style: t.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
