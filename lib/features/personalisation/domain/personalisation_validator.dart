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
    if (rule.edits.isEmpty) error(ValidationCode.noEdits, 'The rule has no edits.');
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
      }
    }

    // 4. Location, application, grammar and exact recovery.
    if (canonicalText != null && canonicalText == rule.sourceText && rule.edits.isNotEmpty) {
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
