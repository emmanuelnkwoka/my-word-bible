import 'package:flutter/foundation.dart';

import 'scripture_reference.dart';

/// A Christian topic used for discovery (e.g. Fear, Faith, Prayer).
@immutable
class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.summary,
    required this.keyScriptures,
    this.relatedTopicIds = const [],
    this.keywords = const [],
    this.isTrending = false,
  });

  final String id;
  final String name;

  /// Short editorial description (MWB's own words, not Scripture).
  final String summary;
  final List<ScriptureReference> keyScriptures;
  final List<String> relatedTopicIds;

  /// Extra search terms ("afraid", "anxiety", ...).
  final List<String> keywords;
  final bool isTrending;
}
