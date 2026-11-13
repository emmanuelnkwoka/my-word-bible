import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/data/models/daily_word.dart';
import 'package:my_word_bible/data/models/library_items.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/features/daily_word/domain/adaptive_relevance_scorer.dart';
import 'package:my_word_bible/features/daily_word/domain/daily_word_engine.dart';

import 'daily_word_test_support.dart';

ScriptureReference ref(String s) => ScriptureReference.parseCompact(s);

void main() {
  final e = engine();
  final cat = e.catalogue;
  // A date whose scheduled passage is not in the Family category.
  final date = () {
    for (var d = DateTime(2026, 11, 10); ; d = d.add(const Duration(days: 1))) {
      if (cat.scheduledFor(d).category != 'Family') return d;
    }
  }();
  final scheduled = cat.scheduledFor(date);
  const familyInterest = RelevanceProfile(interestIds: {'family'});

  group('Baseline', () {
    test('without personalisation the schedule is used unchanged', () {
      final d = e.select(date: date, history: const [], profile: null);
      expect(d.candidate.id, scheduled.id);
      expect(d.adaptive, isFalse);
      expect(d.summary, contains('annual Daily Word schedule'));
    });

    test('with personalisation but no signals the schedule is used', () {
      final d = e.select(date: date, history: const [], profile: const RelevanceProfile());
      expect(d.candidate.id, scheduled.id);
      expect(d.adaptive, isFalse);
    });

    test('29 February always gives Revelation 21:5, even with strong signals', () {
      final d = e.select(date: DateTime(2028, 2, 29), history: const [], profile: familyInterest);
      expect(d.candidate.reference, ref('REV 21:5'));
      expect(d.adaptive, isFalse);
      expect(d.reasons.first.text, contains('29 February'));
    });

    test('selection is deterministic for the same inputs', () {
      final a = e.select(date: date, history: const [], profile: familyInterest);
      final b = engine().select(date: date, history: const [], profile: familyInterest);
      expect(a.candidate.id, b.candidate.id);
      expect(a.reasons.map((r) => r.code), b.reasons.map((r) => r.code));
      expect(a.summary, b.summary);
    });
  });

  group('Adaptive relevance', () {
    test('an interest can replace the scheduled passage, with its reasons', () {
      final d = e.select(date: date, history: const [], profile: familyInterest);
      expect(d.adaptive, isTrue);
      expect(d.candidate.category, 'Family');
      expect(d.scheduled.id, scheduled.id);
      expect(d.reasons.map((r) => r.code), contains('signal.interest'));
      expect(d.summary, contains('instead of the scheduled ${scheduled.reference.label}'));
      expect(d.summary, contains('only on your activity on this device'));
    });

    test('a single weak signal does not override the schedule', () {
      // A search match is worth at most 24 points; the schedule anchor is 25.
      final d = e.select(
        date: date,
        history: const [],
        profile: const RelevanceProfile(searchTerms: ['peace strength wisdom family hope']),
      );
      expect(d.candidate.id, scheduled.id);
    });

    test('topic diversity: yesterday\'s theme is penalised', () {
      final family = cat.pool.firstWhere((c) => c.category == 'Family');
      final yesterday = entryFor(date.subtract(const Duration(days: 1)), family);
      final d = e.select(date: date, history: [yesterday], profile: familyInterest);
      expect(d.candidate.category, isNot('Family'), reason: '30 interest − 25 diversity does not beat the schedule');
    });

    test('recent passages are not repeated within the freshness window', () {
      final first = e.select(date: date, history: const [], profile: familyInterest).candidate;
      final history = [entryFor(date.subtract(const Duration(days: 10)), first)];
      final next = e.select(date: date, history: history, profile: familyInterest);
      expect(next.candidate.id, isNot(first.id));
      expect(next.candidate.category, 'Family');
      // Outside the window the passage may return.
      final old = [entryFor(date.subtract(const Duration(days: DailyWordEngine.freshnessWindow + 1)), first)];
      expect(e.select(date: date, history: old, profile: familyInterest).candidate.id, first.id);
    });

    test('a recently received scheduled passage moves to the next scheduled passage', () {
      final history = [entryFor(date.subtract(const Duration(days: 5)), scheduled)];
      final d = e.select(date: date, history: history, profile: const RelevanceProfile());
      expect(d.candidate.id, isNot(scheduled.id));
      expect(d.reasons.map((r) => r.code), containsAll(['freshness', 'schedule.next']));
      final i = cat.days.indexWhere((x) => x.monthDay == monthDayOf(date));
      final nextIds = [for (var k = 1; k <= 3; k++) cat.days[(i + k) % 365].candidateId];
      expect(nextIds, contains(d.candidate.id));
    });

    test('reasons describe activity neutrally and make no divine claim', () {
      final profiles = [
        familyInterest,
        const RelevanceProfile(interestIds: {'faith', 'prayer'}, searchTerms: ['fear', 'anxiety']),
      ];
      for (final p in profiles) {
        for (var i = 0; i < 30; i++) {
          final d = e.select(
            date: date.add(Duration(days: i)),
            history: const [],
            profile: p,
          );
          final text = [d.summary, ...d.reasons.map((r) => r.text)].join(' ');
          expect(text, isNot(contains('God')));
          expect(text.toLowerCase(), isNot(contains('you are struggling')));
          expect(text.toLowerCase(), isNot(contains('you are afraid')));
        }
      }
    });
  });

  group('Scorer dimensions', () {
    final facts = CandidateFacts.build(cat, corpus());
    final ps91 = cat.candidates.firstWhere((c) => c.reference == ref('PSA 91:11'));
    CandidateScore score(RelevanceProfile p, {String? yesterday, List<String> week = const []}) =>
        AdaptiveRelevanceScorer.score(
          facts: facts[ps91.id]!,
          profile: p,
          isScheduled: false,
          yesterdayCategory: yesterday,
          lastWeekCategories: week,
        );

    test('interest, search, reading, related Scripture and favoured themes each add points', () {
      expect(
        score(const RelevanceProfile(interestIds: {'faith'})).total,
        0,
        reason: 'Protection is not a Faith interest',
      );
      expect(score(const RelevanceProfile(searchTerms: ['angels'])).signalPoints, 8);
      expect(score(const RelevanceProfile(readChapters: {'PSA.91'})).signalPoints, 12);
      expect(score(const RelevanceProfile(readBooks: {'PSA'})).signalPoints, 4);
      // Psalm 34:7 is linked to Psalm 91:11 by a Stage C relationship.
      expect(score(RelevanceProfile(engagedReferences: {ref('PSA 34:7')})).signalPoints, 15);
      expect(score(const RelevanceProfile(favouredCategories: {'Protection'})).signalPoints, 10);
    });

    test('search points are capped', () {
      expect(
        score(const RelevanceProfile(searchTerms: ['angels charge protection keep ways'])).signalPoints,
        lessThanOrEqualTo(24),
      );
    });

    test('diversity penalties for yesterday and the past week', () {
      expect(score(const RelevanceProfile(), yesterday: 'Protection').total, -25);
      expect(score(const RelevanceProfile(), week: ['Protection', 'Protection']).total, -16);
    });
  });

  group('Relevance profile', () {
    final now = DateTime(2026, 11, 10, 9);
    RelevanceProfile build({
      DateTime? clearedAt,
      required DateTime at,
      List<DailyWordHistoryEntry> history = const [],
    }) => buildRelevanceProfile(
      now: now,
      interestIds: const {'faith'},
      signals: [RelevanceSignal(kind: SignalKind.search, value: 'Peace', at: at)],
      reading: [ReadingHistoryEntry(reference: ref('PSA 23'), versionId: 'KJV', readAt: at)],
      saved: [SavedScripture(reference: ref('JHN 14:27'), versionId: 'KJV', savedAt: at)],
      highlights: const [],
      notes: const [],
      history: history,
      clearedAt: clearedAt,
    );

    test('collects recent local signals', () {
      final p = build(at: now.subtract(const Duration(days: 2)));
      expect(p.searchTerms, ['peace']);
      expect(p.readChapters, {'PSA.23'});
      expect(p.engagedReferences, {ref('JHN 14:27')});
      expect(p.interestIds, {'faith'});
    });

    test('ignores signals older than 30 days', () {
      final p = build(at: now.subtract(const Duration(days: 31)));
      expect(p.searchTerms, isEmpty);
      expect(p.readChapters, isEmpty);
      expect(p.engagedReferences, isEmpty);
    });

    test('ignores signals recorded before they were cleared (interests remain)', () {
      final p = build(at: now.subtract(const Duration(days: 2)), clearedAt: now.subtract(const Duration(days: 1)));
      expect(p.searchTerms, isEmpty);
      expect(p.engagedReferences, isEmpty);
      expect(p.interestIds, {'faith'});
    });

    test('a saved Daily Word counts as a favoured theme, not as related Scripture', () {
      final c = cat.candidates.firstWhere((c) => c.reference == ref('JHN 14:27'));
      final p = build(
        at: now.subtract(const Duration(days: 2)),
        history: [entryFor(now.subtract(const Duration(days: 2)), c)],
      );
      expect(p.engagedReferences, isEmpty);
      expect(p.favouredCategories, {c.category});
    });
  });

  test('stable hash is platform independent', () {
    expect(DailyWordEngine.stableHash(''), 0x811c9dc5);
    expect(DailyWordEngine.stableHash('a'), 0xe40c292c);
  });
}
