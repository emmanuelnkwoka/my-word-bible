import 'package:flutter/foundation.dart';

import 'scripture_reference.dart';

/// The controlled operations an MWB rule may perform on a source verse.
///
/// The first three only *insert* text around an exact anchor: the source
/// wording stays untouched. The last two *replace* a small anchored span and
/// are tracked so the original can always be recovered.
enum PersonalisationOperation {
  /// Adds the name as a direct address where the verse already addresses the
  /// reader, but without an explicit form of address at that point.
  insertDirectAddress,

  /// Appends the name at the end of a clause or the verse.
  appendPersonalName,

  /// Adds the name after an existing form of address ("My son," → "My son, Name,").
  insertNameAfterExistingAddress,

  /// Adjusts punctuation only (no words change).
  punctuationAdjustment,

  /// A minimal grammatical change (a word or two) needed for natural direct
  /// address. Never publishes without an explicit recorded approval.
  approvedMinimalGrammaticalAdjustment;

  bool get insertsName =>
      this == insertDirectAddress || this == appendPersonalName || this == insertNameAfterExistingAddress;
  bool get replacesSource => !insertsName;
}

/// Where an edit applies relative to its anchor.
enum EditPosition { before, after, replace }

/// Profile data a rule needs. Gender is deliberately not representable: it
/// can never influence a rendering.
enum ProfileField { personalName }

/// Lifecycle of a rule. Automated validation and human theological approval
/// are separate steps; only [approved] rules are shown to readers.
enum RuleStatus {
  proposed('Proposed'),
  automatedValidated('Automated checks passed'),
  underReview('Under theological review'),
  approved('Approved'),
  rejected('Rejected'),
  retired('Retired');

  const RuleStatus(this.label);
  final String label;

  bool get isClosed => this == rejected || this == retired;
}

/// Risk indicator for review prioritisation. Not proof of correctness.
enum RiskLevel {
  /// Straightforward personal address with no identified concerns.
  low('Low'),

  /// Unclear grammar, audience or interpretation.
  medium('Medium'),

  /// Conditional promise, collective audience, specific relationship,
  /// covenantal context or other substantial uncertainty.
  high('High'),

  /// Direct divine speech, potential doctrinal change or disputed meaning.
  critical('Critical');

  const RiskLevel(this.label);
  final String label;

  RiskLevel max(RiskLevel other) => index >= other.index ? this : other;
}

/// The placeholder for the reader's resolved name in edit templates.
const namePlaceholder = '{name}';

/// One anchored edit within a rule.
@immutable
class RuleEdit {
  const RuleEdit({
    required this.operation,
    required this.anchor,
    required this.position,
    required this.text,
    this.occurrence,
  });

  final PersonalisationOperation operation;

  /// Exact source text the edit is attached to.
  final String anchor;

  /// Which occurrence of [anchor] (1-based). Required when the anchor occurs
  /// more than once in the verse; otherwise the single occurrence is used.
  final int? occurrence;
  final EditPosition position;

  /// Inserted text (insert operations) or replacement text (replace
  /// operations). May contain [namePlaceholder].
  final String text;

  Map<String, dynamic> toJson() => {
    'operation': operation.name,
    'anchor': anchor,
    if (occurrence != null) 'occurrence': occurrence,
    'position': position.name,
    'text': text,
  };

  factory RuleEdit.fromJson(Map<String, dynamic> j) => RuleEdit(
    operation: PersonalisationOperation.values.byName(j['operation'] as String),
    anchor: j['anchor'] as String,
    occurrence: j['occurrence'] as int?,
    position: EditPosition.values.byName(j['position'] as String),
    text: j['text'] as String,
  );
}

/// What a review step did.
enum ReviewAction { submitted, approved, rejected, retired, comment }

/// One entry in a rule's review history.
///
/// An approval is only valid when it names a human [reviewer], carries the
/// actual date of the decision and applies to the rule's current version.
@immutable
class ReviewRecord {
  const ReviewRecord({
    required this.action,
    required this.at,
    required this.ruleVersion,
    this.reviewer,
    this.reviewerRole,
    this.comments = '',
    this.rejectionReason,
  });

  final ReviewAction action;
  final DateTime at;
  final int ruleVersion;
  final String? reviewer;
  final String? reviewerRole;
  final String comments;
  final String? rejectionReason;

  /// The status this record moves the rule to, if any.
  RuleStatus? get resultingStatus => switch (action) {
    ReviewAction.submitted => RuleStatus.underReview,
    ReviewAction.approved => RuleStatus.approved,
    ReviewAction.rejected => RuleStatus.rejected,
    ReviewAction.retired => RuleStatus.retired,
    ReviewAction.comment => null,
  };

  bool get hasReviewer => (reviewer ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'at': at.toIso8601String(),
    'ruleVersion': ruleVersion,
    if (reviewer != null) 'reviewer': reviewer,
    if (reviewerRole != null) 'reviewerRole': reviewerRole,
    if (comments.isNotEmpty) 'comments': comments,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
  };

  factory ReviewRecord.fromJson(Map<String, dynamic> j) => ReviewRecord(
    action: ReviewAction.values.byName(j['action'] as String),
    at: DateTime.parse(j['at'] as String),
    ruleVersion: j['ruleVersion'] as int,
    reviewer: j['reviewer'] as String?,
    reviewerRole: j['reviewerRole'] as String?,
    comments: j['comments'] as String? ?? '',
    rejectionReason: j['rejectionReason'] as String?,
  );
}

/// A version-specific personalisation rule for a single verse.
///
/// A rule belongs to exactly one source translation and one MWB edition. It
/// never applies to any other version.
@immutable
class MwbRule {
  const MwbRule({
    required this.id,
    required this.ruleVersion,
    required this.sourceVersionId,
    required this.targetVersionId,
    required this.reference,
    required this.sourceText,
    required this.edits,
    required this.declaredRisk,
    required this.status,
    this.requiredFields = const {ProfileField.personalName},
    this.grammaticalConditions = const [],
    this.riskReasons = const [],
    this.reviewQuestion,
    this.rejectionReason,
    this.notes = '',
    this.reviews = const [],
  });

  final String id;

  /// Incremented whenever the rule's edits change. Approvals apply to one
  /// rule version only.
  final int ruleVersion;
  final String sourceVersionId;
  final String targetVersionId;

  /// A single verse.
  final ScriptureReference reference;

  /// The exact canonical verse text the rule was written against.
  final String sourceText;
  final List<RuleEdit> edits;
  final RiskLevel declaredRisk;

  /// Status as recorded in the rule data. See [effectiveStatus].
  final RuleStatus status;
  final Set<ProfileField> requiredFields;
  final List<String> grammaticalConditions;
  final List<String> riskReasons;

  /// The decision a theological reviewer is asked to make, if any.
  final String? reviewQuestion;
  final String? rejectionReason;
  final String notes;
  final List<ReviewRecord> reviews;

  /// Status after applying the review history: the most recent
  /// status-changing record wins over the recorded [status].
  RuleStatus get effectiveStatus {
    for (final r in reviews.reversed) {
      final s = r.resultingStatus;
      if (s != null) return s;
    }
    return status;
  }

  /// The approval record that makes this rule publishable, or null.
  ///
  /// Requires the latest status-changing record to be an approval by a named
  /// human reviewer for the current [ruleVersion].
  ReviewRecord? get validApproval {
    for (final r in reviews.reversed) {
      if (r.resultingStatus == null) continue;
      if (r.action == ReviewAction.approved && r.hasReviewer && r.ruleVersion == ruleVersion) return r;
      return null;
    }
    return null;
  }

  MwbRule withReviews(List<ReviewRecord> extra) => extra.isEmpty
      ? this
      : MwbRule(
          id: id,
          ruleVersion: ruleVersion,
          sourceVersionId: sourceVersionId,
          targetVersionId: targetVersionId,
          reference: reference,
          sourceText: sourceText,
          edits: edits,
          declaredRisk: declaredRisk,
          status: status,
          requiredFields: requiredFields,
          grammaticalConditions: grammaticalConditions,
          riskReasons: riskReasons,
          reviewQuestion: reviewQuestion,
          rejectionReason: rejectionReason,
          notes: notes,
          reviews: [...reviews, ...extra],
        );

  factory MwbRule.fromJson(Map<String, dynamic> j, {required String sourceVersionId, required String targetVersionId}) {
    final fields = (j['requiredFields'] as List?)?.cast<String>().map(ProfileField.values.byName).toSet();
    return MwbRule(
      id: j['id'] as String,
      ruleVersion: j['ruleVersion'] as int,
      sourceVersionId: j['sourceVersionId'] as String? ?? sourceVersionId,
      targetVersionId: j['targetVersionId'] as String? ?? targetVersionId,
      reference: ScriptureReference.parseCompact(j['reference'] as String),
      sourceText: j['sourceText'] as String,
      edits: (j['edits'] as List).cast<Map<String, dynamic>>().map(RuleEdit.fromJson).toList(),
      declaredRisk: RiskLevel.values.byName(j['risk'] as String),
      status: RuleStatus.values.byName(j['status'] as String),
      requiredFields: fields ?? const {ProfileField.personalName},
      grammaticalConditions: (j['grammaticalConditions'] as List?)?.cast<String>() ?? const [],
      riskReasons: (j['riskReasons'] as List?)?.cast<String>() ?? const [],
      reviewQuestion: j['reviewQuestion'] as String?,
      rejectionReason: j['rejectionReason'] as String?,
      notes: j['notes'] as String? ?? '',
      reviews: (j['reviews'] as List?)?.cast<Map<String, dynamic>>().map(ReviewRecord.fromJson).toList() ?? const [],
    );
  }
}

/// Version-specific vocabulary policy used by the validator.
@immutable
class VersionStyleProfile {
  const VersionStyleProfile({required this.versionId, this.allowedAddedWords = const {}, this.notes = ''});

  final String versionId;

  /// Words a rule may add besides the reader's name, beyond words already in
  /// the verse (e.g. the vocative "O" in the KJV). Lower case.
  final Set<String> allowedAddedWords;
  final String notes;

  factory VersionStyleProfile.fromJson(String versionId, Map<String, dynamic>? j) => VersionStyleProfile(
    versionId: versionId,
    allowedAddedWords: ((j?['allowedAddedWords'] as List?)?.cast<String>() ?? const [])
        .map((w) => w.toLowerCase())
        .toSet(),
    notes: j?['notes'] as String? ?? '',
  );
}

/// The designated theological supervisor for a ruleset. Being designated is
/// not the same as having approved anything.
@immutable
class TheologicalSupervisor {
  const TheologicalSupervisor({required this.name, required this.role});
  final String name;
  final String role;
}

/// All rules for one MWB edition.
@immutable
class MwbRuleset {
  const MwbRuleset({
    required this.sourceVersionId,
    required this.targetVersionId,
    required this.rulesetVersion,
    required this.style,
    required this.rules,
    this.supervisor,
    this.loadIssues = const [],
  });

  final String sourceVersionId;
  final String targetVersionId;
  final int rulesetVersion;
  final VersionStyleProfile style;
  final List<MwbRule> rules;
  final TheologicalSupervisor? supervisor;

  /// Rules that could not be parsed. They are skipped; others still load.
  final List<String> loadIssues;

  List<MwbRule> rulesForVerse(ScriptureReference verse) => rules
      .where(
        (r) =>
            r.reference.bookId == verse.bookId &&
            r.reference.chapter == verse.chapter &&
            r.reference.verseStart == verse.verseStart,
      )
      .toList();
}
