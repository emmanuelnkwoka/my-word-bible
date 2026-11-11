import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/mock/mock_topics.dart';
import '../../../data/models/content.dart';
import '../../../data/models/creator.dart';
import '../../../data/models/topic.dart';
import '../../profile/application/profile_controllers.dart';

final allContentProvider = FutureProvider<List<ContentItem>>(
  (ref) => ref.watch(contentRepositoryProvider).allContent(),
);

/// Fast id → item lookup (used by Library and Recently viewed).
final contentMapProvider = FutureProvider<Map<String, ContentItem>>((ref) async {
  final all = await ref.watch(allContentProvider.future);
  return {for (final c in all) c.id: c};
});

final contentByIdProvider = FutureProvider.family<ContentItem, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).contentById(id),
);

final featuredContentProvider = FutureProvider<List<ContentItem>>(
  (ref) => ref.watch(contentRepositoryProvider).featured(),
);

final recentContentProvider = FutureProvider<List<ContentItem>>(
  (ref) => ref.watch(contentRepositoryProvider).recent(limit: 8),
);

final topicsProvider = FutureProvider<List<Topic>>((ref) => ref.watch(contentRepositoryProvider).topics());

final primaryTopicsProvider = FutureProvider<List<Topic>>((ref) async {
  final all = await ref.watch(topicsProvider.future);
  final byId = {for (final t in all) t.id: t};
  return [for (final id in primaryTopicIds) ?byId[id]];
});

final trendingTopicsProvider = FutureProvider<List<Topic>>((ref) async {
  final all = await ref.watch(topicsProvider.future);
  return all.where((t) => t.isTrending).toList();
});

final topicProvider = FutureProvider.family<Topic, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).topicById(id),
);

final topicContentProvider = FutureProvider.family<List<ContentItem>, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).byTopic(id),
);

final creatorsProvider = FutureProvider<List<Creator>>((ref) => ref.watch(contentRepositoryProvider).creators());

final creatorMapProvider = FutureProvider<Map<String, Creator>>((ref) async {
  final all = await ref.watch(creatorsProvider.future);
  return {for (final c in all) c.id: c};
});

final creatorProvider = FutureProvider.family<Creator, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).creatorById(id),
);

final creatorContentProvider = FutureProvider.family<List<ContentItem>, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).byCreator(id),
);

/// Personalised recommendations of a given type, driven by onboarding
/// interests and discovery preferences.
final recommendedProvider = FutureProvider.family<List<ContentItem>, ContentType>((ref, type) {
  final topics = ref.watch(interestTopicIdsProvider);
  return ref.watch(contentRepositoryProvider).recommended(topicIds: topics, types: {type}, limit: 8);
});

/// Topics suggested for the user: their interest topics first, then trending.
final suggestedTopicsProvider = FutureProvider<List<Topic>>((ref) async {
  final all = await ref.watch(topicsProvider.future);
  final interestTopics = ref.watch(interestTopicIdsProvider);
  final preferred = all.where((t) => interestTopics.contains(t.id));
  final trending = all.where((t) => t.isTrending && !interestTopics.contains(t.id));
  return [...preferred, ...trending].take(8).toList();
});
