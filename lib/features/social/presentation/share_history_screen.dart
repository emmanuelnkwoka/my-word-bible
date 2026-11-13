import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/social.dart';
import '../application/social_providers.dart';
import 'social_widgets.dart';

/// Sent, received and saved Scriptures, opened links and responses.
class ShareHistoryScreen extends ConsumerWidget {
  const ShareHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(sentSharesProvider);
    final received = ref.watch(receivedSharesProvider);
    final saved = received.where((s) => s.isSaved).toList();
    final links = ref.watch(openedLinksProvider);
    final acks = [
      for (final s in [...sent, ...received])
        for (final a in s.acknowledgements) (s, a),
    ]..sort((a, b) => b.$2.at.compareTo(a.$2.at));
    final now = ref.watch(socialClockProvider)();

    Widget list(List<Widget> children, String emptyTitle, String emptyMessage) => children.isEmpty
        ? MwbEmptyState(icon: Icons.history_rounded, title: emptyTitle, message: emptyMessage, compact: true)
        : ListView(padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl), children: children);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Share history'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(key: Key('history.tab.sent'), text: 'Sent'),
              Tab(key: Key('history.tab.received'), text: 'Received'),
              Tab(key: Key('history.tab.saved'), text: 'Saved'),
              Tab(key: Key('history.tab.links'), text: 'Opened links'),
              Tab(key: Key('history.tab.responses'), text: 'Responses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            list(
              [for (final s in sent) _ShareRow(share: s, now: now)],
              'Nothing sent yet',
              'Scripture you send to someone in the app appears here with its delivery status.',
            ),
            list(
              [for (final s in received) _ShareRow(share: s, now: now)],
              'Nothing received yet',
              'Scripture shared with you appears here, so you can come back to it.',
            ),
            list(
              [for (final s in saved) _ShareRow(share: s, now: now)],
              'No saved Scripture',
              'Tap Save on a shared Scripture to keep it here and in your Library.',
            ),
            list(
              [
                for (final l in links)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_rounded),
                    title: Text(l.label ?? 'Shared link'),
                    subtitle: Text('${_outcome(l.outcome)} · ${relativeTime(l.openedAt, now)}'),
                    onTap: () => context.push(AppRoutes.sharedScripture(l.shareId)),
                  ),
              ],
              'No links opened',
              'Shared links you open on this phone are listed here.',
            ),
            list(
              [
                for (final (s, a) in acks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.reply_rounded),
                    title: Text(a.message ?? a.kind.label),
                    subtitle: Text('${s.referenceLabel} · ${a.status.label} · ${relativeTime(a.at, now)}'),
                    onTap: () => context.push(AppRoutes.sharedScripture(s.id)),
                  ),
              ],
              'No responses yet',
              'Thanks and replies to shared Scripture appear here.',
            ),
          ],
        ),
      ),
    );
  }

  static String _outcome(String o) => switch (o) {
    'opened' => 'Opened',
    'notOnDevice' => 'Waiting for the sharing service',
    'forbidden' => 'Private',
    _ => 'Invalid',
  };
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share, required this.now});
  final ScriptureShare share;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final sent = share.direction == ShareDirection.sent;
    return InkWell(
      key: Key('history.share.${share.id}'),
      borderRadius: MwbRadius.mdAll,
      onTap: () => context.push(AppRoutes.sharedScripture(share.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MwbSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sent ? 'To ${share.recipientName}' : 'From ${share.senderName}',
                    style: t.bodyStrong,
                  ),
                ),
                if (share.simulated) const DemoBadge(),
                if (!sent && !share.isRead) ...[
                  const SizedBox(width: 6),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                ],
              ],
            ),
            Text(
              '${share.referenceLabel} · ${share.translationId}',
              style: t.scriptureReference.copyWith(fontSize: 12),
            ),
            Text(share.text, style: t.supporting, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                if (sent) DeliveryStatusPill(status: share.status) else Text(share.isRead ? 'Read' : 'New', style: t.caption),
                const Spacer(),
                Text(relativeTime(share.createdAt, now), style: t.caption),
              ],
            ),
            Divider(color: c.divider, height: MwbSpace.lg),
          ],
        ),
      ),
    );
  }
}
