import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/errors/app_failure.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart';
import 'package:my_word_bible/data/repositories/mwb_ruleset_repository.dart';
import 'package:my_word_bible/data/repositories/theological_review_repository.dart';
import 'package:my_word_bible/features/personalisation/domain/edit_engine.dart';
import 'package:my_word_bible/features/personalisation/domain/personal_name.dart';
import 'package:my_word_bible/features/personalisation/domain/personalisation_validator.dart';
import 'package:my_word_bible/features/personalisation/domain/review_queue.dart';
import 'package:my_word_bible/features/personalisation/domain/ruleset_processor.dart';

import '../helpers/test_app.dart';
import 'mwb_test_support.dart';

final v = PersonalisationValidator(catalogue);

Future<ValidationReport> check(MwbRule rule) async => v.validate(
  rule,
  canonicalText: (await sharedTestBible.passage('KJV', rule.reference)).verses.single.text,
  style: shippedRuleset().style,
);

void main() {
  group('Shipped KJV-MWB rules', () {
    late List<ProcessedRule> queue;
    setUpAll(() async => queue = await reviewService().queue('KJV-MWB'));
    ProcessedRule item(String id) => queue.singleWhere((p) => p.rule.id == id);

    test('all load, every source text is the exact canonical KJV verse', () {
      expect(shippedRuleset().loadIssues, isEmpty);
      expect(queue, hasLength(21));
      for (final p in queue) {
        expect(p.canonicalText, p.rule.sourceText, reason: p.rule.id);
        expect(p.rule.sourceVersionId, 'KJV');
        expect(p.rule.targetVersionId, 'KJV-MWB');
      }
    });

    test('every renderable rule rebuilds its source exactly', () async {
      for (final p in queue.where((p) => p.report.passed)) {
        final located = EditEngine.locate(p.rule.edits, p.canonicalText!);
        final segments = EditEngine.apply(p.canonicalText!, located.edits, 'Emmanuel Nkwoka', ruleId: p.rule.id);
        expect(segments.map((s) => s.original).join(), p.canonicalText, reason: p.rule.id);
      }
    });

    test('nothing is approved; designation of the supervisor is not an approval', () {
      final ruleset = shippedRuleset();
      expect(ruleset.supervisor!.name, 'Pastor Obi Ogbo');
      expect(queue.where((p) => p.status == RuleStatus.approved), isEmpty);
      for (final p in queue) {
        expect(p.rule.validApproval, isNull, reason: p.rule.id);
        expect(p.rule.reviews.where((r) => (r.reviewer ?? '').contains('Obi')), isEmpty, reason: p.rule.id);
      }
    });

    test('the "My son" rules pass automated validation and keep "My son" unchanged', () {
      final sons = queue.where((p) => p.rule.edits.single.anchor == 'My son,').toList();
      expect(sons, hasLength(17));
      for (final p in sons) {
        expect(p.report.passed, isTrue, reason: '${p.rule.id}: ${p.report.issues}');
        expect(p.status, RuleStatus.automatedValidated);
        expect(p.previewText, startsWith('My son, [Name], '));
      }
      expect(item('kjv-mwb.PRO.23.15.a').risk, RiskLevel.low);
    });

    test('Proverbs 23:18: the historical wording is rejected for vocabulary; the KJV-faithful candidate passes', () {
      final old = item('kjv-mwb.PRO.23.18.a');
      expect(old.status, RuleStatus.rejected);
      expect(old.rule.rejectionReason, contains('KJV'));
      expect(old.report.has(ValidationCode.foreignVocabulary), isTrue);
      expect(old.report.has(ValidationCode.excessiveChange), isTrue);

      final candidate = item('kjv-mwb.PRO.23.18.b');
      expect(candidate.report.passed, isTrue, reason: '${candidate.report.issues}');
      expect(candidate.previewText, 'For surely there is an end; and, [Name], thine expectation shall not be cut off.');
      expect(candidate.risk, RiskLevel.high);
      expect(candidate.context!.isConditionalPromise, isTrue);
      expect(candidate.rule.reviewQuestion, isNotEmpty);
    });

    test('risk follows context: divine speech is critical, specific addressees and conditions are high', () {
      expect(item('kjv-mwb.ISA.41.10.a').risk, RiskLevel.critical);
      expect(item('kjv-mwb.ISA.41.10.a').report.risk.reasons.join(), contains('divine'));
      expect(item('kjv-mwb.3JN.1.2.a').risk, RiskLevel.high);
      expect(item('kjv-mwb.PRO.2.1.a').risk, RiskLevel.high);
      expect(item('kjv-mwb.PRO.1.8.a').risk, RiskLevel.medium);
      // Representative "my son" address is not escalated just for being gendered.
      expect(item('kjv-mwb.PRO.4.20.a').risk, RiskLevel.low);
      expect(queue.where((p) => p.report.has(ValidationCode.riskUnderstated)), isEmpty);
    });

    test('the queue lists open items first, highest risk first', () {
      final open = queue.takeWhile((p) => !p.status.isClosed).toList();
      expect(open.first.risk, RiskLevel.critical);
      expect(queue.last.status, RuleStatus.rejected);
      for (var i = 1; i < open.length; i++) {
        expect(open[i - 1].risk.index >= open[i].risk.index, isTrue);
      }
    });
  });

  group('Validator safeguards', () {
    test('gendered terms may not be swapped ("son" never becomes "daughter")', () async {
      final text = await kjv('PRO 3:1');
      final r = await check(
        makeRule(
          id: 'swap',
          reference: 'PRO 3:1',
          sourceText: text,
          edits: const [
            RuleEdit(
              operation: PersonalisationOperation.approvedMinimalGrammaticalAdjustment,
              anchor: 'My son,',
              position: EditPosition.replace,
              text: 'My daughter, {name},',
            ),
          ],
        ),
      );
      expect(r.has(ValidationCode.genderedTermChanged), isTrue);
      expect(r.passed, isFalse);
    });

    test('only {name} may be used; there is no gender or pronoun placeholder', () async {
      final text = await kjv('PRO 3:1');
      final r = await check(
        makeRule(id: 'p', reference: 'PRO 3:1', sourceText: text, edits: [nameAfter('My son,', ' {name}, {pronoun},')]),
      );
      expect(r.has(ValidationCode.unknownPlaceholder), isTrue);
    });

    test('name insertions cannot add words', () async {
      final text = await kjv('PRO 3:1');
      final r = await check(
        makeRule(id: 'w', reference: 'PRO 3:1', sourceText: text, edits: [nameAfter('My son,', ' beloved {name},')]),
      );
      expect(r.has(ValidationCode.insertionAddsWords), isTrue);
    });

    test('broken punctuation is caught, but pre-existing source quirks are tolerated', () async {
      final text = await kjv('PRO 3:11'); // canonical text contains "the LORD ;"
      expect(text, contains('LORD ;'));
      final bad = await check(
        makeRule(id: 'b', reference: 'PRO 3:11', sourceText: text, edits: [nameAfter('My son,', ' {name},,')]),
      );
      expect(bad.has(ValidationCode.punctuationDefect), isTrue);
      final good = await check(
        makeRule(id: 'g', reference: 'PRO 3:11', sourceText: text, edits: [nameAfter('My son,')]),
      );
      expect(good.passed, isTrue, reason: '${good.issues}');
    });

    test('ambiguous anchors must say which occurrence', () async {
      final text = await kjv('ISA 41:10'); // "I will" occurs three times
      final r = await check(
        makeRule(
          id: 'amb',
          reference: 'ISA 41:10',
          sourceText: text,
          edits: const [
            RuleEdit(
              operation: PersonalisationOperation.insertDirectAddress,
              anchor: 'I will',
              position: EditPosition.before,
              text: '{name}, ',
            ),
          ],
        ),
      );
      expect(r.has(ValidationCode.anchorAmbiguous), isTrue);
    });

    test('punctuation adjustments may change punctuation only', () async {
      final text = await kjv('PRO 4:20');
      final r = await check(
        makeRule(
          id: 'pa',
          reference: 'PRO 4:20',
          sourceText: text,
          edits: const [
            RuleEdit(
              operation: PersonalisationOperation.punctuationAdjustment,
              anchor: 'words;',
              position: EditPosition.replace,
              text: 'sayings;',
            ),
          ],
        ),
      );
      expect(r.has(ValidationCode.punctuationOnlyViolated), isTrue);
    });

    test('a rule must name an MWB edition derived from its own source', () async {
      final text = await kjv('PRO 3:1');
      final wrongTarget = await check(
        makeRule(
          id: 't',
          reference: 'PRO 3:1',
          sourceText: text,
          edits: [nameAfter('My son,')],
          targetVersionId: 'NIV-MWB',
        ),
      );
      expect(wrongTarget.has(ValidationCode.versionMismatch), isTrue);
      final original = await check(
        makeRule(
          id: 'o',
          reference: 'PRO 3:1',
          sourceText: text,
          edits: [nameAfter('My son,')],
          targetVersionId: 'KJV',
        ),
      );
      expect(original.has(ValidationCode.versionMismatch), isTrue);
    });
  });

  group('Skip, flag and continue', () {
    test('a malformed rule and a broken rule do not stop unrelated rules', () async {
      final doc = jsonDecode(rulesetRaw) as Map<String, dynamic>;
      final rules = (doc['rules'] as List).cast<Map<String, dynamic>>();
      final good = rules.firstWhere((r) => r['id'] == 'kjv-mwb.PRO.4.20.a');
      final broken = {...good, 'id': 'broken', 'reference': 'PRO 5:1'}; // wrong source text for 5:1
      doc['rules'] = [
        {'id': 'malformed'},
        broken,
        good,
      ];
      final raw = jsonEncode(doc);
      expect(parseMwbRuleset(raw).loadIssues.single, contains('malformed'));

      final queue = await reviewService(rulesetJson: raw).queue('KJV-MWB');
      expect(queue, hasLength(2));
      final b = queue.singleWhere((p) => p.rule.id == 'broken');
      expect(b.report.has(ValidationCode.sourceTextMismatch), isTrue);
      expect(b.status, RuleStatus.proposed);
      expect(queue.singleWhere((p) => p.rule.id == good['id']).status, RuleStatus.automatedValidated);
    });

    test('a rule whose verse lookup throws is flagged and others continue', () async {
      final processor = MwbRulesetProcessor(v);
      final rs = shippedRuleset();
      final out = await processor.process(
        rs,
        canonicalText: (verse) async {
          if (verse.chapter == 23 && verse.verseStart == 15) throw StateError('disk error');
          return (await sharedTestBible.passage('KJV', verse)).verses.single.text;
        },
        contextFor: contextRepo().contextFor,
      );
      expect(out, hasLength(rs.rules.length));
      expect(
        out.singleWhere((p) => p.rule.id == 'kjv-mwb.PRO.23.15.a').report.has(ValidationCode.processingFailed),
        isTrue,
      );
      expect(out.where((p) => p.status == RuleStatus.automatedValidated).length, greaterThan(15));
    });
  });

  group('Theological review decisions', () {
    test('approval needs a named reviewer and a rule that passes validation', () async {
      final service = reviewService();
      final at = DateTime(2026, 11, 11);
      await expectLater(
        service.recordDecision('KJV-MWB', 'kjv-mwb.PRO.23.15.a', ReviewDecision(action: ReviewAction.approved, at: at)),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        service.recordDecision(
          'KJV-MWB',
          'kjv-mwb.PRO.23.18.a',
          ReviewDecision(action: ReviewAction.approved, at: at, reviewer: 'Test Reviewer'),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        service.recordDecision('KJV-MWB', 'kjv-mwb.PRO.3.1.a', ReviewDecision(action: ReviewAction.rejected, at: at)),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        service.recordDecision('KJV-MWB', 'nope', ReviewDecision(action: ReviewAction.submitted, at: at)),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('recorded decisions persist across restarts and drive rendering', () async {
      final store = InMemoryKeyValueStore();
      await reviewService(store: store).recordDecision(
        'KJV-MWB',
        'kjv-mwb.PRO.4.20.a',
        ReviewDecision(action: ReviewAction.approved, at: DateTime(2026, 11, 11), reviewer: 'Test Reviewer'),
      );
      await reviewService(store: store).recordDecision(
        'KJV-MWB',
        'kjv-mwb.PRO.3.1.a',
        ReviewDecision(action: ReviewAction.submitted, at: DateTime(2026, 11, 11), comments: 'Please review'),
      );

      // A fresh service over the same store (an app restart).
      final restarted = reviewService(store: store);
      expect(LocalTheologicalReviewRepository(store).decisionsFor('kjv-mwb.PRO.4.20.a'), hasLength(1));
      final queue = await restarted.queue('KJV-MWB');
      expect(queue.singleWhere((p) => p.rule.id == 'kjv-mwb.PRO.4.20.a').status, RuleStatus.approved);
      expect(queue.singleWhere((p) => p.rule.id == 'kjv-mwb.PRO.3.1.a').status, RuleStatus.underReview);

      final ruleset = await restarted.effectiveRuleset('KJV-MWB');
      final verse = (await sharedTestBible.passage('KJV', ref('PRO 4:20'))).verses.single;
      final r = renderer().render(
        source: verse,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: ruleset,
        name: PersonalNameResolver.resolve(emmanuel),
        context: await contextRepo().contextFor(verse.reference),
      );
      expect(r.text, 'My son, Emmanuel Nkwoka, attend to my words; incline thine ear unto my sayings.');
      // Under-review rules still do not render in production.
      final pending = (await sharedTestBible.passage('KJV', ref('PRO 3:1'))).verses.single;
      expect(
        renderer()
            .render(
              source: pending,
              sourceVersionId: 'KJV',
              targetVersionId: 'KJV-MWB',
              ruleset: ruleset,
              name: PersonalNameResolver.resolve(emmanuel),
            )
            .isPersonalised,
        isFalse,
      );
    });

    test('corrupt stored decisions are ignored rather than invented', () async {
      final store = InMemoryKeyValueStore({
        LocalTheologicalReviewRepository.storageKey: '{"kjv-mwb.PRO.3.1.a":[{"x":1}]}',
      });
      final queue = await reviewService(store: store).queue('KJV-MWB');
      expect(queue.singleWhere((p) => p.rule.id == 'kjv-mwb.PRO.3.1.a').status, RuleStatus.automatedValidated);
    });
  });

  test('review queue document for the theological supervisor is up to date', () async {
    final queue = await reviewService().queue('KJV-MWB');
    final markdown = ReviewQueueExporter.toMarkdown(shippedRuleset(), queue);
    final file = File('docs/mwb/kjv-mwb-review-queue.md');
    if (Platform.environment['UPDATE_REVIEW_QUEUE'] == '1' || !file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(markdown);
    }
    expect(
      file.readAsStringSync(),
      markdown,
      reason: 'Regenerate with: UPDATE_REVIEW_QUEUE=1 flutter test test/mwb/validation_and_review_test.dart',
    );
    expect(markdown, contains('Pastor Obi Ogbo'));
    expect(markdown, contains('[Name]'));
  });
}
