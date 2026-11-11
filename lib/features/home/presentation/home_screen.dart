import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/content.dart';
import '../../../data/models/library_items.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/mock/mock_daily.dart';
import '../../bible/application/bible_providers.dart';
import '../../bible/widgets/scripture_card.dart';
import '../../content/widgets/content_cards.dart';
import '../../discovery/application/content_providers.dart';
import '../../library/application/library_controllers.dart';
import '../../profile/application/profile_controllers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final daily = ref.watch(dailyExperienceProvider);
    final now = ref.watch(clockProvider)();
    final name = profile?.firstName;
    final gutter = MwbLayout.pagePadding(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recommendedProvider);
            ref.invalidate(suggestedTopicsProvider);
          },
          child: CustomScrollView(
            slivers: [
              MwbSliverPadding(
                top: MwbSpace.lg,
                sliver: SliverToBoxAdapter(
                  child: _Greeting(name: name, now: now),
                ),
              ),
              MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(
                  child: ScriptureCard(
                    key: const Key('home.dailyScripture'),
                    reference: dailyScriptureRefs[dayIndex(now, dailyScriptureRefs.length)],
                    overline: 'Daily Scripture',
                    personalLine: name == null || name.isEmpty ? 'For you today' : 'For you today, $name',
                    large: true,
                  ),
                ),
              ),
              const MwbSliverPadding(
                top: MwbSpace.md,
                sliver: SliverToBoxAdapter(child: _DailyPromiseCard()),
              ),
              const MwbSliverPadding(
                top: MwbSpace.md,
                sliver: SliverToBoxAdapter(child: _ContinueReading()),
              ),
              const MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(child: _QuickAccess()),
              ),
              const MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(child: _RecentlyRead()),
              ),
              MwbSliverPadding(
                top: MwbSpace.xl,
                sliver: SliverToBoxAdapter(
                  child: MwbSectionHeading(
                    overline: 'For you',
                    title: 'Topics to explore',
                    actionLabel: 'Discover',
                    onAction: () => context.go(AppRoutes.discover),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: MwbSpace.sm),
                  child: _SuggestedTopics(padding: gutter),
                ),
              ),
              if (daily.includeAudioInDiscovery)
                _RecommendedSection(
                  type: ContentType.audio,
                  overline: 'Listen',
                  title: 'Recommended audio',
                  padding: gutter,
                ),
              if (daily.includeVideoInDiscovery)
                _RecommendedSection(
                  type: ContentType.video,
                  overline: 'Watch',
                  title: 'Recommended videos',
                  padding: gutter,
                ),
              MwbSliverPadding(
                top: MwbSpace.xl,
                bottom: MwbSpace.xxxl,
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Messages, creators and articles shown in Foundation V1 are illustrative samples. '
                    'Scripture is the King James Version (public domain).',
                    style: context.mwb.text.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.now});
  final String? name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final greeting = greetingFor(now);
    final hasName = name != null && name!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatLongDate(now).toUpperCase(), style: t.overline),
              const SizedBox(height: MwbSpace.xs),
              Semantics(header: true, child: Text(hasName ? '$greeting,\n$name' : greeting, style: t.display)),
            ],
          ),
        ),
        MwbIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          filled: true,
          onPressed: () => context.push(AppRoutes.search()),
        ),
        const SizedBox(width: MwbSpace.xs),
        Semantics(
          button: true,
          label: 'Profile',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(AppRoutes.profile),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: MwbAvatar(initials: hasName ? name!.substring(0, 1).toUpperCase() : 'M'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyPromiseCard extends ConsumerWidget {
  const _DailyPromiseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final value = ref.watch(dailyPromiseProvider);
    final version = ref.watch(activeVersionProvider);
    return MwbCard(
      color: c.surface,
      padding: const EdgeInsets.all(MwbSpace.lg),
      child: AsyncValueView<(DailyPromise, Passage)>(
        value: value,
        compact: true,
        onRetry: () => ref.invalidate(dailyPromiseProvider),
        data: (data) {
          final (promise, passage) = data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.wb_twilight_rounded, size: 18, color: c.primary),
                  const SizedBox(width: MwbSpace.xs),
                  Text('TODAY’S PROMISE', style: t.overline),
                ],
              ),
              const SizedBox(height: MwbSpace.sm),
              Text(passage.text, style: t.scripture.copyWith(fontSize: 17)),
              const SizedBox(height: MwbSpace.xs),
              Text('${passage.reference.label.toUpperCase()} · ${version.abbreviation}', style: t.scriptureReference),
              Divider(height: MwbSpace.xl, color: c.divider),
              Text('YOUR DECLARATION', style: t.overline.copyWith(color: c.textSecondary)),
              const SizedBox(height: 6),
              Text(
                promise.declaration,
                style: t.sectionHeading.copyWith(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text('A personal response to this promise — not Scripture text.', style: t.caption),
            ],
          );
        },
      ),
    );
  }
}

class _ContinueReading extends ConsumerWidget {
  const _ContinueReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final history = ref.watch(readingHistoryProvider);
    final goal = ref.watch(readingPreferencesProvider.select((p) => p.dailyGoal));
    final last = history.isEmpty ? null : history.first;
    final today = DateTime.now();
    final readToday = history
        .where((h) => h.readAt.year == today.year && h.readAt.month == today.month && h.readAt.day == today.day)
        .length;
    final reference = last?.reference ?? const ScriptureReference(bookId: 'JHN', chapter: 1);
    final progress = (readToday / goal.chapters).clamp(0.0, 1.0);

    return MwbCard(
      onTap: () => context.push(AppRoutes.reader(reference.bookId, reference.chapter)),
      semanticLabel: last == null ? 'Start reading John 1' : 'Continue reading ${reference.label}',
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 2.5, backgroundColor: c.border),
                Icon(Icons.menu_book_rounded, color: c.primary, size: 20),
              ],
            ),
          ),
          const SizedBox(width: MwbSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(last == null ? 'START READING' : 'CONTINUE READING', style: t.overline),
                const SizedBox(height: 4),
                Text(reference.label, style: t.sectionHeading.copyWith(fontSize: 21)),
                const SizedBox(height: 2),
                Text(
                  last == null
                      ? 'Begin with the Gospel of John'
                      : '$readToday of ${goal.chapters} ${goal.chapters == 1 ? 'chapter' : 'chapters'} today · ${formatRelative(last.readAt)}',
                  style: t.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.primary),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.volunteer_activism_outlined, 'Prayer', () => context.push(AppRoutes.topic('prayer'))),
      (Icons.local_fire_department_outlined, 'Fasting', () => context.push(AppRoutes.topic('fasting'))),
      (Icons.bookmark_border_rounded, 'Saved', () => context.go(AppRoutes.library)),
      (Icons.edit_note_rounded, 'Notes', () => context.go(AppRoutes.librarySection('notes'))),
    ];
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: MwbSpace.xs),
          Expanded(
            child: MwbCard(
              padding: const EdgeInsets.symmetric(vertical: MwbSpace.md, horizontal: 4),
              onTap: items[i].$3,
              semanticLabel: items[i].$2,
              child: Column(
                children: [
                  Icon(items[i].$1, color: c.primary, size: 22),
                  const SizedBox(height: 6),
                  Text(items[i].$2, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecentlyRead extends ConsumerWidget {
  const _RecentlyRead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(readingHistoryProvider);
    if (history.length < 2) return const SizedBox.shrink();
    final List<ReadingHistoryEntry> recent = history.skip(1).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MwbSectionHeading(
          title: 'Recently read',
          actionLabel: 'History',
          onAction: () => context.go(AppRoutes.librarySection('history')),
        ),
        const SizedBox(height: MwbSpace.sm),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final h in recent)
              MwbChip(
                label: h.reference.label,
                icon: Icons.history_rounded,
                onTap: () => context.push(AppRoutes.reader(h.reference.bookId, h.reference.chapter)),
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggestedTopics extends ConsumerWidget {
  const _SuggestedTopics({required this.padding});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(suggestedTopicsProvider);
    return AsyncValueView(
      value: topics,
      compact: true,
      data: (list) => MwbChipRow(
        padding: padding,
        children: [for (final t in list) MwbChip(label: t.name, onTap: () => context.push(AppRoutes.topic(t.id)))],
      ),
    );
  }
}

class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection({required this.type, required this.overline, required this.title, required this.padding});

  final ContentType type;
  final String overline;
  final String title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recommendedProvider(type));
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: MwbSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: padding,
              child: MwbSectionHeading(
                overline: overline,
                title: title,
                actionLabel: 'See all',
                onAction: () => context.go(AppRoutes.discover),
              ),
            ),
            const SizedBox(height: MwbSpace.md),
            AsyncValueView<List<ContentItem>>(
              value: items,
              compact: true,
              onRetry: () => ref.invalidate(recommendedProvider(type)),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: padding,
                      child: const MwbEmptyState(
                        compact: true,
                        title: 'Nothing here yet',
                        message: 'New messages will appear as creators share them.',
                      ),
                    )
                  : ContentCarousel(items: list, padding: padding),
            ),
          ],
        ),
      ),
    );
  }
}
