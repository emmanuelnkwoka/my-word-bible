import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/sheets.dart';
import '../../settings/presentation/settings_screens.dart';
import '../application/daily_word_providers.dart';

/// Daily Word personalisation and privacy controls.
class DailyWordSettingsScreen extends ConsumerWidget {
  const DailyWordSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final settings = ref.watch(dailyWordSettingsProvider);
    final searches = ref.watch(relevanceSignalsProvider).length;
    final history = ref.watch(dailyWordHistoryProvider).length;
    return SettingsPage(
      title: 'Daily Word & privacy',
      children: [
        MwbNotice(
          icon: Icons.lock_outline_rounded,
          title: settings.adaptiveEnabled ? 'Local personalisation is on' : 'Local personalisation is off',
          message: settings.adaptiveEnabled
              ? 'Your Daily Word follows the annual schedule, and may be adjusted using activity on this device. '
                    'Nothing is sent to any server.'
              : 'Your Daily Word follows the annual schedule exactly.',
        ),
        const SizedBox(height: MwbSpace.lg),
        MwbSwitchTile(
          key: const Key('dailyWordSettings.adaptive'),
          title: 'Adapt to my activity on this device',
          subtitle:
              'Uses the interests you chose, chapters you read, searches, and verses you saved, highlighted or '
              'noted in the last 30 days. Today’s word never changes once chosen.',
          icon: Icons.auto_awesome_motion_outlined,
          value: settings.adaptiveEnabled,
          onChanged: (v) => ref.read(dailyWordSettingsProvider.notifier).setAdaptive(v),
        ),
        const SizedBox(height: MwbSpace.lg),
        Text('SIGNALS ON THIS DEVICE', style: t.overline),
        const SizedBox(height: MwbSpace.xs),
        Text(
          '$searches recorded search${searches == 1 ? '' : 'es'}'
          '${settings.signalsClearedAt == null ? '' : ' · signals last cleared ${settings.signalsClearedAt!.toLocal().toString().substring(0, 16)}'}',
          style: t.supporting,
        ),
        const SizedBox(height: MwbSpace.sm),
        MwbSecondaryButton(
          key: const Key('dailyWordSettings.clear'),
          label: 'Clear Daily Word signals',
          icon: Icons.cleaning_services_outlined,
          onPressed: () async {
            final ok = await showMwbConfirmDialog(
              context,
              title: 'Clear Daily Word signals?',
              message:
                  'Recorded searches are deleted, and earlier reading, saves, highlights and notes stop influencing '
                  'the Daily Word. Your Library itself is not deleted.',
              confirmLabel: 'Clear',
            );
            if (!ok) return;
            await ref.read(dailyWordSettingsProvider.notifier).clearSignals();
            if (context.mounted) showMwbSnack(context, 'Daily Word signals cleared');
          },
        ),
        const SizedBox(height: MwbSpace.xl),
        MwbCard(
          onTap: () => context.push(AppRoutes.dailyWordHistory),
          semanticLabel: 'Daily Word history, $history entries',
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: context.mwb.colors.primary),
              const SizedBox(width: MwbSpace.sm),
              Expanded(child: Text('Daily Word history ($history)', style: t.cardTitle)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ],
    );
  }
}
