import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/models/search.dart';
import '../../bible/application/bible_providers.dart';
import '../../library/application/library_controllers.dart';

/// The active (debounced) search query.
final searchQueryProvider = NotifierProvider.autoDispose<SearchQueryController, String>(SearchQueryController.new);

class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q.trim();
}

final searchCategoryProvider = NotifierProvider.autoDispose<SearchCategoryController, SearchCategory>(
  SearchCategoryController.new,
);

class SearchCategoryController extends Notifier<SearchCategory> {
  @override
  SearchCategory build() => SearchCategory.all;
  void set(SearchCategory c) => state = c;
}

final searchResultsProvider = FutureProvider.autoDispose<SearchResults>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return SearchResults(query: query);
  final version = ref.watch(textVersionProvider);
  final saved = ref.watch(savedContentIdsProvider);
  return ref.watch(searchRepositoryProvider).search(query, versionId: version.id, savedContentIds: saved);
});

/// Suggestions shown before the user types.
const searchSuggestions = <String>[
  'Fear',
  'John 3:16',
  'Prayer',
  'Psalm 23',
  'Peace',
  'Wisdom',
  'Forgiveness',
  'Romans 8',
];
