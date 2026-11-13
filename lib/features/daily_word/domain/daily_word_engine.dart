import 'package:flutter/foundation.dart';

import '../../../data/models/daily_word.dart';
import '../../../data/models/library_items.dart';
import '../../../data/models/scripture_reference.dart';
import 'adaptive_relevance_scorer.dart';

/// The outcome of choosing a Daily Word for one date.
@immutable
class DailyWordDecision {
  const DailyWordDecision({
    required this.candidate,
    required this.scheduled,
    required this.adaptive,
    required this.reasons,
    required this.summary,
  });
  final DailyWordCandidate candidate;
  final DailyWordCandidate scheduled;
  final bool adaptive;
  final List<SelectionReason> reasons;
  final String summary;
}

/// Chooses the Daily Word for a date.
///
/// 1. The annual schedule gives the baseline (Feb 29 → the leap passage).
/// 2. With personalisation on, every pool passage not delivered in the last
///    [freshnessWindow] days is scored. Another passage replaces the
///    scheduled one only when the reader's own signals give it a higher
///    total; ties keep the schedule, then fall back to a stable hash.
/// 3. The result is stored by the caller and never recomputed for that date.
class DailyWordEngine {
  DailyWordEngine({required this.catalogue, required this.facts});

  final DailyWordCatalogue catalogue;
  final Map<String, CandidateFacts> facts;

  static const freshnessWindow = 60;

  DailyWordDecision select({
    required DateTime date,
    required List<DailyWordHistoryEntry> history,
    RelevanceProfile? profile,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final scheduled = catalogue.scheduledFor(day);
    final scheduledReason = SelectionReason(
      'schedule',
      scheduled.leapReserved
          ? 'The passage reserved for 29 February in the annual schedule'
          : 'Today’s passage in the annual schedule',
    );
    DailyWordDecision baseline([List<SelectionReason> extra = const []]) => DailyWordDecision(
      candidate: scheduled,
      scheduled: scheduled,
      adaptive: false,
      reasons: [scheduledReason, ...extra],
      summary: 'Today’s passage in the annual Daily Word schedule (theme: ${scheduled.category}).',
    );

    // The leap passage is fixed; so is everything when personalisation is off.
    if (profile == null || scheduled.leapReserved) return baseline();

    final before = history.where((h) => h.date.isBefore(day)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final recentIds = before
        .where((h) => day.difference(h.date).inDays <= freshnessWindow)
        .map((h) => h.candidateId)
        .toSet();
    final yesterday = before.where((h) => day.difference(h.date).inDays == 1).firstOrNull?.category;
    final week = before.where((h) => day.difference(h.date).inDays <= 7).map((h) => h.category).toList();

    final scores = <CandidateScore>[];
    for (final c in catalogue.pool) {
      final f = facts[c.id];
      if (f == null || recentIds.contains(c.id)) continue;
      scores.add(
        AdaptiveRelevanceScorer.score(
          facts: f,
          profile: profile,
          isScheduled: c.id == scheduled.id,
          yesterdayCategory: yesterday,
          lastWeekCategories: week,
        ),
      );
    }
    final scheduledScore = scores.where((s) => s.candidate.id == scheduled.id).firstOrNull;
    // Only passages the reader's own signals point to may replace the schedule.
    final contenders = scores.where((s) => s.signalPoints > 0).toList()
      ..sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        return byTotal != 0
            ? byTotal
            : stableHash('${dateKeyOf(day)}|${a.candidate.id}')
                  .compareTo(stableHash('${dateKeyOf(day)}|${b.candidate.id}'));
      });
    final best = contenders.firstOrNull;
    final scheduledTotal = scheduledScore?.total;

    if (best == null && scheduledScore == null) {
      // The scheduled passage was received recently (an earlier adaptive
      // choice) and no signal points elsewhere: take the next scheduled
      // passage that is still fresh.
      final start = catalogue.days.indexWhere((d) => d.monthDay == monthDayOf(day));
      for (var i = 1; i <= catalogue.days.length && start >= 0; i++) {
        final next = catalogue.candidate(catalogue.days[(start + i) % catalogue.days.length].candidateId)!;
        if (recentIds.contains(next.id)) continue;
        return DailyWordDecision(
          candidate: next,
          scheduled: scheduled,
          adaptive: true,
          reasons: [
            SelectionReason('freshness', 'The scheduled passage (${scheduled.reference.label}) was received recently'),
            const SelectionReason('schedule.next', 'The next passage in the annual schedule was used instead'),
          ],
          summary:
              'The scheduled ${scheduled.reference.label} was received recently, so the next passage in the annual '
              'schedule was used.',
        );
      }
    }
    if (best == null || best.candidate.id == scheduled.id || (scheduledTotal != null && best.total <= scheduledTotal)) {
      final extra = scheduledScore?.reasons.where((r) => r.code.startsWith('signal.')).toList() ?? const [];
      return baseline(extra);
    }
    final positive = best.reasons.where((r) => r.code.startsWith('signal.')).toList();
    final why = positive.map((r) => _lowerFirst(r.text)).join('; ');
    return DailyWordDecision(
      candidate: best.candidate,
      scheduled: scheduled,
      adaptive: true,
      reasons: [
        ...best.reasons,
        if (scheduledScore == null)
          SelectionReason('freshness', 'The scheduled passage (${scheduled.reference.label}) was received recently'),
      ],
      summary:
          'Chosen from the Daily Word pool instead of the scheduled ${scheduled.reference.label}: $why. '
          'This is based only on your activity on this device.',
    );
  }

  static String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  /// FNV-1a 32-bit: identical on every platform and run.
  static int stableHash(String s) {
    var h = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}

/// Builds a [RelevanceProfile] from local data. Signals older than
/// [window] or recorded before [clearedAt] are ignored.
RelevanceProfile buildRelevanceProfile({
  required DateTime now,
  required Set<String> interestIds,
  required List<RelevanceSignal> signals,
  required List<ReadingHistoryEntry> reading,
  required List<SavedScripture> saved,
  required List<Highlight> highlights,
  required List<VerseNote> notes,
  required List<DailyWordHistoryEntry> history,
  DateTime? clearedAt,
  Duration window = const Duration(days: 30),
}) {
  bool fresh(DateTime at) =>
      now.difference(at) <= window && !at.isAfter(now) && (clearedAt == null || at.isAfter(clearedAt));
  final dailyRefs = {for (final h in history) h.reference};
  return RelevanceProfile(
    interestIds: interestIds,
    searchTerms: [
      for (final s in signals)
        if (s.kind == SignalKind.search && fresh(s.at)) s.value.toLowerCase().trim(),
    ],
    readChapters: {
      for (final r in reading)
        if (fresh(r.readAt)) '${r.reference.bookId}.${r.reference.chapter}',
    },
    readBooks: {
      for (final r in reading)
        if (fresh(r.readAt)) r.reference.bookId,
    },
    engagedReferences: <ScriptureReference>{
      for (final s in saved)
        if (fresh(s.savedAt) && !dailyRefs.contains(s.reference)) s.reference,
      for (final h in highlights)
        if (fresh(h.createdAt)) h.reference,
      for (final n in notes)
        if (fresh(n.updatedAt)) n.reference,
    },
    favouredCategories: {
      for (final h in history)
        if (fresh(h.deliveredAt) && (h.favourite || saved.any((s) => s.reference == h.reference))) h.category,
    },
  );
}
