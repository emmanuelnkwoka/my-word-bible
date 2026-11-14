import 'dart:math';

import 'package:flutter/foundation.dart';

import 'daily_word.dart';
import 'scripture_reference.dart';

/// F1 personal records: reading sessions, activity, reflections. All stay on
/// the device in the encrypted personal store (`PersonalDatabase`).

/// Random (version 4) UUID from the platform CSPRNG. Stable record identity
/// that a future sync can use as an idempotency key.
String newRecordId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

final recordIdPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// Where a reading or reflection began. Stored as text.
enum PersonalOrigin {
  reader('Bible reader'),
  rhythm('Word rhythm'),
  dailyWord('Daily Word'),
  savedScripture('Saved Scripture'),
  independent('Written on its own');

  const PersonalOrigin(this.label);
  final String label;

  static PersonalOrigin parse(String? s) => values.asNameMap()[s] ?? PersonalOrigin.independent;
}

enum ReadingSessionStatus {
  /// Started by the user; not yet completed.
  active,

  /// The user chose "Complete reading".
  completed,

  /// The user ended it without completing.
  ended,
}

/// One user-initiated reading of a chapter. Only an explicit action creates
/// or completes one; opening a chapter never does.
@immutable
class ReadingSession {
  const ReadingSession({
    required this.id,
    required this.chapter,
    required this.versionId,
    required this.origin,
    required this.status,
    required this.startedAt,
    this.finishedAt,
  });

  final String id;

  /// Chapter reference (no verses).
  final ScriptureReference chapter;

  /// Canonical translation id (e.g. "KJV"), never a personalised edition.
  final String versionId;
  final PersonalOrigin origin;
  final ReadingSessionStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;

  bool get isActive => status == ReadingSessionStatus.active;
}

enum ActivityKind {
  /// The user chose "Complete reading" for a chapter.
  readingCompleted,

  /// The user saved a new reflection.
  reflectionWritten,
}

/// Append-only, private record of a personal action.
@immutable
class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.localDate,
    required this.tzOffsetMinutes,
    this.reference,
    this.versionId,
    this.sessionId,
    this.journalId,
  });

  final String id;
  final ActivityKind kind;

  /// UTC instant.
  final DateTime occurredAt;

  /// Calendar date on the device when it happened (`yyyy-mm-dd`).
  final String localDate;
  final int tzOffsetMinutes;
  final ScriptureReference? reference;
  final String? versionId;
  final String? sessionId;
  final String? journalId;
}

/// Activity on one calendar day.
@immutable
class RhythmDay {
  const RhythmDay({required this.dateKey, this.readings = 0, this.reflections = 0});
  final String dateKey;
  final int readings;
  final int reflections;

  bool get hasActivity => readings > 0 || reflections > 0;
}

/// A calendar week (Monday to Sunday). Counts only; no scores.
@immutable
class RhythmWeek {
  const RhythmWeek({required this.start, required this.days});

  /// Monday.
  final DateTime start;

  /// Seven entries, Monday first.
  final List<RhythmDay> days;

  int get readingsCompleted => days.fold(0, (s, d) => s + d.readings);
  int get reflectionsWritten => days.fold(0, (s, d) => s + d.reflections);
  int get daysWithScripture => days.where((d) => d.hasActivity).length;
  bool get isEmpty => readingsCompleted == 0 && reflectionsWritten == 0;
}

/// Monday of the week containing [day].
DateTime weekStartOf(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// The seven date keys of the week starting [monday].
List<String> weekDateKeys(DateTime monday) => [
  for (var i = 0; i < 7; i++) dateKeyOf(DateTime(monday.year, monday.month, monday.day + i)),
];

// ---------------------------------------------------------------------------
// Journal
// ---------------------------------------------------------------------------

/// A private reflection. Personal writing, never Scripture: it links to a
/// canonical reference but never stores verse text.
@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
    required this.body,
    required this.source,
    this.reference,
    this.versionId,
    this.dailyWordDate,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String body;
  final PersonalOrigin source;
  final ScriptureReference? reference;

  /// Canonical translation of [reference].
  final String? versionId;

  /// The Daily Word date this reflection responded to.
  final String? dailyWordDate;

  bool get isLinked => reference != null;

  /// Title, or the first line of the body.
  String get heading {
    if (title.trim().isNotEmpty) return title.trim();
    final line = body.trim().split('\n').first.trim();
    return line.length <= 60 ? line : '${line.substring(0, 57)}…';
  }
}

/// What the user writes; ids and timestamps are assigned by the repository.
@immutable
class JournalDraft {
  const JournalDraft({
    this.title = '',
    required this.body,
    this.reference,
    this.versionId,
    this.source = PersonalOrigin.independent,
    this.dailyWordDate,
  });

  final String title;
  final String body;
  final ScriptureReference? reference;
  final String? versionId;
  final PersonalOrigin source;
  final String? dailyWordDate;
}

/// Filters for the journal list. All conditions combine (AND).
@immutable
class JournalQuery {
  const JournalQuery({this.text = '', this.source, this.linked, this.bookId});

  /// Case-insensitive match in title or body.
  final String text;
  final PersonalOrigin? source;

  /// true: linked to Scripture only; false: unlinked only; null: either.
  final bool? linked;
  final String? bookId;

  bool get isEmpty => text.trim().isEmpty && source == null && linked == null && bookId == null;

  JournalQuery copyWith({String? text, Object? source = _keep, Object? linked = _keep, Object? bookId = _keep}) =>
      JournalQuery(
        text: text ?? this.text,
        source: identical(source, _keep) ? this.source : source as PersonalOrigin?,
        linked: identical(linked, _keep) ? this.linked : linked as bool?,
        bookId: identical(bookId, _keep) ? this.bookId : bookId as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is JournalQuery &&
      other.text == text &&
      other.source == source &&
      other.linked == linked &&
      other.bookId == bookId;

  @override
  int get hashCode => Object.hash(text, source, linked, bookId);
}

const _keep = Object();

/// Encodes a reference for a route query (`ROM.8.37-39`, `JHN.3`).
String encodeReference(ScriptureReference r) {
  final base = '${r.bookId}.${r.chapter}';
  if (r.verseStart == null) return base;
  final end = r.verseEnd != null && r.verseEnd != r.verseStart ? '-${r.verseEnd}' : '';
  return '$base.${r.verseStart}$end';
}

final _encodedRef = RegExp(r'^([1-3]?[A-Z]{2,3})\.(\d{1,3})(?:\.(\d{1,3})(?:-(\d{1,3}))?)?$');

ScriptureReference? decodeReference(String? s) {
  if (s == null) return null;
  final m = _encodedRef.firstMatch(s);
  if (m == null) return null;
  return ScriptureReference(
    bookId: m.group(1)!,
    chapter: int.parse(m.group(2)!),
    verseStart: m.group(3) == null ? null : int.parse(m.group(3)!),
    verseEnd: m.group(4) == null ? null : int.parse(m.group(4)!),
  );
}
