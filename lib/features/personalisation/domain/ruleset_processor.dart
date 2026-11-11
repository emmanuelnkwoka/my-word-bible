import 'package:flutter/foundation.dart';

import '../../../data/models/mwb_rule.dart';
import '../../../data/models/passage_context.dart';
import '../../../data/models/scripture_reference.dart';
import 'edit_engine.dart';
import 'personalisation_validator.dart';
import 'risk_assessor.dart';

/// Placeholder used when showing a proposed rendering to reviewers.
const reviewNamePlaceholder = '[Name]';

/// A rule after automated processing.
@immutable
class ProcessedRule {
  const ProcessedRule({
    required this.rule,
    required this.report,
    required this.status,
    required this.risk,
    this.context,
    this.canonicalText,
    this.previewText,
  });

  final MwbRule rule;
  final ValidationReport report;

  /// Status for the review queue: recorded status plus automated validation.
  final RuleStatus status;

  /// The higher of declared and assessed risk.
  final RiskLevel risk;
  final PassageContext? context;
  final String? canonicalText;

  /// Proposed rendering with [reviewNamePlaceholder] in place of a name.
  final String? previewText;
}

/// Runs automated validation over a whole ruleset.
///
/// "Skip, flag and continue": every rule is processed independently. A rule
/// that fails, or even throws, is recorded with its reason and the rest are
/// still processed.
class MwbRulesetProcessor {
  const MwbRulesetProcessor(this.validator);

  final PersonalisationValidator validator;

  /// Moves a proposed rule to automatedValidated when it passes. Never moves
  /// anything to approved, and treats an unrecorded approval as unapproved.
  static RuleStatus statusFor(MwbRule rule, ValidationReport report) {
    final s = rule.effectiveStatus;
    if (s == RuleStatus.approved && rule.validApproval == null) return RuleStatus.proposed;
    if (s == RuleStatus.proposed && report.passed) return RuleStatus.automatedValidated;
    return s;
  }

  Future<List<ProcessedRule>> process(
    MwbRuleset ruleset, {
    required Future<String?> Function(ScriptureReference verse) canonicalText,
    required Future<PassageContext?> Function(ScriptureReference verse) contextFor,
  }) async {
    final out = <ProcessedRule>[];
    for (final rule in ruleset.rules) {
      String? canonical;
      PassageContext? context;
      try {
        canonical = await canonicalText(rule.reference);
        context = await contextFor(rule.reference);
        final report = validator.validate(rule, canonicalText: canonical, style: ruleset.style, context: context);
        out.add(
          ProcessedRule(
            rule: rule,
            report: report,
            status: statusFor(rule, report),
            risk: rule.declaredRisk.max(report.risk.level),
            context: context,
            canonicalText: canonical,
            previewText: _preview(rule, canonical),
          ),
        );
      } catch (e) {
        out.add(
          ProcessedRule(
            rule: rule,
            report: ValidationReport(
              ruleId: rule.id,
              issues: [ValidationIssue(ValidationCode.processingFailed, IssueSeverity.error, 'Processing failed: $e')],
              risk: RiskAssessment(rule.declaredRisk, const []),
            ),
            status: rule.effectiveStatus == RuleStatus.approved ? RuleStatus.proposed : rule.effectiveStatus,
            risk: rule.declaredRisk,
            context: context,
            canonicalText: canonical,
          ),
        );
      }
    }
    return out;
  }

  static String? _preview(MwbRule rule, String? canonical) {
    if (canonical == null || canonical != rule.sourceText) return null;
    final located = EditEngine.locate(rule.edits, canonical);
    if (!located.ok) return null;
    return EditEngine.apply(canonical, located.edits, reviewNamePlaceholder, ruleId: rule.id).map((s) => s.text).join();
  }
}
