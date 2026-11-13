import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart';
import 'package:my_word_bible/data/models/personalisation_catalogue.dart';
import 'package:my_word_bible/data/models/user_profile.dart';
import 'package:my_word_bible/data/repositories/mwb_ruleset_repository.dart';
import 'package:my_word_bible/data/repositories/theological_review_repository.dart';
import 'package:my_word_bible/features/personalisation/domain/edit_engine.dart';
import 'package:my_word_bible/features/personalisation/domain/personal_name.dart';
import 'package:my_word_bible/features/personalisation/domain/personalisation_validator.dart';
import 'package:my_word_bible/features/personalisation/domain/rendered_verse.dart';
import 'package:my_word_bible/features/personalisation/domain/review_queue.dart';
import 'package:my_word_bible/features/personalisation/domain/ruleset_processor.dart';

import '../helpers/test_app.dart';
import 'mwb_test_support.dart';

final _catalogues = AssetPersonalisationCatalogueRepository(loader: (p) async => File(p).readAsStringSync());

MwbRule _rule(String reference, String source, List<RuleEdit> edits) => MwbRule(
  id: 'test.$reference',
  ruleVersion: 1,
  sourceVersionId: 'KJV',
  targetVersionId: 'KJV-MWB',
  reference: ref(reference),
  sourceText: source,
  edits: edits,
  declaredRisk: RiskLevel.critical,
  status: RuleStatus.proposed,
);

RuleEdit _replace(String anchor, String text) => RuleEdit(
  operation: PersonalisationOperation.approvedMinimalGrammaticalAdjustment,
  anchor: anchor,
  position: EditPosition.replace,
  text: text,
);

ValidationReport _validate(MwbRule rule, String canonical) =>
    PersonalisationValidator(catalogue).validate(rule, canonicalText: canonical, style: shippedRuleset().style);

void main() {
  late PersonalisationCatalogue kjvCat;
  late PersonalisationCatalogue webCat;
  setUpAll(() async {
    kjvCat = await _catalogues.catalogue('KJV-MWB');
    webCat = await _catalogues.catalogue('WEB-MWB');
  });

  group('Complete catalogue', () {
    test('every canonical verse of both translations is classified', () async {
      for (final (cat, id) in [(kjvCat, 'KJV'), (webCat, 'WEB')]) {
        expect(cat.books, hasLength(66), reason: id);
        var verses = 0;
        for (final b in cat.books) {
          final chapters = (await sharedTestBible.books(id)).singleWhere((x) => x.id == b.id).chapterCount;
          expect(b.chapters, hasLength(chapters), reason: '$id ${b.id}');
          for (var c = 1; c <= chapters; c++) {
            final canon = await sharedTestBible.chapter(id, b.id, c);
            expect(b.chapters[c - 1], hasLength(canon.length), reason: '$id ${b.id} $c');
            verses += canon.length;
          }
        }
        expect(cat.verseCount, verses, reason: id);
      }
      expect(kjvCat.verseCount, 31102);
      expect(webCat.verseCount, 31103);
    });

    test('nothing in the catalogue is approved or carries a review', () {
      for (final p in [...kjvCat.proposals, ...webCat.proposals]) {
        expect(p.status, RuleStatus.proposed, reason: p.id);
        expect(p.reviews, isEmpty, reason: p.id);
        expect(p.validApproval, isNull, reason: p.id);
        expect(p.meta.isGenerated, isTrue, reason: p.id);
      }
    });

    test('every generated proposal is written against the exact canonical text', () async {
      for (final (cat, id) in [(kjvCat, 'KJV'), (webCat, 'WEB')]) {
        for (final p in cat.proposals) {
          final canon = (await sharedTestBible.passage(id, p.reference)).verses.single.text;
          expect(p.sourceText, canon, reason: p.id);
        }
      }
    });

    test('Mode A proposals only insert the name: no source word changes and the source is recoverable', () async {
      for (final (cat, id) in [(kjvCat, 'KJV'), (webCat, 'WEB')]) {
        final style = id == 'KJV' ? shippedRuleset().style : shippedWebRuleset().style;
        for (final p in cat.proposals.where((p) => p.presentationMode == PresentationMode.nameInText)) {
          expect(p.edits.every((e) => e.operation.insertsName), isTrue, reason: p.id);
          final report = PersonalisationValidator(catalogue).validate(p, canonicalText: p.sourceText, style: style);
          expect(report.passed, isTrue, reason: '${p.id}: ${report.issues}');
          final located = EditEngine.locate(p.edits, p.sourceText);
          final segs = EditEngine.apply(p.sourceText, located.edits, 'Ada Obi', ruleId: p.id);
          expect(segs.map((s) => s.original).join(), p.sourceText, reason: p.id);
          final rendered = segs.map((s) => s.text).join();
          expect(rendered.replaceFirst(', Ada Obi', '').replaceFirst(' Ada Obi,', ''), p.sourceText, reason: p.id);
        }
      }
    });

    test('Mode B proposals never touch Scripture and titles never speak in the first person', () {
      for (final p in [...kjvCat.proposals, ...webCat.proposals].where(
        (p) => p.presentationMode == PresentationMode.nameInTitle,
      )) {
        expect(p.edits, isEmpty, reason: p.id);
        final t = p.titleTemplate;
        if (t != null) {
          expect('{name}'.allMatches(t), hasLength(1), reason: p.id);
          expect(RegExp(r'\b(I|me|my|mine|My|Me|Mine)\b').hasMatch(t.replaceAll('{name}', '')), isFalse, reason: p.id);
        }
      }
    });

    test('no generated insertion carries a gendered word', () {
      const gendered = {'he', 'him', 'his', 'she', 'her', 'son', 'daughter', 'man', 'woman', 'brother', 'sister'};
      for (final p in [...kjvCat.proposals, ...webCat.proposals]) {
        for (final e in p.edits) {
          final words = PersonalisationValidator.words(e.text.replaceAll('{name}', ''));
          expect(words.where(gendered.contains), isEmpty, reason: p.id);
        }
      }
    });
  });

  group('Regression: historical defects', () {
    test('Ephesians 2:10 — collective "we" is never replaced by a name', () async {
      final source = await kjv('EPH 2:10');
      expect(kjvCat.classify('EPH', 2, 10)!.verseClass, isNot(VerseClass.nameInText));
      expect(kjvCat.proposals.where((p) => p.reference == ref('EPH 2:10') && p.edits.isNotEmpty), isEmpty);

      // A. The demo rendering.
      final demo = _validate(
        _rule('EPH 2:10', source, [
          _replace('For we are his workmanship', 'For {name} is his workmanship'),
          _replace('that we should walk', 'that he should walk'),
        ]),
        source,
      );
      expect(demo.passed, isFalse);
      expect(demo.has(ValidationCode.pronounReplaced), isTrue);
      expect(demo.has(ValidationCode.genderedTermChanged), isTrue);

      // D. Subject only: "For {name} are his workmanship … that we should walk".
      final d = _validate(_rule('EPH 2:10', source, [_replace('For we are', 'For {name} are')]), source);
      expect(d.passed, isFalse);
      expect(d.has(ValidationCode.pronounReplaced), isTrue);
      expect(d.has(ValidationCode.residualPronoun), isTrue);
      expect(d.has(ValidationCode.verbAgreement), isTrue);
    });

    test('Isaiah 43:1 — divine speech to Israel is held for review; the demo rendering fails', () async {
      final source = await kjv('ISA 43:1');
      final c = kjvCat.classify('ISA', 43, 1)!;
      expect(c.verseClass, VerseClass.contextualReview);
      expect(c.reason.code, 'divineSpeechCollective');
      expect(kjvCat.proposals.where((p) => p.reference == ref('ISA 43:1')), isEmpty);
      final demo = _validate(
        _rule('ISA 43:1', source, [_replace('I have called thee by thy name', 'I have called {name} by name')]),
        source,
      );
      expect(demo.passed, isFalse);
      expect(demo.has(ValidationCode.pronounReplaced), isTrue);
      expect(demo.has(ValidationCode.residualPronoun), isTrue); // "thou art mine" remains
    });

    test('John 11:25 — narrative words to Martha are excluded; lower-casing "Jesus" is caught', () async {
      final source = await kjv('JHN 11:25');
      final c = kjvCat.classify('JHN', 11, 25)!;
      expect(c.verseClass, VerseClass.excluded);
      final demo = _validate(_rule('JHN 11:25', source, [_replace('Jesus said', '{name}, jesus said')]), source);
      expect(demo.passed, isFalse);
      expect(demo.has(ValidationCode.capitalisationChanged), isTrue);
    });

    test('collective promises are never turned into individual guarantees (Romans 8:37, Romans 15:13)', () async {
      for (final r in ['ROM 8:37', 'ROM 15:13', 'PHP 4:19', '2CO 5:17']) {
        final p = ref(r);
        expect(kjvCat.classify(p.bookId, p.chapter, p.verseStart!)!.verseClass, isNot(VerseClass.nameInText), reason: r);
      }
      final source = await kjv('ROM 8:37');
      final demo = _validate(
        _rule('ROM 8:37', source, [_replace('we are more than conquerors', '{name} is more than a conqueror')]),
        source,
      );
      expect(demo.passed, isFalse);
      expect(demo.has(ValidationCode.pronounReplaced), isTrue);

      // Founder references for Romans 15:13 are recorded and fail for the stated reasons.
      final queue = await reviewService().queue('KJV-MWB');
      final a = queue.singleWhere((p) => p.rule.id == 'kjv-mwb.ROM.15.13.founder-a');
      expect(a.report.has(ValidationCode.pronounReplaced), isTrue);
      expect(a.report.has(ValidationCode.residualPronoun), isTrue);
      final b = queue.singleWhere((p) => p.rule.id == 'kjv-mwb.ROM.15.13.founder-b');
      expect(b.report.has(ValidationCode.titleModeEditsScripture), isTrue);
      expect(b.report.has(ValidationCode.capitalisationChanged), isTrue);
      final ok = queue.singleWhere((p) => p.rule.id == 'kjv-mwb.ROM.15.13.b');
      expect(ok.report.passed, isTrue, reason: '${ok.report.issues}');
      expect(ok.status, RuleStatus.automatedValidated);
    });

    test('first-person Psalms keep the psalmist as speaker (Psalm 23:1, 139:14)', () async {
      for (final r in ['PSA 23:1', 'PSA 139:14', 'PSA 23:4', 'PSA 119:105']) {
        final p = ref(r);
        expect(kjvCat.classify(p.bookId, p.chapter, p.verseStart!)!.verseClass, isNot(VerseClass.nameInText), reason: r);
      }
      final source = await kjv('PSA 139:14');
      final demo = _validate(_rule('PSA 139:14', source, [_replace('I will praise thee', '{name} will praise thee')]), source);
      expect(demo.passed, isFalse);
      expect(demo.has(ValidationCode.pronounReplaced), isTrue);
      expect(demo.has(ValidationCode.residualPronoun), isTrue); // "I am fearfully…", "my soul"
    });

    test('psalms addressed to God, the king or Zion are not proposed for name insertion', () {
      for (final r in ['PSA 5:4', 'PSA 8:4', 'PSA 45:2', 'PSA 137:9', 'PSA 147:12', 'PSA 147:13', 'PSA 87:3']) {
        final p = ref(r);
        expect(kjvCat.classify(p.bookId, p.chapter, p.verseStart!)!.verseClass, isNot(VerseClass.nameInText), reason: r);
      }
    });

    test('historical narrative is never addressed to the reader (Genesis 22:2, 1:1)', () {
      expect(kjvCat.classify('GEN', 22, 2)!.verseClass, VerseClass.excluded);
      expect(kjvCat.classify('GEN', 22, 2)!.reason.code, 'narrativeDialogue');
      expect(kjvCat.classify('GEN', 1, 1)!.verseClass, VerseClass.originalOnly);
    });

    test('pronoun and verb agreement: a name followed by a plural verb is an error', () async {
      final source = await kjv('ROM 8:37');
      final r = _validate(_rule('ROM 8:37', source, [_replace('we are', '{name} are')]), source);
      expect(r.has(ValidationCode.verbAgreement), isTrue);
    });

    test('proper-name capitalisation: names are inserted exactly as chosen, lower-case input is capitalised', () {
      expect(PersonalNameResolver.properCase('emmanuel nkwoka'), 'Emmanuel Nkwoka');
      expect(PersonalNameResolver.properCase('McDonald'), 'McDonald');
      expect(PersonalNameResolver.properCase('de la Cruz'), 'de la Cruz');
      const lower = UserProfile(firstName: 'ada', lastName: 'obi', gender: GenderPreference.female);
      expect(PersonalNameResolver.resolve(lower).name, 'Ada Obi');
      expect(PersonalNameResolver.resolveTitle(lower).name, 'Ada');
      expect(PersonalNameResolver.resolveTitle(emmanuel.copyWith(namePreference: NamePreference.none)).canInsert, isFalse);
    });

    test('generated insertions never sit next to quoted speech', () {
      for (final p in kjvCat.proposals.where((p) => p.presentationMode == PresentationMode.nameInText)) {
        final rendered = EditEngine.apply(
          p.sourceText,
          EditEngine.locate(p.edits, p.sourceText).edits,
          'NAME',
          ruleId: p.id,
        ).map((s) => s.text).join();
        expect(RegExp(r'NAME[,:] [A-Z]').hasMatch(rendered.replaceAll('NAME, and', '')), isFalse, reason: rendered);
      }
    });
  });

  group('Presentation modes and review workflow', () {
    test('an approved Mode B rule shows the original text with a first-name title', () async {
      final queue = await reviewService().queue('KJV-MWB');
      final rule = queue.singleWhere((p) => p.rule.id == 'kjv-mwb.ROM.15.13.b').rule.withReviews([testApproval()]);
      final ruleset = MwbRuleset(
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        rulesetVersion: 1,
        style: shippedRuleset().style,
        rules: [rule],
      );
      final verse = (await sharedTestBible.passage('KJV', ref('ROM 15:13'))).verses.single;
      final out = renderer().render(
        source: verse,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: ruleset,
        name: PersonalNameResolver.resolve(emmanuel),
        titleName: PersonalNameResolver.resolveTitle(emmanuel),
      );
      expect(out.outcome, RenderOutcome.titled);
      expect(out.text, verse.text);
      expect(out.title, 'Emmanuel, abound in hope');
      expect(out.isPreview, isFalse);
    });

    test('a correction creates a new version that is not publishable until approved', () async {
      final store = InMemoryKeyValueStore();
      final service = reviewService(store: store);
      final at = DateTime(2026, 11, 12);
      const id = 'kjv-mwb.PRO.3.1.a';
      final source = await kjv('PRO 3:1');
      final corrected = source.replaceFirst('My son,', 'My son, {name},').replaceFirst('law;', 'law,');
      await service.recordDecision(
        'KJV-MWB',
        id,
        ReviewDecision(action: ReviewAction.corrected, at: at, reviewer: 'Test Reviewer', correctedText: corrected),
      );
      var p = (await service.queue('KJV-MWB')).singleWhere((x) => x.rule.id == id);
      expect(p.rule.ruleVersion, 2);
      expect(p.status, RuleStatus.corrected);
      expect(p.rule.validApproval, isNull);
      // Canonical text is untouched; only the rule changed.
      expect(p.rule.sourceText, source);

      await service.recordDecision(
        'KJV-MWB',
        id,
        ReviewDecision(action: ReviewAction.approved, at: at, reviewer: 'Test Reviewer'),
      );
      p = (await service.queue('KJV-MWB')).singleWhere((x) => x.rule.id == id);
      expect(p.status, RuleStatus.approved);
      expect(p.rule.validApproval!.ruleVersion, 2);

      // Reopening needs a reason and returns it to review; unrelated rules are untouched.
      expect(
        () => service.recordDecision('KJV-MWB', id, ReviewDecision(action: ReviewAction.reopened, at: at, reviewer: 'X')),
        throwsA(isA<Object>()),
      );
      await service.recordDecision(
        'KJV-MWB',
        id,
        ReviewDecision(action: ReviewAction.reopened, at: at, reviewer: 'Test Reviewer', comments: 'Recheck'),
      );
      final q = await service.queue('KJV-MWB');
      expect(q.singleWhere((x) => x.rule.id == id).status, RuleStatus.underReview);
      expect(q.where((x) => x.status == RuleStatus.approved), isEmpty);
      expect(LocalTheologicalReviewRepository(store).decisionsFor('kjv-mwb.PRO.1.10.a'), isEmpty);
    });

    test('a flag needs a reason and keeps the proposal unpublished', () async {
      final service = reviewService();
      final at = DateTime(2026, 11, 12);
      expect(
        () => service.recordDecision('KJV-MWB', 'kjv-mwb.PRO.1.10.a', ReviewDecision(action: ReviewAction.flagged, at: at)),
        throwsA(isA<Object>()),
      );
      await service.recordDecision(
        'KJV-MWB',
        'kjv-mwb.PRO.1.10.a',
        ReviewDecision(action: ReviewAction.flagged, at: at, comments: 'Unsure about the audience'),
      );
      final p = (await service.queue('KJV-MWB')).singleWhere((x) => x.rule.id == 'kjv-mwb.PRO.1.10.a');
      expect(p.status, RuleStatus.underReview);
      expect(p.rule.validApproval, isNull);
    });

    test('generated proposals reach the review queue; hand-authored rules win on their verses', () async {
      final service = ReviewQueueService(
        rulesets: AssetMwbRulesetRepository(loader: (p) async => File(p).readAsStringSync(), catalogue: _catalogues),
        bible: sharedTestBible,
        contexts: contextRepo(),
        reviews: LocalTheologicalReviewRepository(InMemoryKeyValueStore()),
        processor: MwbRulesetProcessor(PersonalisationValidator(catalogue)),
      );
      final queue = await service.queue('KJV-MWB');
      expect(queue.length, 24 + kjvCat.proposals.length);
      expect(queue.where((p) => p.rule.reference == ref('PRO 3:1')), hasLength(1));
      expect(queue.where((p) => p.status == RuleStatus.approved), isEmpty);
    });
  });
}
