import 'package:flutter/foundation.dart';

import 'mwb_rule.dart';

/// The seven classes every canonical verse is placed in.
enum VerseClass {
  nameInText('Eligible for name insertion'),
  nameInTitle('Eligible for name-in-title'),
  otherTransformation('Other defined transformation'),
  originalOnly('Original text only'),
  contextualReview('Requires contextual review'),
  excluded('Excluded'),
  pendingDecision('Pending editorial or theological decision');

  const VerseClass(this.label);
  final String label;

  /// Classes with a proposal attached.
  bool get hasProposal => this == nameInText || this == nameInTitle || this == otherTransformation || this == pendingDecision;

  /// Classes counted as "flagged" in coverage: needing human attention
  /// without a proposal.
  bool get isFlagged => this == contextualReview;
}

/// Why a verse is in its class.
@immutable
class VerseReason {
  const VerseReason({required this.code, required this.verseClass, required this.label, required this.explanation});
  final String code;
  final VerseClass verseClass;
  final String label;
  final String explanation;
}

/// Book-level metadata (traditional attributions, recorded as such).
@immutable
class CatalogueBook {
  const CatalogueBook({
    required this.id,
    required this.name,
    required this.author,
    required this.form,
    required this.audience,
    required this.chapters,
  });

  final String id;
  final String name;
  final String author;
  final String form;
  final String audience;

  /// Per chapter, per verse: `class * 100 + reason`.
  final List<List<int>> chapters;
}

/// One verse's classification.
@immutable
class VerseClassification {
  const VerseClassification(this.verseClass, this.reason);
  final VerseClass verseClass;
  final VerseReason reason;
}

/// The complete personalisation catalogue for one MWB edition: every
/// canonical verse classified, plus the generated proposals (unapproved).
@immutable
class PersonalisationCatalogue {
  const PersonalisationCatalogue({
    required this.catalogueVersion,
    required this.generatorRuleVersion,
    required this.sourceVersionId,
    required this.targetVersionId,
    required this.reasons,
    required this.books,
    required this.proposals,
  });

  final String catalogueVersion;
  final int generatorRuleVersion;
  final String sourceVersionId;
  final String targetVersionId;
  final List<VerseReason> reasons;
  final List<CatalogueBook> books;

  /// Generated proposals. Hand-authored rules live in the edition's ruleset.
  final List<MwbRule> proposals;

  CatalogueBook? book(String id) => books.where((b) => b.id == id).firstOrNull;

  VerseClassification? classify(String bookId, int chapter, int verse) {
    final b = book(bookId);
    if (b == null || chapter < 1 || chapter > b.chapters.length) return null;
    final ch = b.chapters[chapter - 1];
    if (verse < 1 || verse > ch.length) return null;
    return decode(ch[verse - 1]);
  }

  VerseClassification decode(int code) {
    final reason = reasons[code % 100];
    return VerseClassification(VerseClass.values[code ~/ 100], reason);
  }

  int get verseCount => books.fold(0, (n, b) => n + b.chapters.fold(0, (m, c) => m + c.length));

  /// Verse counts by class, over the whole edition or one book.
  Map<VerseClass, int> classCounts({String? bookId, int? chapter}) {
    final out = {for (final c in VerseClass.values) c: 0};
    for (final b in books) {
      if (bookId != null && b.id != bookId) continue;
      for (var ci = 0; ci < b.chapters.length; ci++) {
        if (chapter != null && ci + 1 != chapter) continue;
        for (final code in b.chapters[ci]) {
          final k = VerseClass.values[code ~/ 100];
          out[k] = out[k]! + 1;
        }
      }
    }
    return out;
  }

  factory PersonalisationCatalogue.fromJson(Map<String, dynamic> j) {
    final source = j['sourceVersionId'] as String;
    final target = j['targetVersionId'] as String;
    final classByCode = {for (final c in VerseClass.values) c.name: c};
    final reasons = [
      for (final r in (j['reasons'] as List).cast<Map<String, dynamic>>())
        VerseReason(
          code: r['code'] as String,
          verseClass: classByCode[r['class']]!,
          label: r['label'] as String,
          explanation: r['explanation'] as String,
        ),
    ];
    final books = [
      for (final b in (j['books'] as List).cast<Map<String, dynamic>>())
        CatalogueBook(
          id: b['id'] as String,
          name: b['name'] as String,
          author: b['author'] as String,
          form: b['form'] as String,
          audience: b['audience'] as String,
          chapters: [for (final c in b['chapters'] as List) (c as List).cast<int>()],
        ),
    ];
    final proposals = <MwbRule>[];
    for (final p in (j['proposals'] as List).cast<Map<String, dynamic>>()) {
      try {
        proposals.add(MwbRule.fromJson(p, sourceVersionId: source, targetVersionId: target));
      } catch (_) {
        // Skip a malformed proposal; it is reported by the export test.
      }
    }
    return PersonalisationCatalogue(
      catalogueVersion: j['catalogueVersion'] as String,
      generatorRuleVersion: j['generatorRuleVersion'] as int,
      sourceVersionId: source,
      targetVersionId: target,
      reasons: reasons,
      books: books,
      proposals: proposals,
    );
  }
}
