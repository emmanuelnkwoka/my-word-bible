import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/notices.dart';
import '../../../data/models/creator.dart';

/// Compact creator preview used in carousels.
class CreatorPreviewCard extends StatelessWidget {
  const CreatorPreviewCard({super.key, required this.creator, this.width = 156});

  final Creator creator;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: 'Creator ${creator.displayName}, ${creator.role}',
        excludeSemantics: true,
        child: Material(
          color: c.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: MwbRadius.lgAll,
            side: BorderSide(color: c.border),
          ),
          child: InkWell(
            borderRadius: MwbRadius.lgAll,
            onTap: () => context.push(AppRoutes.creator(creator.id)),
            child: Padding(
              padding: const EdgeInsets.all(MwbSpace.md),
              child: Column(
                children: [
                  MwbAvatar(initials: creator.initials, size: 56),
                  const SizedBox(height: MwbSpace.sm),
                  Text(
                    creator.displayName,
                    style: t.cardTitle.copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    creator.role,
                    style: t.caption,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (creator.isSample) const SampleBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Row-form creator preview for lists and content detail.
class CreatorTile extends StatelessWidget {
  const CreatorTile({super.key, required this.creator, this.trailing});

  final Creator creator;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final followers = creator.followerCount > 0 ? ' · ${formatCompact(creator.followerCount)} followers' : '';
    return Semantics(
      button: true,
      label: 'Creator ${creator.displayName}',
      child: InkWell(
        borderRadius: MwbRadius.mdAll,
        onTap: () => context.push(AppRoutes.creator(creator.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MwbSpace.xs),
          child: Row(
            children: [
              MwbAvatar(initials: creator.initials, size: 44),
              const SizedBox(width: MwbSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            creator.displayName,
                            style: t.cardTitle.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (creator.isSample) ...[const SizedBox(width: 6), const SampleBadge()],
                      ],
                    ),
                    Text('${creator.role}$followers', style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: context.mwb.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
