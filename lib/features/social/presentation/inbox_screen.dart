import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';
import '../application/social_providers.dart';
import 'social_widgets.dart';

/// In-app notifications: Scripture received, followers, encouragement,
/// prayer and replies. Records persist on the device.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  NotificationCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final all = ref.watch(notificationsProvider);
    final items = _filter == null ? all : all.where((n) => n.category == _filter).toList();
    final now = ref.watch(socialClockProvider)();
    final live = ref.watch(scriptureShareRepositoryProvider).isLive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          if (all.any((n) => !n.isRead))
            TextButton(
              key: const Key('inbox.markAll'),
              onPressed: () => ref.read(socialActionsProvider).markAllNotificationsRead(),
              child: const Text('Mark all read'),
            ),
          PopupMenuButton<String>(
            key: const Key('inbox.more'),
            tooltip: 'More',
            onSelected: (v) => switch (v) {
              'history' => context.push(AppRoutes.shareHistory),
              'privacy' => context.push(AppRoutes.sharingPrivacy),
              _ => _showDemoTools(context),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'history', child: Text('Share history')),
              const PopupMenuItem(value: 'privacy', child: Text('Sharing & privacy')),
              if (!live) const PopupMenuItem(value: 'demo', key: Key('inbox.demo'), child: Text('Try the demo…')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: MwbLayout.pagePadding(context, top: MwbSpace.xs, bottom: MwbSpace.xxl),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final cat in <NotificationCategory?>[null, ...NotificationCategory.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('inbox.filter.${cat?.name ?? 'all'}'),
                      label: Text(cat?.label ?? 'All'),
                      selected: _filter == cat,
                      showCheckmark: false,
                      selectedColor: c.selected,
                      backgroundColor: c.surfaceElevated,
                      side: BorderSide(color: _filter == cat ? c.primary.withValues(alpha: 0.5) : c.border),
                      shape: const StadiumBorder(),
                      labelStyle: t.label.copyWith(fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _filter = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MwbSpace.sm),
          if (!live) ...[
            const SocialNotice(
              message:
                  'Messages from other people arrive here once My Word Bible accounts are live. Until then, '
                  'use “Try the demo” to see how receiving Scripture feels.',
            ),
            const SizedBox(height: MwbSpace.sm),
          ],
          if (items.isEmpty)
            const MwbEmptyState(
              icon: Icons.mark_email_unread_outlined,
              title: 'Nothing here yet',
              message: 'When someone shares Scripture with you or follows you, you’ll see it here.',
              compact: true,
            )
          else
            for (final n in items) _NotificationTile(note: n, now: now),
        ],
      ),
    );
  }

  Future<void> _showDemoTools(BuildContext context) {
    final people = DemoUserDirectory.people.where((p) => !p.isRestricted).toList();
    final actions = ref.read(socialActionsProvider);
    return showMwbSheet<void>(
      context,
      title: 'Try the demo',
      subtitle: 'Creates sample notifications on this phone, marked “Demo”. No real person is involved.',
      builder: (ctx) => Column(
        children: [
          ListTile(
            key: const Key('demo.scripture'),
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('Receive a Scripture'),
            subtitle: Text('From ${people[0].displayName} · Psalm 46:10'),
            onTap: () async {
              Navigator.of(ctx).pop();
              await actions.simulateIncoming(from: people[0], reference: ScriptureReference.parseCompact('PSA 46:10'));
            },
          ),
          ListTile(
            key: const Key('demo.encouragement'),
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('Receive encouragement'),
            subtitle: Text('From ${people[2].displayName} · Isaiah 41:10'),
            onTap: () async {
              Navigator.of(ctx).pop();
              await actions.simulateIncoming(
                from: people[2],
                reference: ScriptureReference.parseCompact('ISA 41:10'),
                careIntent: CareIntent.thinkingOfYou,
              );
            },
          ),
          ListTile(
            key: const Key('demo.follower'),
            leading: const Icon(Icons.person_add_alt_1_rounded),
            title: const Text('Get a new follower'),
            subtitle: Text(people[1].displayName),
            onTap: () async {
              Navigator.of(ctx).pop();
              final added = await actions.simulateFollower(people[1]);
              if (!added && context.mounted) showMwbSnack(context, '${people[1].displayName} already follows you.');
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.note, required this.now});
  final InAppNotification note;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final icon = switch (note.category) {
      NotificationCategory.scriptureReceived => Icons.menu_book_rounded,
      NotificationCategory.newFollower => Icons.person_add_alt_1_rounded,
      NotificationCategory.encouragement => Icons.volunteer_activism_outlined,
      NotificationCategory.prayer => Icons.self_improvement_rounded,
      NotificationCategory.acknowledgement => Icons.reply_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: MwbSpace.xs),
      child: Material(
        color: note.isRead ? c.surface : c.selected.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: MwbRadius.lgAll, side: BorderSide(color: c.border)),
        child: InkWell(
          key: Key('inbox.item.${note.id}'),
          borderRadius: MwbRadius.lgAll,
          onTap: () async {
            await ref.read(socialActionsProvider).markNotificationRead(note.id);
            if (!context.mounted) return;
            if (note.shareId != null) {
              context.push(AppRoutes.sharedScripture(note.shareId!));
            } else if (note.actorId != null) {
              context.push(AppRoutes.person(note.actorId!));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(MwbSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PersonAvatar(initials: _initials(note.actorName), tone: note.actorId == null ? -1 : ref.watch(publicProfileProvider(note.actorId!)).value?.tone ?? -1, size: 42),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: c.primaryStrong, shape: BoxShape.circle),
                        child: Icon(icon, size: 12, color: c.onPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: MwbSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.title, style: t.bodyStrong),
                      if (note.body != null) Text(note.body!, style: t.supporting),
                      if (note.preview != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '“${note.preview}”',
                          style: t.scripture.copyWith(fontSize: 15, height: 1.45),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.referenceLabel != null)
                          Text(note.referenceLabel!, style: t.scriptureReference.copyWith(fontSize: 11.5)),
                      ],
                      if (note.message != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          note.message!,
                          style: t.supporting.copyWith(fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(relativeTime(note.createdAt, now), style: t.caption),
                          if (note.simulated) ...[const SizedBox(width: 8), const DemoBadge()],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '•';
    return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Inbox entry with an unread badge (Home header).
class InboxBellButton extends ConsumerWidget {
  const InboxBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final unread = ref.watch(unreadNotificationsProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const Key('home.inbox'),
          tooltip: unread == 0 ? 'Inbox' : 'Inbox, $unread unread',
          icon: Icon(Icons.notifications_none_rounded, color: c.textPrimary),
          onPressed: () => context.push(AppRoutes.inbox),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                key: const Key('home.inboxBadge'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(color: c.primaryStrong, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: context.mwb.text.caption.copyWith(color: c.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
