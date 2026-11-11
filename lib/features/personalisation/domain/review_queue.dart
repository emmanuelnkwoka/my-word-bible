import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../data/models/mwb_rule.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/repositories/bible_repository.dart';
import '../../../data/repositories/mwb_ruleset_repository.dart';
import '../../../data/repositories/passage_context_repository.dart';
import '../../../data/repositories/theological_review_repository.dart';
import 'ruleset_processor.dart';

/// A decision a human reviewer makes about a rule.
@immutable
class ReviewDecision {
  const ReviewDecision({
    required this.action,
    required this.at,
    this.reviewer,
    this.reviewerRole,
    this.comments = '',
    this.rejectionReason,
  });

  final ReviewAction action;

  /// The actual date of the decision.
  final DateTime at;
  final String? reviewer;
  final String? reviewerRole;
  final String comments;
  final String? rejectionReason;
}

/// Theological review workflow over the rulesets.
///
/// Independent of rendering: pending items never block other rules, and
/// nothing here is ever approved automatically.
class ReviewQueueService {
  ReviewQueueService({
    required this.rulesets,
    required this.bible,
    required this.contexts,
    required this.reviews,
    required this.processor,
  });

  final MwbRulesetRepository rulesets;
  final BibleRepository bible;
  final PassageContextRepository contexts;
  final TheologicalReviewRepository reviews;
  final MwbRulesetProcessor processor;

  /// The ruleset with locally recorded decisions applied to each rule.
  Future<MwbRuleset> effectiveRuleset(String targetVersionId) async {
    final base = await rulesets.ruleset(targetVersionId);
    final local = reviews.allDecisions();
    if (local.isEmpty) return base;
    return MwbRuleset(
      sourceVersionId: base.sourceVersionId,
      targetVersionId: base.targetVersionId,
      rulesetVersion: base.rulesetVersion,
      style: base.style,
      supervisor: base.supervisor,
      loadIssues: base.loadIssues,
      rules: [for (final r in base.rules) r.withReviews(local[r.id] ?? const [])],
    );
  }

  Future<String?> _canonical(String versionId, ScriptureReference verse) async {
    try {
      final p = await bible.passage(versionId, verse);
      return p.verses.length == 1 ? p.verses.single.text : null;
    } on NotFoundFailure {
      return null;
    }
  }

  /// Every rule of an edition after automated processing, in review order:
  /// open items first (highest risk first), then closed ones.
  Future<List<ProcessedRule>> queue(String targetVersionId) async {
    final ruleset = await effectiveRuleset(targetVersionId);
    final processed = await processor.process(
      ruleset,
      canonicalText: (v) => _canonical(ruleset.sourceVersionId, v),
      contextFor: contexts.contextFor,
    );
    int rank(ProcessedRule p) => switch (p.status) {
      RuleStatus.underReview || RuleStatus.automatedValidated || RuleStatus.proposed => 0,
      RuleStatus.approved => 1,
      RuleStatus.rejected => 2,
      RuleStatus.retired => 3,
    };
    processed.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final k = b.risk.index.compareTo(a.risk.index);
      if (k != 0) return k;
      final ref = a.rule.reference.compareTo(b.rule.reference);
      return ref != 0 ? ref : a.rule.id.compareTo(b.rule.id);
    });
    return processed;
  }

  /// Records a human decision. Approval requires a named reviewer and a rule
  /// that currently passes automated validation; rejection requires a reason.
  Future<void> recordDecision(String targetVersionId, String ruleId, ReviewDecision d) async {
    final processed = (await queue(targetVersionId)).where((p) => p.rule.id == ruleId).firstOrNull;
    if (processed == null) throw const NotFoundFailure('That personalisation rule does not exist.');
    final reviewer = d.reviewer?.trim() ?? '';
    switch (d.action) {
      case ReviewAction.approved:
        if (reviewer.isEmpty) throw const ValidationFailure('An approval must name the human reviewer.');
        if (!processed.report.passed) {
          throw const ValidationFailure('This rule fails automated validation and cannot be approved.');
        }
      case ReviewAction.rejected:
        if ((d.rejectionReason ?? '').trim().isEmpty) throw const ValidationFailure('A rejection needs a reason.');
      case ReviewAction.submitted || ReviewAction.retired || ReviewAction.comment:
        break;
    }
    await reviews.append(
      ruleId,
      ReviewRecord(
        action: d.action,
        at: d.at,
        ruleVersion: processed.rule.ruleVersion,
        reviewer: reviewer.isEmpty ? null : reviewer,
        reviewerRole: d.reviewerRole,
        comments: d.comments,
        rejectionReason: d.rejectionReason,
      ),
    );
  }
}

/// Renders the review queue as a Markdown document a reviewer can read
/// without access to the source code.
abstract final class ReviewQueueExporter {
  static final _trailingStop = RegExp(r'\.$');

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String toMarkdown(MwbRuleset ruleset, List<ProcessedRule> items) {
    final b = StringBuffer();
    final open = items.where((p) => !p.status.isClosed && p.status != RuleStatus.approved).toList();
    b.writeln('# ${ruleset.targetVersionId} theological review queue');
    b.writeln();
    b.writeln(
      'Personalisation rules for **${ruleset.targetVersionId}**, derived from the **${ruleset.sourceVersionId}**. '
      'Ruleset version ${ruleset.rulesetVersion}.',
    );
    if (ruleset.supervisor != null) {
      b.writeln();
      b.writeln(
        '${ruleset.supervisor!.role}: **${ruleset.supervisor!.name}**. '
        'Being designated is not an approval: a rule is approved only when an approval with the reviewer and '
        'date is recorded below.',
      );
    }
    b.writeln();
    b.writeln('Generated from `assets/mwb/rulesets/` by the test suite. Do not edit by hand.');
    b.writeln();
    b.writeln('| Status | Count |');
    b.writeln('| --- | --- |');
    for (final s in RuleStatus.values) {
      final n = items.where((p) => p.status == s).length;
      if (n > 0) b.writeln('| ${s.label} | $n |');
    }
    b.writeln();
    b.writeln(
      'Awaiting a decision: **${open.length}**. "Automated checks passed" is a technical result, not a theological approval.',
    );
    b.writeln();
    b.writeln('Proposed renderings show `$reviewNamePlaceholder` where the reader’s name would appear.');
    for (final p in items) {
      final r = p.rule;
      b.writeln();
      b.writeln('---');
      b.writeln();
      b.writeln('## ${r.reference.label} — ${p.risk.label} risk — ${p.status.label}');
      b.writeln();
      b.writeln('- **Rule:** `${r.id}` (rule version ${r.ruleVersion})');
      b.writeln('- **Edition:** ${r.targetVersionId} (from ${r.sourceVersionId})');
      b.writeln('- **Operation:** ${r.edits.map((e) => e.operation.name).join(', ')}');
      b.writeln('- **Original ${r.sourceVersionId}:** ${p.canonicalText ?? '(verse not found)'}');
      b.writeln('- **Proposed ${r.targetVersionId}:** ${p.previewText ?? '(cannot be rendered — see validation)'}');
      final c = p.context;
      if (c != null) {
        b.writeln('- **Context:** ${c.author}. Speaker: ${c.speaker.label}. Audience: ${c.originalAudience}');
        if (c.literaryContext.isNotEmpty) b.writeln('- **Literary context:** ${c.literaryContext}');
        if (c.conditionNote.isNotEmpty) b.writeln('- **Condition:** ${c.conditionNote}');
      } else {
        b.writeln('- **Context:** not recorded');
      }
      final reasons = {...r.riskReasons, ...p.report.risk.reasons};
      if (reasons.isNotEmpty) b.writeln('- **Risk reasons:** ${reasons.join(' ')}');
      if (r.grammaticalConditions.isNotEmpty) b.writeln('- **Grammar:** ${r.grammaticalConditions.join(' ')}');
      final issues = p.report.issues.map((i) => '${i.severity.name}: ${i.message.replaceAll(_trailingStop, '')}');
      b.writeln(
        '- **Automated validation:** ${p.report.passed ? 'passed' : 'failed'}'
        '${issues.isEmpty ? '' : ' — ${issues.join('; ')}'}',
      );
      if (r.reviewQuestion != null) b.writeln('- **Question for the reviewer:** ${r.reviewQuestion}');
      if (r.rejectionReason != null) b.writeln('- **Rejection reason:** ${r.rejectionReason}');
      if (r.notes.isNotEmpty) b.writeln('- **Notes:** ${r.notes}');
      if (r.reviews.isEmpty) {
        b.writeln('- **Review history:** none');
      } else {
        b.writeln('- **Review history:**');
        for (final h in r.reviews) {
          final who = h.hasReviewer
              ? '${h.reviewer}${h.reviewerRole == null ? '' : ' (${h.reviewerRole})'}'
              : 'unnamed';
          final why = h.rejectionReason ?? (h.comments.isEmpty ? '' : h.comments);
          b.writeln(
            '  - ${_date(h.at)} — ${h.action.name} by $who, rule version ${h.ruleVersion}${why.isEmpty ? '' : ': $why'}',
          );
        }
      }
    }
    return b.toString();
  }
}
