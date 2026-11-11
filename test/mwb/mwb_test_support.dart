import 'dart:io';

import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/catalogue/version_catalogue.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/models/user_profile.dart';
import 'package:my_word_bible/data/repositories/mwb_ruleset_repository.dart';
import 'package:my_word_bible/data/repositories/passage_context_repository.dart';
import 'package:my_word_bible/data/repositories/theological_review_repository.dart';
import 'package:my_word_bible/features/personalisation/domain/mwb_renderer.dart';
import 'package:my_word_bible/features/personalisation/domain/personalisation_validator.dart';
import 'package:my_word_bible/features/personalisation/domain/review_queue.dart';
import 'package:my_word_bible/features/personalisation/domain/ruleset_processor.dart';

import '../helpers/test_app.dart';

final catalogue = VersionCatalogue(bibleVersionCatalogue);

final rulesetRaw = File('assets/mwb/rulesets/kjv-mwb.json').readAsStringSync();
final contextRaw = File('assets/mwb/passage_context.json').readAsStringSync();

MwbRuleset shippedRuleset() => parseMwbRuleset(rulesetRaw);

AssetMwbRulesetRepository rulesetRepo([String? raw]) =>
    AssetMwbRulesetRepository(loader: (_) async => raw ?? rulesetRaw);
AssetPassageContextRepository contextRepo() => AssetPassageContextRepository(loader: (_) async => contextRaw);

MwbRenderer renderer([PublicationPolicy policy = PublicationPolicy.approvedOnly]) =>
    MwbRenderer(catalogue: catalogue, validator: PersonalisationValidator(catalogue), policy: policy);

ReviewQueueService reviewService({KeyValueStore? store, String? rulesetJson}) => ReviewQueueService(
  rulesets: rulesetRepo(rulesetJson),
  bible: sharedTestBible,
  contexts: contextRepo(),
  reviews: LocalTheologicalReviewRepository(store ?? InMemoryKeyValueStore()),
  processor: MwbRulesetProcessor(PersonalisationValidator(catalogue)),
);

ScriptureReference ref(String s) => ScriptureReference.parseCompact(s);

Future<String> kjv(String reference) async => (await sharedTestBible.passage('KJV', ref(reference))).verses.single.text;

const emmanuel = UserProfile(firstName: 'Emmanuel', lastName: 'Nkwoka', gender: GenderPreference.male);

/// A real, current approval recorded for a test (never in shipped data).
ReviewRecord testApproval({int ruleVersion = 1, String? reviewer = 'Test Reviewer'}) => ReviewRecord(
  action: ReviewAction.approved,
  at: DateTime(2026, 11, 11),
  ruleVersion: ruleVersion,
  reviewer: reviewer,
  reviewerRole: 'Test',
);

/// The shipped rule with [id], optionally with extra review records.
MwbRule shippedRule(String id, [List<ReviewRecord> extra = const []]) =>
    shippedRuleset().rules.singleWhere((r) => r.id == id).withReviews(extra);

/// A ruleset containing only [rules], using the shipped style and ids.
MwbRuleset rulesetOf(List<MwbRule> rules) {
  final base = shippedRuleset();
  return MwbRuleset(
    sourceVersionId: base.sourceVersionId,
    targetVersionId: base.targetVersionId,
    rulesetVersion: base.rulesetVersion,
    style: base.style,
    rules: rules,
    supervisor: base.supervisor,
  );
}

/// Builds a rule against real KJV text for negative tests.
MwbRule makeRule({
  required String id,
  required String reference,
  required String sourceText,
  required List<RuleEdit> edits,
  String sourceVersionId = 'KJV',
  String targetVersionId = 'KJV-MWB',
  RuleStatus status = RuleStatus.proposed,
  RiskLevel risk = RiskLevel.low,
  List<ReviewRecord> reviews = const [],
}) => MwbRule(
  id: id,
  ruleVersion: 1,
  sourceVersionId: sourceVersionId,
  targetVersionId: targetVersionId,
  reference: ref(reference),
  sourceText: sourceText,
  edits: edits,
  declaredRisk: risk,
  status: status,
  reviews: reviews,
);

RuleEdit nameAfter(String anchor, [String text = ' {name},']) => RuleEdit(
  operation: PersonalisationOperation.insertNameAfterExistingAddress,
  anchor: anchor,
  position: EditPosition.after,
  text: text,
);
