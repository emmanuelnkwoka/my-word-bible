import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/content.dart';
import '../../../data/models/search.dart';
import '../../bible/widgets/scripture_card.dart';
import '../../content/widgets/content_cards.dart';
import '../../creator/widgets/creator_widgets.dart';
import '../../discovery/application/content_providers.dart';
import '../../library/application/library_controllers.dart';
import '../application/search_controller.dart';

/// Unified search over Scripture, topics, content, creators and saved items.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(widget.initialQuery!, remember: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _run(String q, {bool remember = false}) {
    if (!mounted) return;
    ref.read(searchQueryProvider.notifier).set(q);
    if (remember) ref.read(recentSearchesProvider.notifier).add(q);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
  }

  void _useQuery(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _debounce?.cancel();
    _run(q, remember: true);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MwbConstrained(
              child: Padding(
                padding: const EdgeInsets.only(top: MwbSpace.xs, bottom: MwbSpace.sm),
                child: Row(
                  children: [
                    MwbIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => context.pop()),
                    const SizedBox(width: 4),
                    Expanded(
                      child: MwbSearchField(
                        key: const Key('search.field'),
                        controller: _controller,
                        autofocus: (widget.initialQuery ?? '').isEmpty,
                        hint: 'Scripture, topics, messages, creators',
                        onChanged: _onChanged,
                        onSubmitted: (q) {
                          _debounce?.cancel();
                          _run(q, remember: true);
                        },
                        onClear: () => _run(''),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: MwbMotion.medium,
                child: query.isEmpty
                    ? _SearchHome(key: const ValueKey('home'), onQuery: _useQuery)
                    : _SearchResultsView(
                        key: const ValueKey('results'),
                        onRemember: () => ref.read(recentSearchesProvider.notifier).add(query),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHome extends ConsumerWidget {
  const _SearchHome({super.key, required this.onQuery});
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final topics = ref.watch(primaryTopicsProvider).value ?? const [];
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: MwbLayout.pagePadding(context, top: MwbSpace.md, bottom: MwbSpace.xxxl),
      children: [
        if (recent.isNotEmpty) ...[
          MwbSectionHeading(
            title: 'Recent searches',
            actionLabel: 'Clear',
            onAction: () => ref.read(recentSearchesProvider.notifier).clear(),
          ),
          const SizedBox(height: MwbSpace.xs),
          for (final q in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded, color: c.textSecondary),
              title: Text(q, style: t.label.copyWith(fontSize: 15)),
              onTap: () => onQuery(q),
              trailing: MwbIconButton(
                icon: Icons.close_rounded,
                size: 18,
                tooltip: 'Remove $q from recent searches',
                onPressed: () => ref.read(recentSearchesProvider.notifier).remove(q),
              ),
            ),
          const SizedBox(height: MwbSpace.lg),
        ],
        const MwbSectionHeading(title: 'Try searching for'),
        const SizedBox(height: MwbSpace.sm),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [for (final s in searchSuggestions) MwbChip(label: s, onTap: () => onQuery(s))],
        ),
        const SizedBox(height: MwbSpace.xl),
        const MwbSectionHeading(title: 'Browse by topic'),
        const SizedBox(height: MwbSpace.sm),
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final topic in topics)
              MwbChip(label: topic.name, icon: Icons.tag_rounded, onTap: () => context.push(AppRoutes.topic(topic.id))),
          ],
        ),
        const SizedBox(height: MwbSpace.xl),
        const MwbNotice(
          message:
              'Search matches words in Scripture, titles, topics and creators on this device. '
              'Meaning-based search across all MWB content will come with online services.',
        ),
      ],
    );
  }
}

class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({super.key, required this.onRemember});
  final VoidCallback onRemember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final category = ref.watch(searchCategoryProvider);
    final gutter = MwbLayout.pagePadding(context);
    return AsyncValueView<SearchResults>(
      value: results,
      loadingMessage: 'Searching…',
      onRetry: () => ref.invalidate(searchResultsProvider),
      data: (r) {
        if (r.isEmpty) {
          return MwbEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results for “${r.query}”',
            message: 'Try a different word, a topic like “faith”, or a reference like “Psalm 23”.',
          );
        }
        return Listener(
          onPointerDown: (_) => onRemember(),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: MwbSpace.xxxl, top: gutter.top),
            children: [
              MwbChipRow(
                padding: gutter,
                children: [
                  for (final cat in SearchCategory.values)
                    if (cat == SearchCategory.all || r.countFor(cat) > 0)
                      MwbChip(
                        key: Key('search.category.${cat.name}'),
                        label: cat.label,
                        count: r.countFor(cat),
                        selected: category == cat,
                        onTap: () => ref.read(searchCategoryProvider.notifier).set(cat),
                      ),
                ],
              ),
              Padding(
                padding: gutter,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _sections(context, r, category)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sections(BuildContext context, SearchResults r, SearchCategory cat) {
    bool show(SearchCategory c) => cat == SearchCategory.all || cat == c;
    final out = <Widget>[];
    void section(String title, List<Widget> children) {
      if (children.isEmpty) return;
      out
        ..add(const SizedBox(height: MwbSpace.xl))
        ..add(MwbSectionHeading(title: title))
        ..add(const SizedBox(height: MwbSpace.xs))
        ..addAll(children);
    }

    if (show(SearchCategory.scripture)) {
      section('Scripture', [
        if (r.reference != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MwbSpace.sm),
            child: ScriptureCard(reference: r.reference!, overline: 'Reference match', maxLines: 8),
          ),
        for (final hit in r.verses.take(cat == SearchCategory.all ? 5 : 30))
          ScriptureSnippetTile(reference: hit.verse.reference, text: hit.verse.text),
      ]);
    }
    if (show(SearchCategory.topics)) {
      section('Topics', [
        Wrap(
          spacing: MwbSpace.xs,
          runSpacing: MwbSpace.xs,
          children: [
            for (final topic in r.topics)
              MwbChip(label: topic.name, icon: Icons.tag_rounded, onTap: () => context.push(AppRoutes.topic(topic.id))),
          ],
        ),
      ]);
    }
    for (final (c, type, title) in const [
      (SearchCategory.audio, ContentType.audio, 'Audio'),
      (SearchCategory.video, ContentType.video, 'Video'),
      (SearchCategory.articles, ContentType.article, 'Articles'),
    ]) {
      if (show(c)) section(title, [for (final i in r.ofType(type)) ContentListTile(item: i)]);
    }
    if (show(SearchCategory.creators)) {
      section('Creators', [for (final c in r.creators) CreatorTile(creator: c)]);
    }
    if (cat == SearchCategory.saved) {
      section('In your library', [for (final i in r.saved) ContentListTile(item: i)]);
    }
    return out;
  }
}
