import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';
import '../application/social_providers.dart';
import 'social_widgets.dart';

/// Identity, who can reach you, notifications, blocked people.
class SharingPrivacyScreen extends ConsumerWidget {
  const SharingPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final me = ref.watch(socialIdentityProvider);
    final p = ref.watch(socialPrivacyProvider);
    final blockedIds = ref.watch(blockedUsersProvider);
    final actions = ref.read(socialActionsProvider);
    void save(SocialPrivacySettings s) => actions.savePrivacy(s);

    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(top: MwbSpace.lg, bottom: MwbSpace.xs),
      child: Text(s.toUpperCase(), style: t.overline),
    );

    Widget choice<T>(String title, List<T> values, T value, String Function(T) label, ValueChanged<T> onChanged, Key key) =>
        ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: t.body),
          subtitle: Text(label(value), style: t.caption),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final picked = await showMwbSheet<T>(
              context,
              title: title,
              builder: (ctx) => Column(
                children: [
                  for (final v in values)
                    ListTile(
                      title: Text(label(v)),
                      trailing: v == value ? Icon(Icons.check_rounded, color: c.primary) : null,
                      onTap: () => Navigator.of(ctx).pop(v),
                    ),
                ],
              ),
            );
            if (picked != null) onChanged(picked);
          },
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sharing & privacy')),
      body: ListView(
        padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
        children: [
          heading('Your My Word Bible ID'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(me.handle, style: t.bodyStrong),
            subtitle: Text(
              '${me.userId}\n${me.registered ? 'Registered' : 'Reserved on this phone. It is claimed when accounts launch.'}',
              style: t.caption,
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Copy ID',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: me.userId));
                if (context.mounted) showMwbSnack(context, 'ID copied');
              },
            ),
          ),
          heading('Who can reach you'),
          choice<ProfileVisibility>(
            'Who can see my profile',
            ProfileVisibility.values,
            p.profileVisibility,
            (v) => v.label,
            (v) => save(p.copyWith(profileVisibility: v)),
            const Key('privacy.visibility'),
          ),
          choice<DirectShareAudience>(
            'Who can send me Scripture',
            DirectShareAudience.values,
            p.whoCanSendScripture,
            (v) => v.label,
            (v) => save(p.copyWith(whoCanSendScripture: v)),
            const Key('privacy.whoCanSend'),
          ),
          SwitchListTile.adaptive(
            key: const Key('privacy.public'),
            contentPadding: EdgeInsets.zero,
            title: Text('Show Scripture I share on my profile', style: t.body),
            subtitle: Text('Only verses, never private messages. Off by default.', style: t.caption),
            value: p.sharePublicActivity,
            onChanged: (v) => save(p.copyWith(sharePublicActivity: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Show my name on cards by default', style: t.body),
            value: p.showNameOnCards,
            onChanged: (v) => save(p.copyWith(showNameOnCards: v)),
          ),
          heading('Notifications'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Scripture shared with me', style: t.body),
            value: p.notifyOnScripture,
            onChanged: (v) => save(p.copyWith(notifyOnScripture: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('New followers', style: t.body),
            value: p.notifyOnFollow,
            onChanged: (v) => save(p.copyWith(notifyOnFollow: v)),
          ),
          Text(
            'These appear in your in-app inbox. Phone notifications arrive with My Word Bible accounts.',
            style: t.caption,
          ),
          heading('Blocked people'),
          if (blockedIds.isEmpty)
            Text('You haven’t blocked anyone.', style: t.supporting)
          else
            for (final id in blockedIds)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block_rounded),
                title: Text(
                  DemoUserDirectory.people.where((p) => p.userId == id).firstOrNull?.displayName ?? id,
                  style: t.body,
                ),
                trailing: TextButton(
                  key: Key('privacy.unblock.$id'),
                  onPressed: () => actions.unblock(id),
                  child: const Text('Unblock'),
                ),
              ),
          const SizedBox(height: MwbSpace.lg),
          const SocialNotice(
            icon: Icons.favorite_border_rounded,
            message:
                'My Word Bible never asks you to share what you are going through, and never shows anyone’s '
                'struggles publicly. Encouragement you send or receive stays between the two of you.',
          ),
        ],
      ),
    );
  }
}
