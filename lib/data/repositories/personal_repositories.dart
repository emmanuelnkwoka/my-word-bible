import 'package:sqlite3/sqlite3.dart';

import '../local/personal_database.dart';
import '../models/bible_canon.dart';
import '../models/daily_word.dart';
import '../models/personal_rhythm.dart';
import '../models/scripture_reference.dart';

/// Result of "Complete reading".
sealed class CompletionResult {
  const CompletionResult(this.record);
  final ActivityRecord record;
}

class ReadingCompleted extends CompletionResult {
  const ReadingCompleted(super.record);
}

/// The chapter was already completed today; nothing new was recorded.
class AlreadyCompletedToday extends CompletionResult {
  const AlreadyCompletedToday(super.record);
}

class PersonalDataException implements Exception {
  const PersonalDataException(this.message);

  /// User-safe message. Never contains reflection text.
  final String message;

  @override
  String toString() => 'PersonalDataException($message)';
}

/// Checks a reference against the canon (book, chapter range, verse order).
/// Verse existence in a translation is checked by the caller with the Bible.
ScriptureReference validCanonicalReference(ScriptureReference r) {
  final book = BibleCanon.byId(r.bookId);
  if (book == null) throw const PersonalDataException('Unknown book');
  if (r.chapter < 1 || r.chapter > book.chapterCount) throw const PersonalDataException('Unknown chapter');
  final vs = r.verseStart;
  final ve = r.verseEnd;
  if (vs == null && ve != null) throw const PersonalDataException('Invalid verse range');
  if (vs != null && vs < 1) throw const PersonalDataException('Invalid verse');
  if (vs != null && ve != null && ve < vs) throw const PersonalDataException('Invalid verse range');
  return ScriptureReference(bookId: book.id, chapter: r.chapter, verseStart: vs, verseEnd: ve == vs ? null : ve);
}

String _iso(DateTime t) => t.toUtc().toIso8601String();
DateTime _parse(Object? v) => DateTime.parse(v! as String);

ScriptureReference? _refFrom(Row r) {
  final book = r['book_id'] as String?;
  final chapter = r['chapter'] as int?;
  if (book == null || chapter == null) return null;
  return ScriptureReference(
    bookId: book,
    chapter: chapter,
    verseStart: r['verse_start'] as int?,
    verseEnd: r['verse_end'] as int?,
  );
}

// ---------------------------------------------------------------------------
// Rhythm
// ---------------------------------------------------------------------------

/// Reading sessions and the private activity ledger.
abstract interface class RhythmRepository {
  ReadingSession? activeSession();
  ReadingSession? sessionById(String id);

  /// Starts a user-initiated session. An earlier active session is ended
  /// (not completed): only one reading session is open at a time.
  ReadingSession startSession(ScriptureReference chapter, {required String versionId, required PersonalOrigin origin});

  /// Ends a session without completing it.
  void endSession(String id);

  /// The explicit "Complete reading" action. One completion per chapter per
  /// local day: a second call returns [AlreadyCompletedToday].
  CompletionResult completeReading(
    ScriptureReference chapter, {
    required String versionId,
    required PersonalOrigin origin,
    DateTime? openedAt,
  });

  /// Today's completion of [chapter], if any.
  ActivityRecord? completionOn(ScriptureReference chapter, String dateKey);

  /// Removes a completion (and its session). Used for "Undo" and history edits.
  void removeCompletion(String activityId);

  List<ActivityRecord> completedReadings({int? limit});
  List<ActivityRecord> activityBetween(String fromDateKey, String toDateKey);
  Map<String, RhythmDay> daysBetween(String fromDateKey, String toDateKey);
  RhythmWeek week(DateTime anyDay);

  /// Deletes every reading session and reading record (reflections stay).
  void clearReadingActivity();
  int readingCount();
}

class SqlRhythmRepository implements RhythmRepository {
  SqlRhythmRepository(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final PersonalDatabase _store;
  final DateTime Function() _clock;
  Database get _db => _store.db;

  static ReadingSession _session(Row r) => ReadingSession(
    id: r['id'] as String,
    chapter: ScriptureReference(bookId: r['book_id'] as String, chapter: r['chapter'] as int),
    versionId: r['version_id'] as String,
    origin: PersonalOrigin.parse(r['origin'] as String?),
    status: ReadingSessionStatus.values.byName(r['status'] as String),
    startedAt: _parse(r['started_at']),
    finishedAt: r['finished_at'] == null ? null : _parse(r['finished_at']),
  );

  static ActivityRecord _record(Row r) => ActivityRecord(
    id: r['id'] as String,
    kind: ActivityKind.values.byName(r['kind'] as String),
    occurredAt: _parse(r['occurred_at']),
    localDate: r['local_date'] as String,
    tzOffsetMinutes: r['tz_offset_min'] as int,
    reference: _refFrom(r),
    versionId: r['version_id'] as String?,
    sessionId: r['session_id'] as String?,
    journalId: r['journal_id'] as String?,
  );

  static String completionKey(ScriptureReference chapter, String dateKey) =>
      'readingCompleted:${chapter.bookId}.${chapter.chapter}:$dateKey';

  @override
  ReadingSession? activeSession() {
    final rows = _db.select("SELECT * FROM reading_sessions WHERE status = 'active' ORDER BY started_at DESC LIMIT 1");
    return rows.isEmpty ? null : _session(rows.first);
  }

  @override
  ReadingSession? sessionById(String id) {
    final rows = _db.select('SELECT * FROM reading_sessions WHERE id = ?', [id]);
    return rows.isEmpty ? null : _session(rows.first);
  }

  @override
  ReadingSession startSession(ScriptureReference chapter, {required String versionId, required PersonalOrigin origin}) {
    final c = validCanonicalReference(chapter.chapterOnly);
    final now = _clock();
    final id = newRecordId();
    _store.transaction(() {
      _db.execute("UPDATE reading_sessions SET status = 'ended', finished_at = ? WHERE status = 'active'", [_iso(now)]);
      _db.execute(
        "INSERT INTO reading_sessions(id, book_id, chapter, version_id, origin, status, started_at) "
        "VALUES (?, ?, ?, ?, ?, 'active', ?)",
        [id, c.bookId, c.chapter, versionId, origin.name, _iso(now)],
      );
    });
    return sessionById(id)!;
  }

  @override
  void endSession(String id) => _db.execute(
    "UPDATE reading_sessions SET status = 'ended', finished_at = ? WHERE id = ? AND status = 'active'",
    [_iso(_clock()), id],
  );

  @override
  CompletionResult completeReading(
    ScriptureReference chapter, {
    required String versionId,
    required PersonalOrigin origin,
    DateTime? openedAt,
  }) {
    final c = validCanonicalReference(chapter.chapterOnly);
    final now = _clock();
    final dateKey = dateKeyOf(now);
    return _store.transaction(() {
      final existing = completionOn(c, dateKey);
      if (existing != null) return AlreadyCompletedToday(existing);
      final active = _db.select(
        "SELECT * FROM reading_sessions WHERE status = 'active' AND book_id = ? AND chapter = ? LIMIT 1",
        [c.bookId, c.chapter],
      );
      final String sessionId;
      if (active.isNotEmpty) {
        sessionId = active.first['id'] as String;
        _db.execute("UPDATE reading_sessions SET status = 'completed', finished_at = ?, version_id = ? WHERE id = ?", [
          _iso(now),
          versionId,
          sessionId,
        ]);
      } else {
        sessionId = newRecordId();
        final started = openedAt == null || openedAt.isAfter(now) ? now : openedAt;
        _db.execute(
          "INSERT INTO reading_sessions(id, book_id, chapter, version_id, origin, status, started_at, finished_at) "
          "VALUES (?, ?, ?, ?, ?, 'completed', ?, ?)",
          [sessionId, c.bookId, c.chapter, versionId, origin.name, _iso(started), _iso(now)],
        );
      }
      final id = newRecordId();
      _db.execute(
        'INSERT INTO activity_records(id, kind, occurred_at, local_date, tz_offset_min, book_id, chapter, '
        'version_id, session_id, dedupe_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          ActivityKind.readingCompleted.name,
          _iso(now),
          dateKey,
          now.timeZoneOffset.inMinutes,
          c.bookId,
          c.chapter,
          versionId,
          sessionId,
          completionKey(c, dateKey),
        ],
      );
      return ReadingCompleted(_record(_db.select('SELECT * FROM activity_records WHERE id = ?', [id]).first));
    });
  }

  @override
  ActivityRecord? completionOn(ScriptureReference chapter, String dateKey) {
    final rows = _db.select('SELECT * FROM activity_records WHERE dedupe_key = ?', [
      completionKey(chapter.chapterOnly, dateKey),
    ]);
    return rows.isEmpty ? null : _record(rows.first);
  }

  @override
  void removeCompletion(String activityId) => _store.transaction(() {
    final rows = _db.select('SELECT session_id FROM activity_records WHERE id = ? AND kind = ?', [
      activityId,
      ActivityKind.readingCompleted.name,
    ]);
    if (rows.isEmpty) return;
    final session = rows.first['session_id'] as String?;
    _db.execute('DELETE FROM activity_records WHERE id = ?', [activityId]);
    if (session != null) _db.execute('DELETE FROM reading_sessions WHERE id = ?', [session]);
  });

  @override
  List<ActivityRecord> completedReadings({int? limit}) => [
    for (final r in _db.select(
      'SELECT * FROM activity_records WHERE kind = ? ORDER BY occurred_at DESC${limit == null ? '' : ' LIMIT $limit'}',
      [ActivityKind.readingCompleted.name],
    ))
      _record(r),
  ];

  @override
  List<ActivityRecord> activityBetween(String fromDateKey, String toDateKey) => [
    for (final r in _db.select(
      'SELECT * FROM activity_records WHERE local_date BETWEEN ? AND ? ORDER BY occurred_at DESC',
      [fromDateKey, toDateKey],
    ))
      _record(r),
  ];

  @override
  Map<String, RhythmDay> daysBetween(String fromDateKey, String toDateKey) {
    final rows = _db.select(
      'SELECT local_date, '
      "SUM(kind = 'readingCompleted') AS readings, SUM(kind = 'reflectionWritten') AS reflections "
      'FROM activity_records WHERE local_date BETWEEN ? AND ? GROUP BY local_date',
      [fromDateKey, toDateKey],
    );
    return {
      for (final r in rows)
        r['local_date'] as String: RhythmDay(
          dateKey: r['local_date'] as String,
          readings: r['readings'] as int,
          reflections: r['reflections'] as int,
        ),
    };
  }

  @override
  RhythmWeek week(DateTime anyDay) {
    final monday = weekStartOf(anyDay);
    final keys = weekDateKeys(monday);
    final days = daysBetween(keys.first, keys.last);
    return RhythmWeek(
      start: monday,
      days: [for (final k in keys) days[k] ?? RhythmDay(dateKey: k)],
    );
  }

  @override
  void clearReadingActivity() {
    _store.transaction(() {
      _db.execute('DELETE FROM activity_records WHERE kind = ?', [ActivityKind.readingCompleted.name]);
      _db.execute('DELETE FROM reading_sessions');
    });
    _store.vacuum();
  }

  @override
  int readingCount() =>
      _db.select('SELECT count(*) AS n FROM activity_records WHERE kind = ?', [
            ActivityKind.readingCompleted.name,
          ]).first['n']
          as int;
}

// ---------------------------------------------------------------------------
// Journal
// ---------------------------------------------------------------------------

/// Private reflections. Text never leaves this repository except through an
/// explicit user export.
abstract interface class JournalRepository {
  JournalEntry create(JournalDraft draft);
  JournalEntry update(String id, JournalDraft draft);
  void delete(String id);
  void deleteAll();
  JournalEntry? byId(String id);
  List<JournalEntry> search(JournalQuery query);

  /// Reflections whose reference overlaps [reference] (same chapter; verse
  /// ranges intersect, or either side is a whole chapter).
  List<JournalEntry> forReference(ScriptureReference reference);
  int count();

  /// Book ids used by linked reflections, in canonical order.
  List<String> books();
}

class SqlJournalRepository implements JournalRepository {
  SqlJournalRepository(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final PersonalDatabase _store;
  final DateTime Function() _clock;
  Database get _db => _store.db;

  static const maxBodyLength = 20000;
  static const maxTitleLength = 120;

  static JournalEntry _entry(Row r) => JournalEntry(
    id: r['id'] as String,
    createdAt: _parse(r['created_at']),
    updatedAt: _parse(r['updated_at']),
    title: r['title'] as String,
    body: r['body'] as String,
    source: PersonalOrigin.parse(r['source'] as String?),
    reference: _refFrom(r),
    versionId: r['version_id'] as String?,
    dailyWordDate: r['daily_word_date'] as String?,
  );

  ({String title, String body, ScriptureReference? ref}) _clean(JournalDraft d) {
    final body = d.body.trim();
    final title = d.title.trim();
    if (body.isEmpty) throw const PersonalDataException('Write something before saving');
    if (body.length > maxBodyLength) throw const PersonalDataException('This reflection is too long');
    if (title.length > maxTitleLength) throw const PersonalDataException('The title is too long');
    final ref = d.reference == null ? null : validCanonicalReference(d.reference!);
    if (ref != null && (d.versionId == null || d.versionId!.isEmpty)) {
      throw const PersonalDataException('A translation is required for a linked reflection');
    }
    return (title: title, body: body, ref: ref);
  }

  @override
  JournalEntry create(JournalDraft draft) {
    final c = _clean(draft);
    final now = _clock();
    final id = newRecordId();
    _store.transaction(() {
      _db.execute(
        'INSERT INTO journal_entries(id, created_at, updated_at, title, body, book_id, chapter, verse_start, '
        'verse_end, version_id, source, daily_word_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          _iso(now),
          _iso(now),
          c.title,
          c.body,
          c.ref?.bookId,
          c.ref?.chapter,
          c.ref?.verseStart,
          c.ref?.verseEnd,
          c.ref == null ? null : draft.versionId,
          draft.source.name,
          draft.dailyWordDate,
        ],
      );
      _db.execute(
        'INSERT INTO activity_records(id, kind, occurred_at, local_date, tz_offset_min, book_id, chapter, '
        'verse_start, verse_end, version_id, journal_id, dedupe_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          newRecordId(),
          ActivityKind.reflectionWritten.name,
          _iso(now),
          dateKeyOf(now),
          now.timeZoneOffset.inMinutes,
          c.ref?.bookId,
          c.ref?.chapter,
          c.ref?.verseStart,
          c.ref?.verseEnd,
          c.ref == null ? null : draft.versionId,
          id,
          'reflectionWritten:$id',
        ],
      );
    });
    return byId(id)!;
  }

  @override
  JournalEntry update(String id, JournalDraft draft) {
    final c = _clean(draft);
    if (byId(id) == null) throw const PersonalDataException('This reflection no longer exists');
    _db.execute(
      'UPDATE journal_entries SET updated_at = ?, title = ?, body = ?, book_id = ?, chapter = ?, verse_start = ?, '
      'verse_end = ?, version_id = ? WHERE id = ?',
      [
        _iso(_clock()),
        c.title,
        c.body,
        c.ref?.bookId,
        c.ref?.chapter,
        c.ref?.verseStart,
        c.ref?.verseEnd,
        c.ref == null ? null : draft.versionId,
        id,
      ],
    );
    return byId(id)!;
  }

  @override
  void delete(String id) => _store.transaction(() {
    _db.execute('DELETE FROM journal_entries WHERE id = ?', [id]);
    _db.execute('DELETE FROM activity_records WHERE journal_id = ?', [id]);
  });

  @override
  void deleteAll() {
    _store.transaction(() {
      _db.execute('DELETE FROM journal_entries');
      _db.execute('DELETE FROM activity_records WHERE kind = ?', [ActivityKind.reflectionWritten.name]);
    });
    _store.vacuum();
  }

  @override
  JournalEntry? byId(String id) {
    final rows = _db.select('SELECT * FROM journal_entries WHERE id = ?', [id]);
    return rows.isEmpty ? null : _entry(rows.first);
  }

  @override
  List<JournalEntry> search(JournalQuery q) {
    final where = <String>[];
    final args = <Object?>[];
    final text = q.text.trim();
    if (text.isNotEmpty) {
      where.add("(instr(lower(title), lower(?)) > 0 OR instr(lower(body), lower(?)) > 0)");
      args.addAll([text, text]);
    }
    if (q.source != null) {
      where.add('source = ?');
      args.add(q.source!.name);
    }
    if (q.linked == true) where.add('book_id IS NOT NULL');
    if (q.linked == false) where.add('book_id IS NULL');
    if (q.bookId != null) {
      where.add('book_id = ?');
      args.add(q.bookId);
    }
    final sql =
        'SELECT * FROM journal_entries${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'} '
        'ORDER BY created_at DESC';
    return [for (final r in _db.select(sql, args)) _entry(r)];
  }

  @override
  List<JournalEntry> forReference(ScriptureReference reference) {
    final rows = _db.select(
      'SELECT * FROM journal_entries WHERE book_id = ? AND chapter = ? ORDER BY created_at DESC',
      [reference.bookId, reference.chapter],
    );
    final vs = reference.verseStart;
    final ve = reference.verseEnd ?? vs;
    return [
      for (final r in rows)
        if (_overlaps(vs, ve, r['verse_start'] as int?, (r['verse_end'] as int?) ?? r['verse_start'] as int?))
          _entry(r),
    ];
  }

  static bool _overlaps(int? aStart, int? aEnd, int? bStart, int? bEnd) {
    if (aStart == null || bStart == null) return true;
    return aStart <= bEnd! && bStart <= aEnd!;
  }

  @override
  int count() => _db.select('SELECT count(*) AS n FROM journal_entries').first['n'] as int;

  @override
  List<String> books() {
    final ids = {
      for (final r in _db.select('SELECT DISTINCT book_id FROM journal_entries WHERE book_id IS NOT NULL'))
        r['book_id'] as String,
    };
    return [
      for (final b in BibleCanon.books)
        if (ids.contains(b.id)) b.id,
    ];
  }
}
