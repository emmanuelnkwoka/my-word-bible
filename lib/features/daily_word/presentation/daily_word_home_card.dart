import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/state_views.dart';
import '../application/daily_word_providers.dart';
import 'daily_word_hero.dart';

/// The Daily Word on Home: the personalised Scripture itself, immediately
/// visible, with one Share action and a way into the full Daily Word.
class DailyWordHomeCard extends ConsumerWidget {
  const DailyWordHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(todayKeyProvider);
    final value = ref.watch(dailyWordDetailProvider(key));
    return KeyedSubtree(
      key: const Key('home.dailyWord'),
      child: value.when(
        data: (d) => DailyWordHero(detail: d, onOpen: () => context.push(AppRoutes.dailyWord(key))),
        loading: () => const MwbCard(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: MwbLoadingState(compact: true, message: 'Preparing today’s Word…'),
        ),
        error: (e, _) => MwbCard(
          child: MwbErrorState(error: e, compact: true, onRetry: () => ref.invalidate(dailyWordDetailProvider(key))),
        ),
      ),
    );
  }
}
