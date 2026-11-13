import 'package:flutter/foundation.dart';

import '../../../data/catalogue/version_catalogue.dart';
import '../../../data/models/mwb_rule.dart';
import '../../../data/models/passage_context.dart';
import 'edit_engine.dart';
import 'risk_assessor.dart';

enum IssueSeverity { error, warning }

/// Every check the validator can report.
enum ValidationCode {
  versionMismatch,
  verseNotFound,
  sourceTextMismatch,
  noEdits,
  invalidPosition,
  anchorNotFound,
  anchorAmbiguous,
  overlappingEdits,
  unknownPlaceholder,
  nameNotInserted,
  insertionAddsWords,
  punctuationOnlyViolated,
  excessiveChange,
  foreignVocabulary,
  genderedTermChanged,
  punctuationDefect,
  recoveryFailed,
  approvalNotRecorded,
  approvalStale,
  riskUnderstated,
  contextMissing,
  processingFailed,

  /// A replacement removes a pronoun that carries person or number ("we",
  /// "you", "ye", "thee"…): the verse would change who is addressed.
  pronounReplaced,

  /// After a pronoun is replaced by a name, pronouns of the same person
  /// remain elsewhere in the verse ("fill Name … that ye may abound").
  residualPronoun,

  /// A name is followed by a plural or second-person verb ("Name are").
  verbAgreement,

  /// A word keeps its spelling but changes case ("you" → "You").
  capitalisationChanged,

  /// A source word is removed and not restored.
  sourceWordDeleted,

  /// Name-in-title: no title, or the title lacks the name.
  titleMissing,

  /// Name-in-title: the title uses first-person words, which would put a
  /// speaker's words into a title addressed to the reader.
  titleFirstPerson,

  /// Name-in-title proposals must leave the Scripture text unchanged.
  titleModeEditsScripture,
}

@immutable
class ValidationIssue {
  const ValidationIssue(this.code, this.severity, this.message);
  final ValidationCode code;
  final IssueSeverity severity;
  final String message;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '${severity.name}:${code.name}: $message';
}

@immutable
class ValidationReport {
  const ValidationReport({required this.ruleId, required this.issues, required this.risk});

  final String ruleId;
  final List<ValidationIssue> issues;

  /// Risk derived from context and operations.
  final RiskAssessment risk;

  /// True when there are no errors. Passing is a technical result only; it is
  /// never a theological approval.
  bool get passed => !issues.any((i) => i.isError);

  bool has(ValidationCode code) => issues.any((i) => i.code == code);
}

/// Automated structural, grammatical and versional checks for a rule.
///
/// Gender can never influence a rule: no gender field exists, templates may
/// only use `{name}`, and replacements may not add, remove or swap gendered
/// terms ("son" never becomes "daughter").
class PersonalisationValidator {
  const PersonalisationValidator(this.catalogue);

  final VersionCatalogue catalogue;

  /// A neutral name used to test grammar and recovery.
  static const sampleName = 'Sample Name';

  static final _punctuationOnly = RegExp(r'^[\s,;:.!?—–\-]*$');
  static final _placeholder = RegExp(r'\{[^}]*\}');
  static final _word = RegExp(r"[A-Za-z’']+");

  static const _gendered = {
    'son', 'sons', 'daughter', 'daughters', 'father', 'fathers', 'mother', 'mothers', //
    'brother', 'brothers', 'brethren', 'sister', 'sisters', 'man', 'men', 'woman', 'women',
    'he', 'him', 'his', 'himself', 'she', 'her', 'hers', 'herself', 'husband', 'wife',
    'king', 'queen', 'boy', 'girl', 'master', 'mistress',
  };

  /// Punctuation patterns that indicate a broken insertion. Compared against
  /// the source so pre-existing quirks in the canonical text are tolerated.
  static const _defects = ['  ', ' ,', ',,', ',;', ';,', ',:', ':,', ',.', ' ;', ' :', ' .', ' !', ' ?'];

  static List<String> words(String s) => _word.allMatches(s.toLowerCase()).map((m) => m.group(0)!).toList();

  static List<String> _rawWords(String s) => _word.allMatches(s).map((m) => m.group(0)!).toList();

  static const _firstPerson = {'i', 'me', 'my', 'mine', 'myself'};

  /// Pronouns that carry person or number, grouped by person.
  static const _personPronouns = {
    'i': 1, 'me': 1, 'my': 1, 'mine': 1, 'myself': 1, //
    'we': 1, 'us': 1, 'our': 1, 'ours': 1, 'ourselves': 1,
    'thou': 2, 'thee': 2, 'thy': 2, 'thine': 2, 'thyself': 2,
    'ye': 2, 'you': 2, 'your': 2, 'yours': 2, 'yourselves': 2, 'yourself': 2,
    'he': 3, 'him': 3, 'his': 3, 'himself': 3, 'she': 3, 'her': 3, 'hers': 3, 'herself': 3,
    'they': 3, 'them': 3, 'their': 3, 'theirs': 3, 'themselves': 3,
  };

  /// Verbs that cannot follow a singular third-person name.
  static final _badAgreement = RegExp(
    r'\{name\}\s*,?\s+(are|were|have|art|wast|hast|shalt|wilt|canst|dost|didst|be)\b',
    caseSensitive: false,
  );

  /// Person, number, agreement, case and deletion checks for a tracked
  /// replacement. These catch the historical Ephesians 2:10 defect and the
  /// founder-reference Romans 15:13 proposals.
  void _checkReplacement(
    RuleEdit e,
    String source,
    void Function(ValidationCode, String) error,
    void Function(ValidationCode, String) warn,
  ) {
    final before = _rawWords(e.anchor);
    final afterRaw = _rawWords(e.text.replaceAll(namePlaceholder, ' '));
    final beforeLower = before.map((w) => w.toLowerCase()).toList();
    final afterLower = afterRaw.map((w) => w.toLowerCase()).toList();

    final removed = [...beforeLower];
    for (final w in afterLower) {
      removed.remove(w);
    }
    final removedPronouns = removed.where(_personPronouns.containsKey).toList();
    if (removedPronouns.isNotEmpty) {
      error(
        ValidationCode.pronounReplaced,
        'Replaces the pronoun(s) ${removedPronouns.map((p) => '“$p”').join(', ')}, which changes who is addressed or '
        'speaking.',
      );
      final persons = removedPronouns.map((p) => _personPronouns[p]).toSet();
      final rest = words(source.replaceFirst(e.anchor, ' '));
      final residual = rest.where((w) => persons.contains(_personPronouns[w])).toSet();
      if (residual.isNotEmpty) {
        error(
          ValidationCode.residualPronoun,
          'The verse still uses ${residual.map((p) => '“$p”').join(', ')} for the same person, so it would no longer '
          'agree with the replacement.',
        );
      }
    }
    final nonPronounRemoved = removed.where((w) => !_personPronouns.containsKey(w)).toList();
    if (nonPronounRemoved.isNotEmpty) {
      // Caught and shown to reviewers. Small reviewed word changes stay
      // approvable (founder decision, 2026-11-11); more than two is an error
      // via excessiveChange.
      warn(
        ValidationCode.sourceWordDeleted,
        'Removes source word(s) ${nonPronounRemoved.map((w) => '“$w”').join(', ')} without restoring them.',
      );
    }
    if (_badAgreement.hasMatch(e.text)) {
      error(ValidationCode.verbAgreement, 'The name is followed by a verb that does not agree with a single person.');
    }
    final recased = <String>{};
    for (final w in afterRaw) {
      final lower = w.toLowerCase();
      if (beforeLower.contains(lower) && !before.contains(w)) recased.add('“${before[beforeLower.indexOf(lower)]}” → “$w”');
    }
    if (recased.isNotEmpty) {
      error(
        ValidationCode.capitalisationChanged,
        'Changes capitalisation (${recased.join(', ')}). A capitalised pronoun reads as a divine pronoun.',
      );
    }
  }

  static int _count(String s, String pattern) {
    var n = 0;
    var i = s.indexOf(pattern);
    while (i >= 0) {
      n++;
      i = s.indexOf(pattern, i + 1);
    }
    return n;
  }

  ValidationReport validate(
    MwbRule rule, {
    required String? canonicalText,
    required VersionStyleProfile style,
    PassageContext? context,
  }) {
    final issues = <ValidationIssue>[];
    void error(ValidationCode c, String m) => issues.add(ValidationIssue(c, IssueSeverity.error, m));
    void warn(ValidationCode c, String m) => issues.add(ValidationIssue(c, IssueSeverity.warning, m));

    // 1. Version integrity.
    final target = catalogue.byId(rule.targetVersionId);
    if (target == null || !target.isPersonalised) {
      error(ValidationCode.versionMismatch, '${rule.targetVersionId} is not an MWB edition in the catalogue.');
    } else if (target.sourceVersionId != rule.sourceVersionId) {
      error(
        ValidationCode.versionMismatch,
        '${rule.targetVersionId} derives from ${target.sourceVersionId}, not ${rule.sourceVersionId}.',
      );
    }
    if (style.versionId != rule.sourceVersionId) {
      error(
        ValidationCode.versionMismatch,
        'Style rules for ${style.versionId} cannot check a ${rule.sourceVersionId} rule.',
      );
    }

    // 2. Exact source text.
    if (canonicalText == null) {
      error(ValidationCode.verseNotFound, '${rule.reference.label} is not in ${rule.sourceVersionId}.');
    } else if (canonicalText != rule.sourceText) {
      error(ValidationCode.sourceTextMismatch, 'The rule was written against different text than the canonical verse.');
    }

    // 3. Edit shape.
    final titleMode = rule.presentationMode == PresentationMode.nameInTitle;
    if (titleMode) {
      final title = rule.titleTemplate?.trim() ?? '';
      if (rule.edits.isNotEmpty) {
        error(ValidationCode.titleModeEditsScripture, 'A name-in-title proposal must show the Scripture unchanged.');
      }
      if (title.isEmpty) {
        error(ValidationCode.titleMissing, 'An editorial title is still needed.');
      } else {
        if (_count(title, namePlaceholder) != 1) {
          error(ValidationCode.titleMissing, 'The title must contain $namePlaceholder exactly once.');
        }
        final unknown = _placeholder.allMatches(title).map((m) => m.group(0)!).where((p) => p != namePlaceholder);
        if (unknown.isNotEmpty) {
          error(ValidationCode.unknownPlaceholder, 'Only $namePlaceholder may be used; found ${unknown.join(', ')}.');
        }
        final firstPerson = words(title.replaceAll(namePlaceholder, ' ')).where(_firstPerson.contains).toSet();
        if (firstPerson.isNotEmpty) {
          error(
            ValidationCode.titleFirstPerson,
            'The title uses first-person words (${firstPerson.join(', ')}), which would make a speaker address the reader.',
          );
        }
      }
    } else if (rule.edits.isEmpty) {
      error(ValidationCode.noEdits, 'The rule has no edits.');
    }
    final sourceWords = words(rule.sourceText).toSet();
    for (final e in rule.edits) {
      final inserting = e.operation.insertsName;
      if (inserting == (e.position == EditPosition.replace)) {
        error(ValidationCode.invalidPosition, '${e.operation.name} cannot use position ${e.position.name}.');
      }
      final unknown = _placeholder.allMatches(e.text).map((m) => m.group(0)!).where((p) => p != namePlaceholder);
      if (unknown.isNotEmpty) {
        error(ValidationCode.unknownPlaceholder, 'Only $namePlaceholder may be used; found ${unknown.join(', ')}.');
      }
      final withoutName = e.text.replaceAll(namePlaceholder, ' ');
      switch (e.operation) {
        case PersonalisationOperation.insertDirectAddress:
        case PersonalisationOperation.appendPersonalName:
        case PersonalisationOperation.insertNameAfterExistingAddress:
          if (_count(e.text, namePlaceholder) != 1) {
            error(ValidationCode.nameNotInserted, 'A name insertion must contain $namePlaceholder exactly once.');
          }
          if (!_punctuationOnly.hasMatch(withoutName)) {
            error(ValidationCode.insertionAddsWords, 'A name insertion may add only the name and punctuation.');
          }
        case PersonalisationOperation.punctuationAdjustment:
          if (!_punctuationOnly.hasMatch(e.anchor) || !_punctuationOnly.hasMatch(e.text)) {
            error(ValidationCode.punctuationOnlyViolated, 'A punctuation adjustment may change punctuation only.');
          }
        case PersonalisationOperation.approvedMinimalGrammaticalAdjustment:
          final before = words(e.anchor);
          final after = words(withoutName);
          final added = [...after]..removeWhere(before.contains);
          final removed = [...before]..removeWhere(after.contains);
          if (added.length > 2 || removed.length > 2) {
            error(
              ValidationCode.excessiveChange,
              'Changes ${removed.length} source word(s) and adds ${added.length}; at most two of each is minimal.',
            );
          }
          final foreign = added.where((w) => !sourceWords.contains(w) && !style.allowedAddedWords.contains(w)).toSet();
          if (foreign.isNotEmpty) {
            error(
              ValidationCode.foreignVocabulary,
              'Introduces words not used by this ${rule.sourceVersionId} verse: ${foreign.join(', ')}.',
            );
          }
          final gBefore = before.where(_gendered.contains).toList()..sort();
          final gAfter = after.where(_gendered.contains).toList()..sort();
          if (!listEquals(gBefore, gAfter)) {
            error(ValidationCode.genderedTermChanged, 'Gendered or relational terms must be preserved exactly.');
          }
          _checkReplacement(e, rule.sourceText, error, warn);
      }
      if (e.operation == PersonalisationOperation.punctuationAdjustment) _checkReplacement(e, rule.sourceText, error, warn);
    }

    // 4. Location, application, grammar and exact recovery.
    if (canonicalText != null && canonicalText == rule.sourceText && rule.edits.isNotEmpty && !titleMode) {
      final located = EditEngine.locate(rule.edits, canonicalText);
      for (final entry in located.errors.entries) {
        error(switch (entry.key) {
          LocateError.emptyAnchor || LocateError.notFound => ValidationCode.anchorNotFound,
          LocateError.ambiguous => ValidationCode.anchorAmbiguous,
          LocateError.overlapping => ValidationCode.overlappingEdits,
        }, entry.value);
      }
      if (located.ok) {
        final segments = EditEngine.apply(canonicalText, located.edits, sampleName, ruleId: rule.id);
        final rendered = segments.map((s) => s.text).join();
        final recovered = segments.map((s) => s.original).join();
        if (recovered != canonicalText) {
          error(ValidationCode.recoveryFailed, 'The source cannot be rebuilt exactly from the rendering.');
        }
        for (final d in _defects) {
          if (_count(rendered, d) > _count(canonicalText, d)) {
            error(ValidationCode.punctuationDefect, 'The rendering introduces "${d.replaceAll(' ', '␣')}".');
          }
        }
      }
    }

    // 5. Review integrity: an approval must be real and current.
    if (rule.effectiveStatus == RuleStatus.approved && rule.validApproval == null) {
      final approvals = rule.reviews.where((r) => r.action == ReviewAction.approved);
      if (approvals.any((r) => r.hasReviewer && r.ruleVersion != rule.ruleVersion)) {
        error(ValidationCode.approvalStale, 'The approval was for an earlier version of this rule.');
      } else {
        error(ValidationCode.approvalNotRecorded, 'Marked approved without a recorded human reviewer and date.');
      }
    }

    // 6. Risk.
    final risk = RiskAssessor.assess(rule, context);
    if (context == null) {
      warn(ValidationCode.contextMissing, 'No passage context is recorded for ${rule.reference.label}.');
    }
    if (rule.declaredRisk.index < risk.level.index) {
      warn(
        ValidationCode.riskUnderstated,
        'Declared ${rule.declaredRisk.label} but context indicates ${risk.level.label}: ${risk.reasons.join(' ')}',
      );
    }
    return ValidationReport(ruleId: rule.id, issues: issues, risk: risk);
  }
}
