import '../../../data/catalogue/version_catalogue.dart';
import '../../../data/models/bible.dart';
import '../../../data/models/mwb_rule.dart';
import '../../../data/models/passage_context.dart';
import 'edit_engine.dart';
import 'personal_name.dart';
import 'personalisation_validator.dart';
import 'rendered_verse.dart';

/// Which rules may be shown to readers.
enum PublicationPolicy {
  /// Production: only rules with a recorded human approval for their current
  /// version.
  approvedOnly,

  /// Reviewer builds: also shows proposed / automated-validated / under-review
  /// rules, marked as previews. Rejected and retired rules never render.
  reviewPreview,
}

/// Renders a canonical verse in an MWB edition.
///
/// Fails safe: whenever any condition is not met the untouched source verse
/// is returned, with an [RenderOutcome] saying why. Nothing it produces is
/// ever persisted in place of canonical text.
class MwbRenderer {
  const MwbRenderer({required this.catalogue, required this.validator, this.policy = PublicationPolicy.approvedOnly});

  final VersionCatalogue catalogue;
  final PersonalisationValidator validator;
  final PublicationPolicy policy;

  bool isPublishable(MwbRule rule) => switch (policy) {
    PublicationPolicy.approvedOnly => rule.validApproval != null,
    PublicationPolicy.reviewPreview => !rule.effectiveStatus.isClosed,
  };

  RenderedVerse render({
    required Verse source,
    required String sourceVersionId,
    required String targetVersionId,
    required MwbRuleset? ruleset,
    required NameResolution name,
    PassageContext? context,
  }) {
    RenderedVerse original(RenderOutcome outcome, [String? ruleId]) => RenderedVerse.original(
      source,
      sourceVersionId: sourceVersionId,
      targetVersionId: targetVersionId,
      outcome: outcome,
      ruleId: ruleId,
    );

    try {
      // Edition, source and ruleset must all agree.
      final edition = catalogue.byId(targetVersionId);
      if (edition == null || !edition.isPersonalised || edition.sourceVersionId != sourceVersionId) {
        return original(RenderOutcome.versionMismatch);
      }
      if (ruleset == null) return original(RenderOutcome.noRule);
      if (ruleset.targetVersionId != targetVersionId || ruleset.sourceVersionId != sourceVersionId) {
        return original(RenderOutcome.versionMismatch);
      }

      final candidates = ruleset
          .rulesForVerse(source.reference)
          .where((r) => r.targetVersionId == targetVersionId && r.sourceVersionId == sourceVersionId)
          .toList();
      if (candidates.isEmpty) return original(RenderOutcome.noRule);

      final publishable = candidates.where(isPublishable).toList();
      if (publishable.isEmpty) return original(RenderOutcome.ruleNotPublishable);
      if (publishable.map((r) => r.id).toSet().length > 1) return original(RenderOutcome.ruleConflict);
      publishable.sort((a, b) => b.ruleVersion.compareTo(a.ruleVersion));
      final rule = publishable.first;

      if (name.status == NameStatus.insertionOff) return original(RenderOutcome.nameInsertionOff, rule.id);
      if (!name.canInsert) return original(RenderOutcome.nameUnavailable, rule.id);

      final report = validator.validate(rule, canonicalText: source.text, style: ruleset.style, context: context);
      if (!report.passed) return original(RenderOutcome.validationFailed, rule.id);

      final located = EditEngine.locate(rule.edits, source.text);
      if (!located.ok) return original(RenderOutcome.validationFailed, rule.id);
      final segments = EditEngine.apply(source.text, located.edits, name.name!, ruleId: rule.id);
      if (segments.map((s) => s.original).join() != source.text) {
        return original(RenderOutcome.validationFailed, rule.id);
      }
      return RenderedVerse(
        source: source,
        sourceVersionId: sourceVersionId,
        targetVersionId: targetVersionId,
        segments: segments,
        outcome: RenderOutcome.personalised,
        ruleId: rule.id,
        isPreview: rule.validApproval == null,
      );
    } catch (_) {
      return original(RenderOutcome.renderError);
    }
  }
}
