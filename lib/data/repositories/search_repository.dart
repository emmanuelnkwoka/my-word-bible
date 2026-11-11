import '../models/bible.dart';
import '../models/content.dart';
import '../models/scripture_reference.dart';
import '../models/search.dart';
import 'bible_repository.dart';
import 'content_repository.dart';

/// Unified search across Scripture, topics, content and creators.
///
/// Foundation V1 performs keyword matching on the device. A future
/// implementation can call a backend (including meaning-based search)
/// behind the same interface.
abstract interface class SearchRepository {
  Future<SearchResults> search(String query, {required String versionId, Set<String> savedContentIds = const {}});
}

class LocalSearchRepository implements SearchRepository {
  LocalSearchRepository(this._bible, this._content);

  final BibleRepository _bible;
  final ContentRepository _content;

  @override
  Future<SearchResults> search(
    String query, {
    required String versionId,
    Set<String> savedContentIds = const {},
  }) async {
    final q = query.trim();
    if (q.isEmpty) return SearchResults(query: q);

    final reference = ScriptureReference.tryParse(q);
    Passage? passage;
    if (reference != null) {
      try {
        passage = await _bible.passage(versionId, reference);
      } catch (_) {
        passage = null; // e.g. verse number beyond the chapter
      }
    }

    final (verses, topics, matched, creators) = await (
      reference == null ? _bible.search(versionId, q, limit: 30) : Future.value(<VerseSearchHit>[]),
      _content.searchTopics(q),
      _content.search(q),
      _content.searchCreators(q),
    ).wait;
    final content = List<ContentItem>.of(matched);

    // Topic matches pull in their related content so that e.g. "fear" shows
    // audio and video tagged Fear even if the word is not in the title.
    final topicIds = topics.map((t) => t.id).toSet();
    if (topicIds.isNotEmpty) {
      final all = await _content.allContent();
      final seen = content.map((c) => c.id).toSet();
      for (final c in all) {
        if (!seen.contains(c.id) && c.topicIds.any(topicIds.contains)) {
          content.add(c);
          seen.add(c.id);
        }
      }
    }

    return SearchResults(
      query: q,
      reference: passage == null ? null : reference,
      referencePassage: passage,
      verses: verses,
      topics: topics,
      content: content,
      creators: creators,
      saved: content.where((c) => savedContentIds.contains(c.id)).toList(),
    );
  }
}
