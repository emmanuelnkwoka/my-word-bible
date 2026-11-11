import 'package:flutter/foundation.dart';

import 'bible.dart';
import 'content.dart';
import 'creator.dart';
import 'scripture_reference.dart';
import 'topic.dart';

/// Result categories. Designed to grow with future backend/semantic search.
enum SearchCategory {
  all('All'),
  scripture('Scripture'),
  topics('Topics'),
  audio('Audio'),
  video('Video'),
  articles('Articles'),
  creators('Creators'),
  saved('Saved');

  const SearchCategory(this.label);
  final String label;
}

@immutable
class SearchResults {
  const SearchResults({
    required this.query,
    this.reference,
    this.referencePassage,
    this.verses = const [],
    this.topics = const [],
    this.content = const [],
    this.creators = const [],
    this.saved = const [],
  });

  final String query;

  /// Set when the query parsed as a Scripture reference ("John 3:16").
  final ScriptureReference? reference;
  final Passage? referencePassage;
  final List<VerseSearchHit> verses;
  final List<Topic> topics;
  final List<ContentItem> content;
  final List<Creator> creators;

  /// Saved items (content the user saved) matching the query.
  final List<ContentItem> saved;

  List<ContentItem> ofType(ContentType t) => content.where((c) => c.type == t).toList();

  int countFor(SearchCategory c) => switch (c) {
    SearchCategory.all => totalCount,
    SearchCategory.scripture => verses.length + (referencePassage == null ? 0 : 1),
    SearchCategory.topics => topics.length,
    SearchCategory.audio => ofType(ContentType.audio).length,
    SearchCategory.video => ofType(ContentType.video).length,
    SearchCategory.articles => ofType(ContentType.article).length,
    SearchCategory.creators => creators.length,
    SearchCategory.saved => saved.length,
  };

  int get totalCount =>
      verses.length + (referencePassage == null ? 0 : 1) + topics.length + content.length + creators.length;

  bool get isEmpty => totalCount == 0 && saved.isEmpty;
}
