import '../../core/errors/app_failure.dart';
import '../../core/network/api_client.dart';
import '../mock/mock_content.dart';
import '../mock/mock_creators.dart';
import '../mock/mock_topics.dart';
import '../models/content.dart';
import '../models/creator.dart';
import '../models/topic.dart';

/// Christian content, topics and creators.
abstract interface class ContentRepository {
  Future<List<ContentItem>> allContent();
  Future<ContentItem> contentById(String id);
  Future<List<ContentItem>> featured();
  Future<List<ContentItem>> recent({int limit = 8});
  Future<List<ContentItem>> byTopic(String topicId);
  Future<List<ContentItem>> byCreator(String creatorId);
  Future<List<ContentItem>> recommended({required Set<String> topicIds, Set<ContentType>? types, int limit = 8});

  /// Keyword search over titles, descriptions, topics, creators and references.
  Future<List<ContentItem>> search(String query, {Set<ContentType>? types});

  Future<List<Topic>> topics();
  Future<Topic> topicById(String id);
  Future<List<Topic>> searchTopics(String query);

  Future<List<Creator>> creators();
  Future<Creator> creatorById(String id);
  Future<List<Creator>> searchCreators(String query);
}

/// Serves the local sample dataset. [latency] simulates network timing so
/// loading states are exercised; tests pass [Duration.zero].
class MockContentRepository implements ContentRepository {
  MockContentRepository({
    this.latency = const Duration(milliseconds: 220),
    List<ContentItem>? content,
    List<Topic>? topics,
    List<Creator>? creators,
  }) : _content = content ?? mockContent,
       _topics = topics ?? mockTopics,
       _creators = creators ?? mockCreators;

  final Duration latency;
  final List<ContentItem> _content;
  final List<Topic> _topics;
  final List<Creator> _creators;

  Future<T> _delay<T>(T Function() fn) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return fn();
  }

  Iterable<ContentItem> get _visible => _content.where((c) => c.moderationStatus == ModerationStatus.approved);

  @override
  Future<List<ContentItem>> allContent() => _delay(() => _visible.toList());

  @override
  Future<ContentItem> contentById(String id) => _delay(() {
    for (final c in _content) {
      if (c.id == id) return c;
    }
    throw const NotFoundFailure('This content is no longer available.');
  });

  @override
  Future<List<ContentItem>> featured() => _delay(() => _visible.where((c) => c.isFeatured).toList());

  @override
  Future<List<ContentItem>> recent({int limit = 8}) => _delay(() {
    final list = _visible.toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return list.take(limit).toList();
  });

  @override
  Future<List<ContentItem>> byTopic(String topicId) => _delay(
    () =>
        _visible.where((c) => c.topicIds.contains(topicId)).toList()
          ..sort((a, b) => b.engagement.amens.compareTo(a.engagement.amens)),
  );

  @override
  Future<List<ContentItem>> byCreator(String creatorId) => _delay(
    () =>
        _visible.where((c) => c.creatorId == creatorId).toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
  );

  @override
  Future<List<ContentItem>> recommended({required Set<String> topicIds, Set<ContentType>? types, int limit = 8}) =>
      _delay(() {
        final pool = _visible.where((c) => types == null || types.contains(c.type));
        final scored = pool.map((c) {
          final overlap = c.topicIds.where(topicIds.contains).length;
          final score = overlap * 1000 + (c.isFeatured ? 300 : 0) + c.engagement.amens ~/ 10;
          return (c, score);
        }).toList()..sort((a, b) => b.$2.compareTo(a.$2));
        return scored.map((e) => e.$1).take(limit).toList();
      });

  List<String> _tokens(String q) => q.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 1).toList();

  @override
  Future<List<ContentItem>> search(String query, {Set<ContentType>? types}) => _delay(() {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return <ContentItem>[];
    final topicsById = {for (final t in _topics) t.id: t};
    final creatorsById = {for (final c in _creators) c.id: c};
    final scored = <(ContentItem, int)>[];
    for (final c in _visible) {
      if (types != null && !types.contains(c.type)) continue;
      final title = c.title.toLowerCase();
      final desc = c.description.toLowerCase();
      final topicText = c.topicIds
          .map((id) => topicsById[id])
          .whereType<Topic>()
          .expand((t) => [t.name, ...t.keywords])
          .join(' ')
          .toLowerCase();
      final creator = creatorsById[c.creatorId]?.displayName.toLowerCase() ?? '';
      final refs = c.scriptureRefs.map((r) => r.label).join(' ').toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (title.contains(t)) score += 5;
        if (topicText.contains(t)) score += 4;
        if (creator.contains(t)) score += 3;
        if (refs.contains(t)) score += 3;
        if (desc.contains(t)) score += 1;
      }
      if (score > 0) scored.add((c, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  });

  @override
  Future<List<Topic>> topics() => _delay(() => List.of(_topics));

  @override
  Future<Topic> topicById(String id) => _delay(() {
    for (final t in _topics) {
      if (t.id == id) return t;
    }
    throw const NotFoundFailure('This topic could not be found.');
  });

  @override
  Future<List<Topic>> searchTopics(String query) => _delay(() {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return <Topic>[];
    return _topics.where((t) {
      final hay = [t.name, ...t.keywords].join(' ').toLowerCase();
      return tokens.any(hay.contains);
    }).toList();
  });

  @override
  Future<List<Creator>> creators() => _delay(() => List.of(_creators));

  @override
  Future<Creator> creatorById(String id) => _delay(() {
    for (final c in _creators) {
      if (c.id == id) return c;
    }
    throw const NotFoundFailure('This creator could not be found.');
  });

  @override
  Future<List<Creator>> searchCreators(String query) => _delay(() {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return <Creator>[];
    return _creators.where((c) => tokens.any((t) => '${c.displayName} ${c.role}'.toLowerCase().contains(t))).toList();
  });
}

/// Placeholder for the redesigned MWB content API.
///
/// Endpoint paths and payloads will be defined with the new Laravel backend;
/// until then every call reports that online content is unavailable rather
/// than guessing at an unfinished API.
class RemoteContentRepository implements ContentRepository {
  RemoteContentRepository(this._api);

  // ignore: unused_field
  final ApiClient _api;

  Never _unavailable() =>
      throw const FeatureUnavailableFailure('Online content will be available when MWB services launch.');

  @override
  Future<List<ContentItem>> allContent() async => _unavailable();
  @override
  Future<ContentItem> contentById(String id) async => _unavailable();
  @override
  Future<List<ContentItem>> featured() async => _unavailable();
  @override
  Future<List<ContentItem>> recent({int limit = 8}) async => _unavailable();
  @override
  Future<List<ContentItem>> byTopic(String topicId) async => _unavailable();
  @override
  Future<List<ContentItem>> byCreator(String creatorId) async => _unavailable();
  @override
  Future<List<ContentItem>> recommended({
    required Set<String> topicIds,
    Set<ContentType>? types,
    int limit = 8,
  }) async => _unavailable();
  @override
  Future<List<ContentItem>> search(String query, {Set<ContentType>? types}) async => _unavailable();
  @override
  Future<List<Topic>> topics() async => _unavailable();
  @override
  Future<Topic> topicById(String id) async => _unavailable();
  @override
  Future<List<Topic>> searchTopics(String query) async => _unavailable();
  @override
  Future<List<Creator>> creators() async => _unavailable();
  @override
  Future<Creator> creatorById(String id) async => _unavailable();
  @override
  Future<List<Creator>> searchCreators(String query) async => _unavailable();
}
