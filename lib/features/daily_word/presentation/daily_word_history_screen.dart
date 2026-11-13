import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/daily_word.dart';
import '../../personalisation/application/scripture_presentation.dart';
import '../application/daily_word_providers.dart';
import 'daily_word_hero.dart';

/// Every Daily Word delivered on this device, newest first.
class DailyWordHistoryScreen extends ConsumerStatefulWidget {
  const DailyWordHistoryScreen({super.key});

  @override
  ConsumerState<DailyWordHistoryScreen> createState() => _DailyWordHistoryScreenState();
}

class _DailyWordHistoryScreenState extends ConsumerState<DailyWordHistoryScreen> {
  bool _favouritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(dailyWordHistoryProvider);
    final shown = _favouritesOnly ? all.where((e) => e.favourite).toList() : all;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Word history')),
      body: ListView(
        padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xl),
        children: [
          MwbChipRow(
            children: [
              MwbChip(
                label: 'All',
                count: all.length,
                selected: !_favouritesOnly,
                onTap: () => setState(() => _favouritesOnly = false),
              ),
              MwbChip(
                label: 'Favourites',
                icon: Icons.star_rounded,
                count: all.where((e) => e.favourite).length,
                selected: _favouritesOnly,
                onTap: () => setState(() => _favouritesOnly = true),
              ),
            ],
          ),
          const SizedBox(height: MwbSpace.md),
          if (shown.isEmpty)
            MwbEmptyState(
              title: _favouritesOnly ? 'No favourites yet' : 'No Daily Words yet',
              message: _favouritesOnly
                  ? 'Tap Favourite on a Daily Word to keep it here.'
                  : 'Each Daily Word you receive is kept here on your device.',
              icon: Icons.wb_twilight_rounded,
            )
          else
            for (final e in shown) DailyWordHistoryTile(entry: e),
        ],
      ),
    );
  }
}

/// One delivered Daily Word, titled exactly as it is presented now (Mode A
/// heading, Mode B personal title or "Daily Word – MWB"). The stored record
/// itself is never rewritten.
class DailyWordHistoryTile extends ConsumerWidget {
  const DailyWordHistoryTile({super.key, required this.entry});
  final DailyWordHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final p = ref
        .watch(
          scripturePresentationProvider(
            PresentationRequest(entry.reference, heading: entry.heading, fallbackTitle: dailyWordFallbackTitle),
          ),
        )
        .value;
    return ListTile(
      key: Key('dailyWordHistory.${entry.dateKey}'),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: MwbSpace.sm,
      leading: Icon(entry.favourite ? Icons.star_rounded : categoryIcon(entry.category), color: c.primary),
      title: Text(p?.title ?? entry.heading, style: t.cardTitle),
      subtitle: Text(
        '${formatShortDate(entry.date)} · ${entry.reference.label} · ${entry.category}',
        style: t.caption,
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      onTap: () => context.push(AppRoutes.dailyWord(entry.dateKey)),
    );
  }
}
