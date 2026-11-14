import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/data/local/personal_database.dart';
import 'package:my_word_bible/data/models/personal_rhythm.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/repositories/personal_repositories.dart';
import 'package:my_word_bible/features/fellowship/application/personal_providers.dart';

import '../helpers/test_app.dart';

const jhn3 = ScriptureReference(bookId: 'JHN', chapter: 3);
const rom8 = ScriptureReference(bookId: 'ROM', chapter: 8);

void main() {
  late PersonalDatabase db;
  late DateTime now;
  late SqlRhythmRepository rhythm;
  late SqlJournalRepository journal;

  setUp(() {
    db = PersonalDatabase.inMemory();
    now = DateTime(2026, 11, 10, 8, 30); // Tuesday
    rhythm = SqlRhythmRepository(db, clock: () => now);
    journal = SqlJournalRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  group('Activity creation and completion', () {
    test('Complete reading creates a stable, timestamped record', () {
      final r = rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader);
      expect(r, isA<ReadingCompleted>());
      final a = r.record;
      expect(a.id, matches(recordIdPattern));
      expect(a.kind, ActivityKind.readingCompleted);
      expect(a.occurredAt, now.toUtc());
      expect(a.occurredAt.isUtc, isTrue);
      expect(a.localDate, '2026-11-10');
      expect(a.tzOffsetMinutes, now.timeZoneOffset.inMinutes);
      expect(a.reference, jhn3);
      expect(a.versionId, 'KJV');
      final s = rhythm.sessionById(a.sessionId!)!;
      expect(s.status, ReadingSessionStatus.completed);
      expect(rhythm.completedReadings().single.id, a.id, reason: 'ids are stable when read back');
    });

    test('the start time is when the chapter was opened (never later than completion)', () {
      final opened = now.subtract(const Duration(minutes: 7));
      final a = rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader, openedAt: opened).record;
      expect(rhythm.sessionById(a.sessionId!)!.startedAt, opened.toUtc());
      final b = rhythm
          .completeReading(
            rom8,
            versionId: 'KJV',
            origin: PersonalOrigin.reader,
            openedAt: now.add(const Duration(hours: 1)),
          )
          .record;
      expect(rhythm.sessionById(b.sessionId!)!.startedAt, now.toUtc());
    });

    test('a user-initiated session is completed by Complete reading on that chapter', () {
      final s = rhythm.startSession(jhn3, versionId: 'KJV', origin: PersonalOrigin.rhythm);
      expect(rhythm.activeSession()!.id, s.id);
      now = now.add(const Duration(minutes: 12));
      final a = rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader).record;
      expect(a.sessionId, s.id);
      final done = rhythm.sessionById(s.id)!;
      expect(done.status, ReadingSessionStatus.completed);
      expect(done.finishedAt!.difference(done.startedAt), const Duration(minutes: 12));
      expect(rhythm.activeSession(), isNull);
    });

    test('starting a session ends the previous one; ending never counts as reading', () {
      final a = rhythm.startSession(jhn3, versionId: 'KJV', origin: PersonalOrigin.rhythm);
      final b = rhythm.startSession(rom8, versionId: 'KJV', origin: PersonalOrigin.reader);
      expect(rhythm.sessionById(a.id)!.status, ReadingSessionStatus.ended);
      expect(rhythm.activeSession()!.id, b.id);
      rhythm.endSession(b.id);
      expect(rhythm.activeSession(), isNull);
      expect(rhythm.completedReadings(), isEmpty);
      expect(rhythm.week(now).isEmpty, isTrue);
    });

    test('completing another chapter leaves an open session for a different chapter alone', () {
      final s = rhythm.startSession(jhn3, versionId: 'KJV', origin: PersonalOrigin.rhythm);
      rhythm.completeReading(rom8, versionId: 'KJV', origin: PersonalOrigin.reader);
      expect(rhythm.activeSession()!.id, s.id);
    });

    test('Undo removes the completion and its session', () {
      final a = rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader).record;
      rhythm.removeCompletion(a.id);
      expect(rhythm.completedReadings(), isEmpty);
      expect(rhythm.sessionById(a.sessionId!), isNull);
      expect(rhythm.completionOn(jhn3, '2026-11-10'), isNull);
    });

    test('invalid references are refused', () {
      for (final bad in const [
        ScriptureReference(bookId: 'XYZ', chapter: 1),
        ScriptureReference(bookId: 'JHN', chapter: 0),
        ScriptureReference(bookId: 'JHN', chapter: 22),
      ]) {
        expect(
          () => rhythm.completeReading(bad, versionId: 'KJV', origin: PersonalOrigin.reader),
          throwsA(isA<PersonalDataException>()),
          reason: '${bad.bookId} ${bad.chapter}',
        );
      }
      expect(rhythm.completedReadings(), isEmpty);
    });
  });

  group('Duplicate completion prevention', () {
    test('one completion per chapter per local day', () {
      final first = rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader);
      now = now.add(const Duration(hours: 3));
      final second = rhythm.completeReading(jhn3, versionId: 'WEB', origin: PersonalOrigin.rhythm);
      expect(second, isA<AlreadyCompletedToday>());
      expect(second.record.id, first.record.id);
      expect(rhythm.readingCount(), 1);
    });

    test('the same chapter on the next day is a new reading', () {
      rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader);
      now = DateTime(2026, 11, 11, 6);
      expect(rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader), isA<ReadingCompleted>());
      expect(rhythm.readingCount(), 2);
    });

    test('the database itself rejects a duplicate key', () {
      rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader);
      expect(
        () => db.db.execute(
          "INSERT INTO activity_records(id, kind, occurred_at, local_date, tz_offset_min, dedupe_key) "
          "VALUES ('x', 'readingCompleted', 't', '2026-11-10', 0, ?)",
          [SqlRhythmRepository.completionKey(jhn3, '2026-11-10')],
        ),
        throwsA(anything),
      );
    });
  });

  group('Weekly summary and calendar', () {
    test('counts readings and reflections Monday to Sunday', () {
      rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader); // Tue
      rhythm.completeReading(rom8, versionId: 'KJV', origin: PersonalOrigin.reader); // Tue
      journal.create(const JournalDraft(body: 'a')); // Tue
      now = DateTime(2026, 11, 15, 21); // Sunday
      rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader);
      now = DateTime(2026, 11, 16, 7); // next Monday: next week
      rhythm.completeReading(rom8, versionId: 'KJV', origin: PersonalOrigin.reader);

      final w = rhythm.week(DateTime(2026, 11, 12));
      expect(w.start, DateTime(2026, 11, 9));
      expect(w.days.map((d) => d.dateKey).first, '2026-11-09');
      expect(w.days.map((d) => d.dateKey).last, '2026-11-15');
      expect(w.readingsCompleted, 3);
      expect(w.reflectionsWritten, 1);
      expect(w.daysWithScripture, 2);
      expect(w.days[1].readings, 2);
      expect(w.days[0].hasActivity, isFalse);

      final month = rhythm.daysBetween('2026-11-01', '2026-11-30');
      expect(month.keys, containsAll(['2026-11-10', '2026-11-15', '2026-11-16']));
      expect(rhythm.activityBetween('2026-11-10', '2026-11-10'), hasLength(3));
    });

    test('weekStartOf is the Monday of the week', () {
      expect(weekStartOf(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
      expect(weekStartOf(DateTime(2026, 11, 15, 23, 59)), DateTime(2026, 11, 9));
      expect(weekStartOf(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    });

    test('clearing reading activity keeps reflections', () {
      rhythm.completeReading(jhn3, versionId: 'KJV', origin: PersonalOrigin.reader);
      journal.create(const JournalDraft(body: 'kept'));
      rhythm.clearReadingActivity();
      expect(rhythm.readingCount(), 0);
      expect(journal.count(), 1);
      expect(rhythm.week(now).reflectionsWritten, 1);
    });
  });

  group('Journal', () {
    test('create, edit and delete with stable ids and timestamps', () {
      final e = journal.create(
        const JournalDraft(
          title: ' Morning ',
          body: ' Grateful today ',
          reference: jhn3,
          versionId: 'KJV',
          source: PersonalOrigin.reader,
        ),
      );
      expect(e.id, matches(recordIdPattern));
      expect(e.title, 'Morning');
      expect(e.body, 'Grateful today');
      expect(e.createdAt, now.toUtc());
      expect(e.source, PersonalOrigin.reader);

      now = now.add(const Duration(hours: 1));
      final edited = journal.update(
        e.id,
        const JournalDraft(body: 'Still grateful', reference: rom8, versionId: 'KJV'),
      );
      expect(edited.id, e.id);
      expect(edited.createdAt, e.createdAt);
      expect(edited.updatedAt, now.toUtc());
      expect(edited.reference, rom8);
      expect(edited.source, PersonalOrigin.reader, reason: 'origin is kept');

      journal.delete(e.id);
      expect(journal.byId(e.id), isNull);
      expect(journal.count(), 0);
    });

    test('writing a reflection records activity; deleting it removes that record', () {
      final e = journal.create(const JournalDraft(body: 'x'));
      final day = rhythm.activityBetween('2026-11-10', '2026-11-10');
      expect(day.single.kind, ActivityKind.reflectionWritten);
      expect(day.single.journalId, e.id);
      journal.delete(e.id);
      expect(rhythm.activityBetween('2026-11-10', '2026-11-10'), isEmpty);
    });

    test('validation', () {
      expect(() => journal.create(const JournalDraft(body: '   ')), throwsA(isA<PersonalDataException>()));
      expect(
        () => journal.create(JournalDraft(body: 'a' * (SqlJournalRepository.maxBodyLength + 1))),
        throwsA(isA<PersonalDataException>()),
      );
      expect(
        () => journal.create(const JournalDraft(body: 'a', reference: jhn3)),
        throwsA(isA<PersonalDataException>()),
        reason: 'a linked reflection needs its translation',
      );
      expect(
        () => journal.create(
          const JournalDraft(
            body: 'a',
            reference: ScriptureReference(bookId: 'JHN', chapter: 3, verseStart: 5, verseEnd: 2),
            versionId: 'KJV',
          ),
        ),
        throwsA(isA<PersonalDataException>()),
      );
      expect(() => journal.update('missing', const JournalDraft(body: 'a')), throwsA(isA<PersonalDataException>()));
      expect(journal.count(), 0);
    });

    test('delete all removes every reflection', () {
      for (var i = 0; i < 5; i++) {
        journal.create(JournalDraft(body: 'entry $i'));
      }
      journal.deleteAll();
      expect(journal.count(), 0);
      expect(rhythm.week(now).reflectionsWritten, 0);
    });
  });

  group('Search and filtering', () {
    setUp(() {
      journal.create(
        const JournalDraft(
          title: 'Peace',
          body: 'The PEACE that passes understanding',
          reference: ScriptureReference(bookId: 'PHP', chapter: 4, verseStart: 7),
          versionId: 'KJV',
          source: PersonalOrigin.reader,
        ),
      );
      now = now.add(const Duration(minutes: 1));
      journal.create(const JournalDraft(body: 'Morning prayer for my family', source: PersonalOrigin.independent));
      now = now.add(const Duration(minutes: 1));
      journal.create(
        const JournalDraft(
          body: 'Waiting on the Lord',
          reference: ScriptureReference(bookId: 'PSA', chapter: 27, verseStart: 14),
          versionId: 'WEB',
          source: PersonalOrigin.dailyWord,
          dailyWordDate: '2026-11-10',
        ),
      );
      now = now.add(const Duration(minutes: 1));
      journal.create(
        const JournalDraft(
          body: 'More peace',
          reference: ScriptureReference(bookId: 'PSA', chapter: 4, verseStart: 8),
          versionId: 'KJV',
          source: PersonalOrigin.savedScripture,
        ),
      );
    });

    List<String> bodies(JournalQuery q) => journal.search(q).map((e) => e.body).toList();

    test('newest first, all by default', () {
      expect(bodies(const JournalQuery()).first, 'More peace');
      expect(bodies(const JournalQuery()), hasLength(4));
    });

    test('text search is case-insensitive across title and body', () {
      expect(bodies(const JournalQuery(text: 'peace')), ['More peace', 'The PEACE that passes understanding']);
      expect(bodies(const JournalQuery(text: 'FAMILY')), ['Morning prayer for my family']);
      expect(bodies(const JournalQuery(text: "50% isn't here")), isEmpty);
    });

    test('filters by origin, link and book, and combine', () {
      expect(bodies(const JournalQuery(source: PersonalOrigin.dailyWord)), ['Waiting on the Lord']);
      expect(bodies(const JournalQuery(linked: false)), ['Morning prayer for my family']);
      expect(bodies(const JournalQuery(linked: true)), hasLength(3));
      expect(bodies(const JournalQuery(bookId: 'PSA')), ['More peace', 'Waiting on the Lord']);
      expect(bodies(const JournalQuery(bookId: 'PSA', text: 'peace')), ['More peace']);
      expect(journal.books(), ['PSA', 'PHP'], reason: 'canonical order');
    });

    test('reflections for a reference match overlapping verses and whole chapters', () {
      expect(
        journal.forReference(const ScriptureReference(bookId: 'PSA', chapter: 27, verseStart: 13, verseEnd: 14)),
        hasLength(1),
      );
      expect(journal.forReference(const ScriptureReference(bookId: 'PSA', chapter: 27)), hasLength(1));
      expect(journal.forReference(const ScriptureReference(bookId: 'PSA', chapter: 27, verseStart: 1)), isEmpty);
    });
  });

  group('Scripture reference integrity', () {
    test('a reflection stores a canonical reference and never verse text', () async {
      final c = testContainer(onboardedStore());
      await c.read(personalStoreProvider.future);
      final e = await c
          .read(personalActionsProvider)
          .createReflection(
            const JournalDraft(
              body: 'Loved',
              reference: ScriptureReference(bookId: 'JHN', chapter: 3, verseStart: 16),
              versionId: 'KJV-MWB',
            ),
          );
      expect(e.versionId, 'KJV', reason: 'a personalised edition maps to its canonical source');
      final store = (c.read(personalStoreProvider).value! as PersonalStoreReady).database;
      final dump = store.db
          .select('SELECT * FROM journal_entries')
          .expand((r) => r.values)
          .followedBy(store.db.select('SELECT * FROM activity_records').expand((r) => r.values))
          .join('|');
      expect(dump, isNot(contains('For God so loved the world')));
      expect(dump, contains('JHN'));
    });

    test('verses that do not exist in the translation are refused', () async {
      final c = testContainer(onboardedStore());
      await c.read(personalStoreProvider.future);
      final actions = c.read(personalActionsProvider);
      await expectLater(
        actions.createReflection(
          const JournalDraft(
            body: 'x',
            reference: ScriptureReference(bookId: 'JHN', chapter: 3, verseStart: 37),
            versionId: 'KJV',
          ),
        ),
        throwsA(isA<PersonalDataException>()),
      );
      await expectLater(
        actions.createReflection(
          const JournalDraft(
            body: 'x',
            reference: ScriptureReference(bookId: 'JHN', chapter: 3, verseStart: 35, verseEnd: 40),
            versionId: 'KJV',
          ),
        ),
        throwsA(isA<PersonalDataException>()),
      );
      expect(c.read(journalCountProvider), 0);
    });

    test('route encoding of references round-trips', () {
      for (final r in const [
        ScriptureReference(bookId: 'JHN', chapter: 3),
        ScriptureReference(bookId: 'ROM', chapter: 8, verseStart: 37),
        ScriptureReference(bookId: '1CO', chapter: 13, verseStart: 4, verseEnd: 7),
      ]) {
        expect(decodeReference(encodeReference(r)), r);
      }
      expect(decodeReference('JHN.3.16;DROP'), isNull);
      expect(decodeReference(null), isNull);
    });
  });
}
