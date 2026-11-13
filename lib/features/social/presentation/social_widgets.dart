import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/social.dart';

/// Initials avatar with a calm tone per person.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.initials, this.tone = 0, this.size = 44});
  final String initials;
  final int tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final tones = c.highlightTones;
    final bg = tone < 0 ? c.selected : tones[tone % tones.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: c.border)),
      child: Text(
        initials,
        style: context.mwb.text.cardTitle.copyWith(fontSize: size * 0.36, color: c.textPrimary),
      ),
    );
  }
}

/// "Demo" label for sample people and simulated records.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'Demo'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MwbRadius.pill),
        border: Border.all(color: c.warning.withValues(alpha: 0.6)),
        color: c.warning.withValues(alpha: 0.1),
      ),
      child: Text(
        label,
        style: context.mwb.text.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: c.textPrimary),
      ),
    );
  }
}

/// Honest delivery state.
class DeliveryStatusPill extends StatelessWidget {
  const DeliveryStatusPill({super.key, required this.status});
  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final (icon, color) = switch (status) {
      DeliveryStatus.delivered => (Icons.done_all_rounded, c.success),
      DeliveryStatus.sent => (Icons.done_rounded, c.success),
      DeliveryStatus.simulated => (Icons.science_outlined, c.warning),
      DeliveryStatus.awaitingServer || DeliveryStatus.preparedOffline => (Icons.schedule_rounded, c.textSecondary),
      DeliveryStatus.failed => (Icons.error_outline_rounded, c.error),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(status.label, style: context.mwb.text.caption.copyWith(fontSize: 12, color: c.textSecondary)),
      ],
    );
  }
}

/// A calm explanation banner (local-only features, demo community).
class SocialNotice extends StatelessWidget {
  const SocialNotice({super.key, required this.message, this.icon = Icons.info_outline_rounded});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Container(
      padding: const EdgeInsets.all(MwbSpace.sm),
      decoration: BoxDecoration(
        color: c.selected.withValues(alpha: 0.6),
        borderRadius: MwbRadius.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(width: MwbSpace.xs),
          Expanded(child: Text(message, style: context.mwb.text.caption.copyWith(color: c.textPrimary, height: 1.4))),
        ],
      ),
    );
  }
}

/// A person row.
class PersonTile extends StatelessWidget {
  const PersonTile({super.key, required this.person, this.trailing, this.onTap, this.subtitle});
  final PublicProfile person;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return InkWell(
      onTap: onTap,
      borderRadius: MwbRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MwbSpace.xs),
        child: Row(
          children: [
            PersonAvatar(initials: person.initials, tone: person.tone),
            const SizedBox(width: MwbSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.displayName,
                          style: t.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (person.isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
                    ],
                  ),
                  Text(
                    subtitle ?? person.handle,
                    style: t.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Scripture as received: canonical text, reference and translation.
class SharedScriptureCard extends StatelessWidget {
  const SharedScriptureCard({super.key, required this.share, this.maxLines});
  final ScriptureShare share;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final numbered = share.verses.length > 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MwbSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MwbRadius.lgAll,
        border: Border.all(color: c.border),
        boxShadow: c.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                for (final v in share.verses) ...[
                  if (numbered)
                    TextSpan(
                      text: '${v.number} ',
                      style: t.caption.copyWith(color: c.primary, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  TextSpan(text: '${v.text} '),
                ],
              ],
            ),
            key: const Key('shared.scripture'),
            style: t.scripture.copyWith(fontSize: 19, height: 1.6),
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: MwbSpace.sm),
          Text(
            '— ${share.referenceLabel} · ${share.translationId}',
            style: t.scriptureReference.copyWith(color: c.primaryStrong),
          ),
        ],
      ),
    );
  }
}

String relativeTime(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return formatShortDate(at);
}
