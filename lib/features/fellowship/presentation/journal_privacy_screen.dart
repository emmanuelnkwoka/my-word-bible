import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/local/personal_database.dart';
import '../application/personal_providers.dart';
import 'journal_screen.dart';
import 'personal_widgets.dart';

/// Profile → Reflections & rhythm privacy: where the data lives, what
/// protects it, and the controls to export or delete it.
class JournalPrivacyScreen extends ConsumerWidget {
  const JournalPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final status = ref.watch(personalStoreProvider).value;
    final ready = status is PersonalStoreReady;
    final reflections = ref.watch(journalCountProvider);
    final readings = ref.watch(completedReadingsProvider).length;

    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: MwbSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(width: MwbSpace.sm),
          Expanded(child: Text(text, style: t.supporting)),
        ],
      ),
    );

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: MwbSpace.lg, bottom: MwbSpace.xs),
      child: Text(s.toUpperCase(), style: t.overline.copyWith(color: c.textSecondary)),
    );

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: MwbLayout.pagePadding(context, bottom: MwbSpace.xxxl),
        children: [
          Semantics(header: true, child: Text('Reflections & rhythm', style: t.pageHeading)),
          const SizedBox(height: MwbSpace.lg),
          const PersonalStoreNotice(),
          if (ready)
            MwbCard(
              key: const Key('journalPrivacy.status'),
              child: Row(
                children: [
                  Icon(Icons.enhanced_encryption_outlined, color: c.primary),
                  const SizedBox(width: MwbSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.database.encrypted ? 'Encrypted on this device' : 'Stored on this device',
                          style: t.cardTitle,
                        ),
                        Text(
                          '$reflections ${reflections == 1 ? 'reflection' : 'reflections'} · '
                          '$readings completed ${readings == 1 ? 'reading' : 'readings'}',
                          style: t.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          label('How it is protected'),
          point(
            Icons.lock_outline_rounded,
            'Reflections and reading activity are kept in an encrypted database (SQLCipher, AES-256) on this phone.',
          ),
          point(
            Icons.key_outlined,
            'The key is created on this phone and held in its secure storage (Android Keystore). It is never '
            'written to ordinary app storage and never leaves the phone.',
          ),
          point(
            Icons.cloud_off_outlined,
            'Nothing here is synced to a server, included in analytics, sent in notifications, or shown to anyone else.',
          ),
          point(
            Icons.backup_outlined,
            'It is not included in your phone\'s cloud backup, because the key cannot be backed up with it. '
            'To keep a copy, export your reflections.',
          ),
          point(
            Icons.key_off_outlined,
            'If the key is lost (for example after restoring app data to a new phone or resetting secure storage), '
            'the encrypted reflections cannot be recovered by anyone. The app will tell you and let you start again.',
          ),
          point(
            Icons.delete_sweep_outlined,
            'Deleted reflections are overwritten in the database file, not just hidden. Uninstalling the app '
            'removes everything.',
          ),
          if (ready) ...[
            label('Your reflections'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_note_rounded, color: c.primary),
              title: Text('Open reflections', style: t.label.copyWith(fontSize: 15)),
              trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              onTap: () => context.push(AppRoutes.journal),
            ),
            if (reflections > 0)
              ListTile(
                key: const Key('journalPrivacy.export'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.ios_share_rounded, color: c.primary),
                title: Text('Export reflections', style: t.label.copyWith(fontSize: 15)),
                subtitle: Text('Plain text or structured data. The file is not encrypted.', style: t.caption),
                onTap: () => exportReflections(context, ref),
              ),
            label('Delete'),
            _Danger(
              key: const Key('journalPrivacy.deleteReflections'),
              title: 'Delete all reflections',
              subtitle: 'Permanently remove every reflection from this device',
              confirmTitle: 'Delete all reflections?',
              confirmMessage: 'Every reflection will be permanently deleted. This cannot be undone.',
              done: 'All reflections deleted',
              onConfirm: () => ref.read(personalActionsProvider).deleteAllReflections(),
            ),
            _Danger(
              key: const Key('journalPrivacy.deleteReadings'),
              title: 'Delete reading activity',
              subtitle: 'Remove completed readings and sessions from your rhythm',
              confirmTitle: 'Delete reading activity?',
              confirmMessage:
                  'Completed readings and reading sessions will be removed. Reflections, bookmarks and your '
                  'reading history in the Library are not affected.',
              done: 'Reading activity deleted',
              onConfirm: () => ref.read(personalActionsProvider).clearReadingActivity(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Danger extends StatelessWidget {
  const _Danger({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.done,
    required this.onConfirm,
  });

  final String title;
  final String subtitle;
  final String confirmTitle;
  final String confirmMessage;
  final String done;
  final void Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: context.mwb.text.label.copyWith(fontSize: 15, color: c.error)),
      subtitle: Text(subtitle, style: context.mwb.text.caption),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      onTap: () async {
        final ok = await showMwbConfirmDialog(
          context,
          title: confirmTitle,
          message: confirmMessage,
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        onConfirm();
        if (context.mounted) showMwbSnack(context, done);
      },
    );
  }
}
