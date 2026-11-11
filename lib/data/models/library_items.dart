import 'package:flutter/foundation.dart';

import 'content.dart';
import 'scripture_reference.dart';

DateTime _date(Object? v) => DateTime.tryParse('$v') ?? DateTime.fromMillisecondsSinceEpoch(0);

/// A reading place-marker on a verse.
@immutable
class Bookmark {
  const Bookmark({required this.reference, required this.versionId, required this.createdAt});

  final ScriptureReference reference;
  final String versionId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'ref': reference.toJson(), 'v': versionId, 'at': createdAt.toIso8601String()};
  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    versionId: j['v'] as String? ?? 'KJV',
    createdAt: _date(j['at']),
  );
}

/// Highlight tones map onto [MwbPalette.highlightTones] by index.
enum HighlightTone { gold, sage, sky, rose }

@immutable
class Highlight {
  const Highlight({required this.reference, required this.tone, required this.createdAt});

  /// Always a single verse.
  final ScriptureReference reference;
  final HighlightTone tone;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'ref': reference.toJson(), 'tone': tone.name, 'at': createdAt.toIso8601String()};
  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    tone: HighlightTone.values.asNameMap()[j['tone']] ?? HighlightTone.gold,
    createdAt: _date(j['at']),
  );
}

@immutable
class VerseNote {
  const VerseNote({
    required this.id,
    required this.reference,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ScriptureReference reference;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  VerseNote copyWith({String? text, DateTime? updatedAt}) => VerseNote(
    id: id,
    reference: reference,
    text: text ?? this.text,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ref': reference.toJson(),
    'text': text,
    'at': createdAt.toIso8601String(),
    'up': updatedAt.toIso8601String(),
  };
  factory VerseNote.fromJson(Map<String, dynamic> j) => VerseNote(
    id: j['id'] as String,
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    text: j['text'] as String? ?? '',
    createdAt: _date(j['at']),
    updatedAt: _date(j['up']),
  );
}

/// A verse or passage saved to the user's Scripture collection.
@immutable
class SavedScripture {
  const SavedScripture({required this.reference, required this.versionId, required this.savedAt});

  final ScriptureReference reference;
  final String versionId;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {'ref': reference.toJson(), 'v': versionId, 'at': savedAt.toIso8601String()};
  factory SavedScripture.fromJson(Map<String, dynamic> j) => SavedScripture(
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    versionId: j['v'] as String? ?? 'KJV',
    savedAt: _date(j['at']),
  );
}

@immutable
class SavedContent {
  const SavedContent({required this.contentId, required this.type, required this.savedAt});

  final String contentId;
  final ContentType type;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {'id': contentId, 'type': type.name, 'at': savedAt.toIso8601String()};
  factory SavedContent.fromJson(Map<String, dynamic> j) => SavedContent(
    contentId: j['id'] as String,
    type: ContentType.fromName(j['type'] as String? ?? ''),
    savedAt: _date(j['at']),
  );
}

@immutable
class ReadingHistoryEntry {
  const ReadingHistoryEntry({required this.reference, required this.versionId, required this.readAt});

  /// Chapter-level reference.
  final ScriptureReference reference;
  final String versionId;
  final DateTime readAt;

  Map<String, dynamic> toJson() => {'ref': reference.toJson(), 'v': versionId, 'at': readAt.toIso8601String()};
  factory ReadingHistoryEntry.fromJson(Map<String, dynamic> j) => ReadingHistoryEntry(
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    versionId: j['v'] as String? ?? 'KJV',
    readAt: _date(j['at']),
  );
}

@immutable
class RecentlyViewed {
  const RecentlyViewed({required this.contentId, required this.viewedAt});

  final String contentId;
  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {'id': contentId, 'at': viewedAt.toIso8601String()};
  factory RecentlyViewed.fromJson(Map<String, dynamic> j) =>
      RecentlyViewed(contentId: j['id'] as String, viewedAt: _date(j['at']));
}

/// A user-created collection of content items.
@immutable
class ContentCollection {
  const ContentCollection({required this.id, required this.name, required this.contentIds, required this.createdAt});

  final String id;
  final String name;
  final List<String> contentIds;
  final DateTime createdAt;

  ContentCollection copyWith({String? name, List<String>? contentIds}) => ContentCollection(
    id: id,
    name: name ?? this.name,
    contentIds: contentIds ?? this.contentIds,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'items': contentIds, 'at': createdAt.toIso8601String()};
  factory ContentCollection.fromJson(Map<String, dynamic> j) => ContentCollection(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Collection',
    contentIds: (j['items'] as List?)?.whereType<String>().toList() ?? const [],
    createdAt: _date(j['at']),
  );
}

/// Kinds of contribution the upload flow anticipates.
enum UploadKind {
  shortVideo('Short video', 'A short excerpt from a message or teaching'),
  audio('Audio message', 'An independently recorded audio message'),
  audioFromVideo('Audio from video', 'Extract the audio track from a video');

  const UploadKind(this.label, this.description);
  final String label;
  final String description;
}

/// A contribution prepared on the device, awaiting future upload/review.
@immutable
class UploadDraft {
  const UploadDraft({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.topicIds,
    required this.scriptureRefs,
    required this.attribution,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final UploadKind kind;
  final String title;
  final String description;
  final List<String> topicIds;
  final List<ScriptureReference> scriptureRefs;

  /// Who delivered the message (speaker/ministry), as entered by the user.
  final String attribution;
  final ModerationStatus status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'description': description,
    'topics': topicIds,
    'refs': scriptureRefs.map((r) => r.toJson()).toList(),
    'attribution': attribution,
    'status': status.name,
    'at': createdAt.toIso8601String(),
  };

  factory UploadDraft.fromJson(Map<String, dynamic> j) => UploadDraft(
    id: j['id'] as String,
    kind: UploadKind.values.asNameMap()[j['kind']] ?? UploadKind.shortVideo,
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    topicIds: (j['topics'] as List?)?.whereType<String>().toList() ?? const [],
    scriptureRefs:
        (j['refs'] as List?)?.whereType<Map<String, dynamic>>().map(ScriptureReference.fromJson).toList() ?? const [],
    attribution: j['attribution'] as String? ?? '',
    status: ModerationStatus.values.asNameMap()[j['status']] ?? ModerationStatus.draft,
    createdAt: _date(j['at']),
  );
}

enum ReportReason {
  misleading('Misleading or misrepresents Scripture'),
  inappropriate('Inappropriate content'),
  copyright('Copyright concern'),
  spam('Spam or promotion'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

@immutable
class ContentReport {
  const ContentReport({required this.contentId, required this.reason, required this.details, required this.createdAt});

  final String contentId;
  final ReportReason reason;
  final String details;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': contentId,
    'reason': reason.name,
    'details': details,
    'at': createdAt.toIso8601String(),
  };
  factory ContentReport.fromJson(Map<String, dynamic> j) => ContentReport(
    contentId: j['id'] as String,
    reason: ReportReason.values.asNameMap()[j['reason']] ?? ReportReason.other,
    details: j['details'] as String? ?? '',
    createdAt: _date(j['at']),
  );
}
