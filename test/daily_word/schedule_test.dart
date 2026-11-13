import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/data/models/daily_word.dart';
import 'package:my_word_bible/data/models/intelligence.dart';
import 'package:my_word_bible/core/errors/app_failure.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/repositories/daily_word_repository.dart';

import '../helpers/test_app.dart';
import 'daily_word_test_support.dart';

void main() {
  final catalogue = shippedCatalogue();

  group('Annual schedule', () {
    test('covers all 365 calendar dates of a common year exactly once', () {
      expect(catalogue.days, hasLength(365));
      expect(catalogue.days.map((d) => d.day), List.generate(365, (i) => i + 1));
      final keys = catalogue.days.map((d) => d.monthDay).toSet();
      expect(keys, hasLength(365));
      expect(keys.contains('02-29'), isFalse, reason: 'Feb 29 is handled separately');
      for (var d = DateTime(2027); d.year == 2027; d = d.add(const Duration(days: 1))) {
        expect(catalogue.scheduleDay(d), isNotNull, reason: dateKeyOf(d));
      }
    });

    test('February 29 is the reserved Revelation 21:5 passage', () {
      final leap = catalogue.scheduledFor(DateTime(2028, 2, 29));
      expect(leap.reference, ScriptureReference.parseCompact('REV 21:5'));
      expect(leap.leapReserved, isTrue);
      expect(leap.title, 'All things new');
      expect(catalogue.days.any((d) => d.candidateId == leap.id), isFalse, reason: 'not used on any other date');
      expect(catalogue.pool.any((c) => c.id == leap.id), isFalse, reason: 'not available to adaptive selection');
    });

    test('a leap year does not shift or repeat the 28 February and 1 March passages', () {
      for (final year in [2027, 2028]) {
        expect(
          catalogue.scheduledFor(DateTime(year, 2, 28)).id,
          catalogue.scheduleDay(DateTime(2027, 2, 28))!.candidateId,
        );
        expect(
          catalogue.scheduledFor(DateTime(year, 3, 1)).id,
          catalogue.scheduleDay(DateTime(2027, 3, 1))!.candidateId,
        );
      }
      final feb28 = catalogue.scheduledFor(DateTime(2028, 2, 28)).id;
      final feb29 = catalogue.scheduledFor(DateTime(2028, 2, 29)).id;
      final mar1 = catalogue.scheduledFor(DateTime(2028, 3, 1)).id;
      expect({feb28, feb29, mar1}, hasLength(3));
    });

    test('date mapping is by month and day, the same in every year', () {
      for (final md in [(1, 1), (6, 15), (12, 31)]) {
        final a = catalogue.scheduledFor(DateTime(2026, md.$1, md.$2));
        final b = catalogue.scheduledFor(DateTime(2031, md.$1, md.$2, 23, 59));
        expect(a.id, b.id);
      }
      expect(catalogue.scheduleDay(DateTime(2026, 1, 1))!.day, 1);
      expect(catalogue.scheduleDay(DateTime(2026, 12, 31))!.day, 365);
    });

    test('consecutive days never share a category, including 31 Dec → 1 Jan and around 29 Feb', () {
      String cat(DateTime d) => catalogue.scheduledFor(d).category;
      for (var d = DateTime(2028); d.year == 2028; d = d.add(const Duration(days: 1))) {
        final next = d.add(const Duration(days: 1));
        expect(cat(d), isNot(cat(next)), reason: '${dateKeyOf(d)} → ${dateKeyOf(next)}');
      }
    });

    test('reuse is explicit: each recurrence is numbered and spaced by the cycle', () {
      expect(catalogue.cycleLength, catalogue.pool.length);
      final seen = <String, List<int>>{};
      for (final d in catalogue.days) {
        (seen[d.candidateId] ??= []).add(d.day);
        expect(d.occurrence, seen[d.candidateId]!.length);
      }
      for (final days in seen.values) {
        for (var i = 1; i < days.length; i++) {
          expect(days[i] - days[i - 1], catalogue.cycleLength);
        }
      }
      expect(seen.length, catalogue.pool.length, reason: 'every pool passage is scheduled');
    });

    test('is versioned and tied to the intelligence corpus version', () {
      expect(catalogue.scheduleVersion, '2026.1');
      expect(catalogue.corpusVersion, corpus().manifest.corpusVersion);
      final raw = jsonDecode(File('assets/daily/schedule.json').readAsStringSync()) as Map<String, dynamic>;
      expect(raw['schemaVersion'], 1);
    });
  });

  group('Candidates', () {
    test('each has a stable id, canonical reference, theme, rationale, provenance and review status', () {
      final ids = <String>{};
      for (final c in catalogue.candidates) {
        expect(ids.add(c.id), isTrue, reason: 'duplicate ${c.id}');
        expect(
          c.id,
          'dwc-${c.reference.bookId}-${c.reference.chapter}-${c.reference.verseStart}${c.reference.verseEnd == null ? '' : '-${c.reference.verseEnd}'}',
        );
        expect(catalogue.categories, contains(c.category));
        expect(c.theme, isNotEmpty);
        expect(c.rationale, isNotEmpty);
        expect(c.reviewStatus, EditorialStatus.pendingEditorialReview, reason: 'nothing is labelled approved');
        if (c.origin == ProvenanceOrigin.demoSeed) expect(c.seedId, isNotNull);
      }
      expect(catalogue.candidates, hasLength(114));
      expect(catalogue.candidates.where((c) => c.origin == ProvenanceOrigin.demoSeed), hasLength(55));
    });

    test('every reference resolves in KJV and WEB and has a Stage C context', () async {
      for (final c in catalogue.candidates) {
        final kjv = await sharedTestBible.passage('KJV', c.reference);
        final web = await sharedTestBible.passage('WEB', c.reference);
        expect(kjv.text, isNotEmpty, reason: c.id);
        expect(web.verses.every((v) => !v.isOmitted), isTrue, reason: c.id);
        final ctx = corpus().byId(c.contextId);
        expect(ctx, isA<IntelContext>(), reason: c.id);
        expect((ctx as IntelContext).reference, c.reference);
      }
    });

    test('candidates store references only, never verse text', () {
      final raw = File('assets/daily/candidates.json').readAsStringSync();
      expect(raw.contains('For God so loved'), isFalse);
      expect(raw.contains('"text"'), isFalse);
    });

    test('passages held back from the pool are recorded and not scheduled', () {
      final raw = jsonDecode(File('assets/daily/candidates.json').readAsStringSync()) as Map<String, dynamic>;
      final excluded = (raw['excluded'] as List).map((e) => (e as Map)['reference']).toSet();
      expect(excluded, {'MAL 3:10', 'DEU 8:18', 'PRO 10:22'});
      for (final c in catalogue.candidates) {
        expect(excluded.contains('${c.reference.bookId} ${c.reference.chapter}:${c.reference.verseStart}'), isFalse);
      }
    });
  });

  group('Offline loading', () {
    test('reads only the bundled schedule files, once', () async {
      final paths = <String>[];
      final repo = AssetDailyWordRepository(
        loader: (p) async {
          paths.add(p);
          return File(p).readAsStringSync();
        },
      );
      final a = await repo.catalogue();
      final b = await repo.catalogue();
      expect(identical(a, b), isTrue);
      expect(paths, ['assets/daily/candidates.json', 'assets/daily/schedule.json']);
    });

    test('a missing or malformed schedule fails clearly and is retried', () async {
      var calls = 0;
      final repo = AssetDailyWordRepository(
        loader: (p) async {
          calls++;
          if (p.endsWith('schedule.json')) return '{"schemaVersion": 9}';
          return File(p).readAsStringSync();
        },
      );
      await expectLater(
        repo.catalogue(),
        throwsA(isA<UnknownFailure>().having((f) => f.message, 'message', contains('schema 9'))),
      );
      await expectLater(repo.catalogue(), throwsA(isA<UnknownFailure>()));
      expect(calls, 4);
    });
  });
}
