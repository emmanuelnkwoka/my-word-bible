import 'package:flutter/foundation.dart';

import '../../../data/models/daily_word.dart';
import '../../../data/models/interest.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/intelligence_repository.dart';

/// What the corpus says about one candidate, used for scoring.
@immutable
class CandidateFacts {
  const CandidateFacts({required this.candidate, required this.keywords, required this.relatedReferences});
  final DailyWordCandidate candidate;

  /// Lower-case words and phrases: context keywords, theme, title, category,
  /// names of life situations that cite the passage, promise categories.
  final Set<String> keywords;

  /// Passages linked by Stage C relationships or a shared life situation.
  final Set<ScriptureReference> relatedReferences;

  static Map<String, CandidateFacts> build(DailyWordCatalogue catalogue, IntelligenceCorpus corpus) => {
    for (final c in catalogue.candidates) c.id: _of(c, corpus),
  };

  static CandidateFacts _of(DailyWordCandidate c, IntelligenceCorpus corpus) {
    final words = <String>{c.category.toLowerCase(), c.theme.toLowerCase(), ?c.title?.toLowerCase()};
    final context = corpus.contextsFor(c.reference).firstOrNull;
    if (context != null) words.addAll(context.keywords.map((k) => k.toLowerCase()));
    final related = <ScriptureReference>{};
    for (final s in corpus.situations.where((s) => s.references.any((r) => referencesOverlap(r, c.reference)))) {
      words.add(s.name.toLowerCase());
      related.addAll(s.references.where((r) => !referencesOverlap(r, c.reference)));
    }
    for (final p in corpus.promises.where((p) => p.references.any((r) => referencesOverlap(r, c.reference)))) {
      words.add(p.category.toLowerCase());
    }
    for (final v in corpus.relationshipsFor(c.reference)) {
      related.add(v.other);
    }
    return CandidateFacts(candidate: c, keywords: words, relatedReferences: related);
  }
}

/// Local signals, already filtered to the scoring window and to anything
/// recorded after the reader last cleared them.
@immutable
class RelevanceProfile {
  const RelevanceProfile({
    this.interestIds = const {},
    this.searchTerms = const [],
    this.readChapters = const {},
    this.readBooks = const {},
    this.engagedReferences = const {},
    this.favouredCategories = const {},
  });

  final Set<String> interestIds;

  /// Recent search queries, lower-case.
  final List<String> searchTerms;

  /// `BOOK.chapter` keys of chapters read recently.
  final Set<String> readChapters;
  final Set<String> readBooks;

  /// Verses saved, highlighted or noted recently.
  final Set<ScriptureReference> engagedReferences;

  /// Categories of Daily Words the reader saved or favourited.
  final Set<String> favouredCategories;

  bool get isEmpty =>
      interestIds.isEmpty &&
      searchTerms.isEmpty &&
      readChapters.isEmpty &&
      engagedReferences.isEmpty &&
      favouredCategories.isEmpty;
}

@immutable
class CandidateScore {
  const CandidateScore(this.candidate, this.reasons);
  final DailyWordCandidate candidate;
  final List<SelectionReason> reasons;

  int get total => reasons.fold(0, (n, r) => n + r.points);

  /// Points that come from the reader's own signals (not the schedule
  /// anchor and not penalties).
  int get signalPoints => reasons.where((r) => r.code.startsWith('signal.')).fold(0, (n, r) => n + r.points);
}

/// Transparent, deterministic scoring. Every point carries a plain reason.
///
/// Reasons describe the reader's activity neutrally ("topics you searched
/// for") and never infer a personal circumstance or a divine intention.
abstract final class AdaptiveRelevanceScorer {
  static const scheduleAnchor = 25;
  static const interestPoints = 30;
  static const searchPointsPerTerm = 8;
  static const searchCap = 24;
  static const chapterReadPoints = 12;
  static const bookReadPoints = 4;
  static const engagedPoints = 15;
  static const favouredCategoryPoints = 10;
  static const yesterdayCategoryPenalty = -25;
  static const weeklyCategoryPenalty = -8;

  /// Interests chosen at onboarding → Daily Word categories.
  static const interestCategories = <String, List<String>>{
    'faith': ['Faith', 'Hope', 'Courage'],
    'prayer': ['Peace', 'Faith'],
    'understanding': ['Wisdom', 'Guidance'],
    'growth': ['Strength', 'Identity', 'Purpose'],
    'family': ['Family'],
    'purpose': ['Purpose', 'Guidance'],
    'wisdom': ['Wisdom', 'Guidance'],
    'living': ['Gratitude', 'Rest', 'Peace'],
    'development': ['Purpose', 'Wisdom', 'Strength'],
  };

  static Set<String> categoriesForInterests(Iterable<String> interestIds) => {
    for (final i in interestIds) ...?interestCategories[i],
  };

  static CandidateScore score({
    required CandidateFacts facts,
    required RelevanceProfile profile,
    required bool isScheduled,
    required String? yesterdayCategory,
    required List<String> lastWeekCategories,
  }) {
    final c = facts.candidate;
    final reasons = <SelectionReason>[];
    if (isScheduled) {
      reasons.add(const SelectionReason('schedule', 'Today’s passage in the annual schedule', scheduleAnchor));
    }

    final interests = profile.interestIds.where((i) => interestCategories[i]?.contains(c.category) ?? false).toList();
    if (interests.isNotEmpty) {
      // Name the interest the reader actually chose, then the theme it maps to.
      final labels = [for (final i in interests) spiritualInterests.where((s) => s.id == i).firstOrNull?.label ?? i];
      reasons.add(
        SelectionReason(
          'signal.interest',
          'Fits an interest you chose (${labels.join(', ')}), in the theme ${c.category}',
          interestPoints,
        ),
      );
    }

    final matched = <String>{};
    for (final q in profile.searchTerms) {
      for (final term in q.split(RegExp(r'\s+')).where((t) => t.length >= 3)) {
        if (facts.keywords.any((k) => k == term || k.split(RegExp(r'[\s-]+')).contains(term))) matched.add(term);
      }
    }
    if (matched.isNotEmpty) {
      final pts = (matched.length * searchPointsPerTerm).clamp(0, searchCap);
      reasons.add(SelectionReason('signal.search', 'Related to topics you searched for recently', pts));
    }

    final r = c.reference;
    if (profile.readChapters.contains('${r.bookId}.${r.chapter}')) {
      reasons.add(
        SelectionReason(
          'signal.reading',
          'From a chapter you read recently (${r.chapterOnly.label})',
          chapterReadPoints,
        ),
      );
    } else if (profile.readBooks.contains(r.bookId)) {
      reasons.add(
        SelectionReason('signal.reading', 'From a book you have been reading (${r.book.name})', bookReadPoints),
      );
    }

    if (profile.engagedReferences.any(
      (e) => facts.relatedReferences.any((x) => referencesOverlap(x, e)) && !referencesOverlap(e, r),
    )) {
      reasons.add(
        const SelectionReason(
          'signal.engaged',
          'Connected to Scripture you saved, highlighted or noted',
          engagedPoints,
        ),
      );
    }

    if (profile.favouredCategories.contains(c.category)) {
      reasons.add(
        SelectionReason(
          'signal.favoured',
          'A theme of Daily Words you saved or favourited (${c.category})',
          favouredCategoryPoints,
        ),
      );
    }

    if (yesterdayCategory == c.category) {
      reasons.add(const SelectionReason('diversity.yesterday', 'Same theme as yesterday', yesterdayCategoryPenalty));
    }
    final weekly = lastWeekCategories.where((k) => k == c.category).length;
    if (weekly > 0) {
      reasons.add(
        SelectionReason('diversity.week', 'Theme already received this week', weekly * weeklyCategoryPenalty),
      );
    }
    return CandidateScore(c, reasons);
  }
}
