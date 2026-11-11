import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/content.dart';

/// Content-type filter used by Discover and topic pages.
enum ContentFilter {
  all('All', null),
  scripture('Scripture', ContentType.scriptureReference),
  audio('Audio', ContentType.audio),
  video('Video', ContentType.video),
  articles('Articles', ContentType.article);

  const ContentFilter(this.label, this.type);
  final String label;
  final ContentType? type;

  bool matches(ContentItem item) => type == null || item.type == type;

  /// Whether Scripture passages (not content items) should be shown.
  bool get showsScripture => this == all || this == scripture;
}

List<ContentItem> applyFilter(List<ContentItem> items, ContentFilter f) => items.where(f.matches).toList();

final discoverFilterProvider = NotifierProvider<DiscoverFilterController, ContentFilter>(DiscoverFilterController.new);

class DiscoverFilterController extends Notifier<ContentFilter> {
  @override
  ContentFilter build() => ContentFilter.all;
  void set(ContentFilter f) => state = f;
}
