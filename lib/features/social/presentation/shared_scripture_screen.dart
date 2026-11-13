import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';
import '../../share/scripture_image_composer.dart';
import '../../share/scripture_share_sheet.dart';
import '../application/social_providers.dart';
import '../domain/share_links.dart';
import 'social_widgets.dart';

/// A shared Scripture, opened from the inbox, history or a link
/// (`/s/{shareId}`). Private shares open only for the two people in them.
class SharedScriptureScreen extends ConsumerStatefulWidget {
  const SharedScriptureScreen({super.key, required this.shareId});
  final String shareId;

  @override
  ConsumerState<SharedScriptureScreen> createState() => _SharedScriptureScreenState();
}

class _SharedScriptureScreenState extends ConsumerState<SharedScriptureScreen> {
  late Future<ShareResolution> _resolution;

  @override
  void initState() {
    super.initState();
    _resolution = ref.read(socialActionsProvider).openLink(widget.shareId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShareResolution>(
      future: _resolution,
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) return const Scaffold(body: MwbLoadingState());
        if (r.outcome != ShareLinkOutcome.opened) return _Unavailable(outcome: r.outcome);
        // Re-read so actions (save, thanks) show immediately.
        ref.watch(socialRevisionProvider);
        final share = ref.read(scriptureShareRepositoryProvider).byId(widget.shareId) ?? r.share!;
        return _ShareView(share: share);
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.outcome});
  final ShareLinkOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (outcome) {
      ShareLinkOutcome.forbidden => (
        Icons.lock_outline_rounded,
        'This Scripture is private',
        'It was shared with someone else. Only the sender and the person it was sent to can open it.',
      ),
      ShareLinkOutcome.notOnDevice => (
        Icons.cloud_off_rounded,
        'Not on this device',
        'Shared links will open here once the My Word Bible sharing service is connected. '
            'This link was saved, so it will be ready when it is.',
      ),
      _ => (Icons.link_off_rounded, 'This link isn’t valid', 'Check that the whole link was copied.'),
    };
    return Scaffold(
      appBar: AppBar(),
      body: MwbEmptyState(
        key: Key('shared.unavailable.${outcome.name}'),
        icon: icon,
        title: title,
        message: message,
        actionLabel: 'Go to Home',
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}

class _ShareView extends ConsumerWidget {
  const _ShareView({required this.share});
  final ScriptureShare share;

  bool get _received => share.direction == ShareDirection.received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final other = _received ? share.senderId : share.recipientId;
    final otherName = _received ? share.senderName : share.recipientName;
    final first = otherName.split(' ').first;
    final person = ref.watch(publicProfileProvider(other)).value;
    final following = ref.watch(followingProvider).contains(other);
    final now = ref.watch(socialClockProvider)();
    final actions = ref.read(socialActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_received ? 'Shared with you' : 'You shared'),
        actions: [
          if (_received)
            PopupMenuButton<String>(
              key: const Key('shared.more'),
              tooltip: 'More',
              onSelected: (v) async {
                if (v == 'block') {
                  final ok = await showMwbConfirmDialog(
                    context,
                    title: 'Block $otherName?',
                    message: 'They won’t be able to share with you or see you in search, and their shares will be hidden.',
                    confirmLabel: 'Block',
                    destructive: true,
                  );
                  if (!ok) return;
                  await actions.block(other);
                  if (context.mounted) {
                    showMwbSnack(context, '$otherName blocked');
                    context.pop();
                  }
                } else if (v == 'report') {
                  await _report(context, ref, other, otherName);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'report', child: Text('Report')),
                const PopupMenuItem(value: 'block', key: Key('shared.block'), child: Text('Block')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
        children: [
          Row(
            children: [
              PersonAvatar(initials: person?.initials ?? otherName.characters.first, tone: person?.tone ?? 0),
              const SizedBox(width: MwbSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _received ? '$otherName shared a Scripture with you' : 'To $otherName',
                      style: t.bodyStrong,
                    ),
                    Row(
                      children: [
                        Text(relativeTime(share.createdAt, now), style: t.caption),
                        if (share.simulated) ...[const SizedBox(width: 8), const DemoBadge()],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (share.message != null) ...[
            const SizedBox(height: MwbSpace.md),
            Container(
              key: const Key('shared.message'),
              padding: const EdgeInsets.all(MwbSpace.md),
              decoration: BoxDecoration(color: c.selected, borderRadius: MwbRadius.lgAll),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (share.careIntent != null)
                    Text(share.careIntent!.label.toUpperCase(), style: t.overline.copyWith(color: c.primaryStrong)),
                  Text(share.message!, style: t.body.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
          const SizedBox(height: MwbSpace.md),
          SharedScriptureCard(share: share),
          const SizedBox(height: MwbSpace.lg),
          if (_received) ...[
            MwbPrimaryButton(
              key: const Key('shared.read'),
              label: 'Read in the Bible',
              icon: Icons.menu_book_rounded,
              onPressed: () {
                final r = share.references.first;
                context.push(AppRoutes.reader(r.bookId, r.chapter, verse: r.verseStart));
              },
            ),
            const SizedBox(height: MwbSpace.sm),
            Wrap(
              spacing: MwbSpace.xs,
              runSpacing: MwbSpace.xs,
              children: [
                _Action(
                  key: const Key('shared.save'),
                  icon: share.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: share.isSaved ? 'Saved' : 'Save',
                  onTap: () async {
                    await actions.saveShare(share, saved: !share.isSaved);
                    if (context.mounted) showMwbSnack(context, share.isSaved ? 'Removed from saved' : 'Saved to your Library');
                  },
                ),
                _Action(
                  key: const Key('shared.thanks'),
                  icon: Icons.favorite_border_rounded,
                  label: share.acknowledgements.any((a) => a.kind == AcknowledgementKind.thanks) ? 'Thanked' : 'Thank $first',
                  onTap: () async {
                    await actions.acknowledge(share, AcknowledgementKind.thanks);
                    if (context.mounted) showMwbSnack(context, _ackNote(share, first));
                  },
                ),
                _Action(
                  key: const Key('shared.respond'),
                  icon: Icons.reply_rounded,
                  label: 'Respond',
                  onTap: () => _respond(context, ref, first),
                ),
                if (person != null)
                  _Action(
                    key: const Key('shared.follow'),
                    icon: following ? Icons.how_to_reg_rounded : Icons.person_add_alt_1_rounded,
                    label: following ? 'Following' : 'Follow $first',
                    onTap: () async {
                      try {
                        following ? await actions.unfollow(other) : await actions.follow(other);
                      } on SocialFailure catch (e) {
                        if (context.mounted) showMwbSnack(context, e.message);
                      }
                    },
                  ),
                _Action(
                  key: const Key('shared.reshare'),
                  icon: Icons.ios_share_rounded,
                  label: 'Share this verse',
                  onTap: () => _reshare(context, ref),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Text('Status: ', style: t.supporting),
                DeliveryStatusPill(status: share.status),
              ],
            ),
            if (share.status == DeliveryStatus.simulated)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$first is a demo person; no one else received this.', style: t.caption),
              ),
            if (share.status == DeliveryStatus.awaitingServer)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('It will be delivered when My Word Bible accounts are live.', style: t.caption),
              ),
            const SizedBox(height: MwbSpace.md),
            MwbSecondaryButton(
              key: const Key('shared.copyLink'),
              label: 'Copy link',
              icon: Icons.link_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: ShareLinkCodec.webUrl(share.id).toString()));
                if (context.mounted) {
                  showMwbSnack(context, 'Link copied. It will open for others once the sharing service is live.');
                }
              },
            ),
          ],
          if (share.acknowledgements.isNotEmpty) ...[
            const SizedBox(height: MwbSpace.lg),
            Text('RESPONSES', style: t.overline),
            for (final a in share.acknowledgements)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.reply_rounded),
                title: Text(a.message ?? a.kind.label),
                subtitle: Text('${a.fromUserId == share.senderId ? share.senderName : 'You'} · ${a.status.label}'),
              ),
          ],
        ],
      ),
    );
  }

  static String _ackNote(ScriptureShare share, String first) => share.simulated
      ? 'Thanks recorded (demo: $first won’t receive it).'
      : 'Thanks saved. $first will see it when accounts are live.';

  Future<void> _respond(BuildContext context, WidgetRef ref, String first) async {
    final controller = TextEditingController();
    final text = await showMwbSheet<String>(
      context,
      title: 'Respond to $first',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('shared.reply'),
            controller: controller,
            autofocus: true,
            maxLength: 280,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Thank you, this blessed me…'),
          ),
          const SizedBox(height: MwbSpace.sm),
          MwbPrimaryButton(
            key: const Key('shared.replySend'),
            label: 'Send',
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    await ref.read(socialActionsProvider).acknowledge(share, AcknowledgementKind.reply, message: text);
    if (context.mounted) showMwbSnack(context, _ackNote(share, first).replaceFirst('Thanks', 'Reply'));
  }

  Future<void> _reshare(BuildContext context, WidgetRef ref) async {
    // The canonical Scripture only; the personal message is never passed on.
    final s = ShareScripture(
      verses: [for (final v in share.verses) ShareVerse(v.number, [ShareSpan(v.text)])],
      reference: share.referenceLabel,
      translation: share.translationId,
      numbered: share.verses.length > 1,
      sources: share.references,
      sourceVersionId: share.translationId,
    );
    await showScriptureShareSheet(context, s);
  }

  static Future<void> _report(BuildContext context, WidgetRef ref, String userId, String name) async {
    const reasons = ['Unwanted or repeated messages', 'Hurtful or harassing', 'Spam or scam', 'Something else'];
    final reason = await showMwbSheet<String>(
      context,
      title: 'Report $name',
      subtitle: 'Reports are kept on this device and will go to the My Word Bible team once moderation is connected.',
      builder: (ctx) => Column(
        children: [
          for (final r in reasons) ListTile(title: Text(r), onTap: () => Navigator.of(ctx).pop(r)),
        ],
      ),
    );
    if (reason == null) return;
    await ref.read(socialActionsProvider).report(userId, reason);
    if (context.mounted) showMwbSnack(context, 'Thank you. Your report was saved. You can also block $name.');
  }
}

class _Action extends StatelessWidget {
  const _Action({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: c.primary),
      label: Text(label),
      labelStyle: context.mwb.text.label.copyWith(fontWeight: FontWeight.w600),
      backgroundColor: c.surfaceElevated,
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      onPressed: onTap,
    );
  }
}
