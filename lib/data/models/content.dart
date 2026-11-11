import 'package:flutter/foundation.dart';

import 'scripture_reference.dart';

/// The kinds of Christian content MWB can represent.
enum ContentType {
  audio('Audio', 'Audio message'),
  video('Video', 'Video excerpt'),
  article('Article', 'Article'),
  scriptureReference('Scripture', 'Scripture passage');

  const ContentType(this.label, this.singular);
  final String label;
  final String singular;

  static ContentType fromName(String name) =>
      ContentType.values.firstWhere((t) => t.name == name, orElse: () => ContentType.article);
}

/// Moderation lifecycle for community-contributed content.
enum ModerationStatus { draft, pendingReview, approved, rejected, removed }

/// Where an item's media lives.
enum MediaSourceKind {
  /// Bundled with the app (sample media only in Foundation V1).
  asset,

  /// Hosted remotely (future MWB media service).
  remote,

  /// No playable media attached (e.g. preview-only video).
  none,
}

@immutable
class MediaSource {
  const MediaSource({required this.kind, this.uri, this.isSampleStandIn = false});

  const MediaSource.none() : this(kind: MediaSourceKind.none);

  final MediaSourceKind kind;
  final String? uri;

  /// True when the media is a generic stand-in (e.g. a sample tone) rather than
  /// the actual recording described by the item. The UI must disclose this.
  final bool isSampleStandIn;

  bool get isPlayable => kind != MediaSourceKind.none && uri != null;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'uri': uri, 'standIn': isSampleStandIn};

  factory MediaSource.fromJson(Map<String, dynamic> j) => MediaSource(
    kind: MediaSourceKind.values.byName(j['kind'] as String),
    uri: j['uri'] as String?,
    isSampleStandIn: j['standIn'] as bool? ?? false,
  );
}

/// Thumbnail description. Foundation V1 renders typographic artwork from a
/// tone index; [imageUrl] is reserved for hosted thumbnails.
@immutable
class ContentArtwork {
  const ContentArtwork({this.tone = 0, this.imageUrl, this.motif = ArtworkMotif.arcs});

  final int tone;
  final String? imageUrl;
  final ArtworkMotif motif;
}

enum ArtworkMotif { arcs, lines, rays, grid }

@immutable
class EngagementStats {
  const EngagementStats({this.views = 0, this.saves = 0, this.shares = 0, this.amens = 0});

  final int views;
  final int saves;
  final int shares;

  /// MWB's equivalent of a "like": a quiet affirmation.
  final int amens;

  Map<String, dynamic> toJson() => {'views': views, 'saves': saves, 'shares': shares, 'amens': amens};

  factory EngagementStats.fromJson(Map<String, dynamic> j) => EngagementStats(
    views: j['views'] as int? ?? 0,
    saves: j['saves'] as int? ?? 0,
    shares: j['shares'] as int? ?? 0,
    amens: j['amens'] as int? ?? 0,
  );
}

/// A unit of Christian content: audio message, video excerpt, article or
/// Scripture passage. Designed to map onto a future backend content table.
@immutable
class ContentItem {
  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.topicIds,
    required this.publishedAt,
    this.scriptureRefs = const [],
    this.durationSeconds,
    this.artwork = const ContentArtwork(),
    this.media = const MediaSource.none(),
    this.engagement = const EngagementStats(),
    this.isFeatured = false,
    this.moderationStatus = ModerationStatus.approved,
    this.body,
    this.sourceContentId,
    this.isSample = true,
  });

  final String id;
  final ContentType type;
  final String title;
  final String description;
  final String creatorId;
  final List<String> topicIds;
  final List<ScriptureReference> scriptureRefs;

  /// Running time of the described message (not necessarily the sample media).
  final int? durationSeconds;
  final DateTime publishedAt;
  final ContentArtwork artwork;
  final MediaSource media;
  final EngagementStats engagement;
  final bool isFeatured;
  final ModerationStatus moderationStatus;

  /// Long-form text for articles.
  final String? body;

  /// For audio extracted from a video: the source video's id.
  final String? sourceContentId;

  /// Foundation V1 content is illustrative sample data.
  final bool isSample;

  bool get isPlayableMedia => type == ContentType.audio || type == ContentType.video;

  Duration? get duration => durationSeconds == null ? null : Duration(seconds: durationSeconds!);
}
