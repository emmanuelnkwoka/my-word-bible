import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/data/repositories/intelligence_repository.dart';
import 'package:my_word_bible/features/intelligence/domain/intelligence_validator.dart';

import 'intel_test_support.dart';

/// Each test breaks the shipped corpus in one way and checks that the
/// validator names the exact record and problem.
void main() {
  Future<IntelValidationReport> check(String file, void Function(Map<String, dynamic>) edit) =>
      validateRaw(mutated(file, edit));

  void expectIssue(IntelValidationReport r, IntelIssueCode code, String id, [String? text]) {
    final hits = r.issues.where((i) => i.code == code && i.objectId == id && i.isError).toList();
    expect(hits, isNotEmpty, reason: 'expected ${code.name} on $id; got:\n${r.issues.join('\n')}');
    if (text != null) expect(hits.map((h) => h.message).join(' '), contains(text));
  }

  group('1. References resolve', () {
    test('a verse beyond the chapter', () async {
      final r = await check(
        'promises.json',
        (j) => recordIn(j, 'promises', 'pr-peace-1')['references'] = ['ISA 26:99'],
      );
      expectIssue(r, IntelIssueCode.unresolvedReference, 'pr-peace-1', 'ISA 26:99');
    });
    test('an unknown book', () async {
      final r = await check(
        'prayers.json',
        (j) => recordIn(j, 'prayers', 'py-fear')['references'] = ['XYZ 1:1', 'ISA 41:10'],
      );
      expectIssue(r, IntelIssueCode.unresolvedReference, 'py-fear', 'unknown book XYZ');
    });
    test('a whole chapter instead of verses', () async {
      final r = await check('blessings.json', (j) => recordIn(j, 'blessings', 'bl-peace')['references'] = ['NUM 6']);
      expectIssue(r, IntelIssueCode.wholeChapterReference, 'bl-peace');
    });
    test('a reversed range', () async {
      final r = await check(
        'commands.json',
        (j) => recordIn(j, 'commands', 'cmd-seek-first')['references'] = ['MAT 6:33-30'],
      );
      expectIssue(r, IntelIssueCode.unresolvedReference, 'cmd-seek-first', 'range ends before it starts');
    });
    test('a verse the WEB omits is a warning, not an error', () async {
      final r = await check(
        'situations.json',
        (j) => (recordIn(j, 'situations', 'sit-sin')['references'] as List).add('ACT 8:37'),
      );
      expect(
        r.issues.where((i) => i.objectId == 'sit-sin' && i.code == IntelIssueCode.omittedInTranslation),
        isNotEmpty,
      );
      expect(r.errors.where((i) => i.objectId == 'sit-sin'), isEmpty);
    });
  });

  group('2. Referenced ids exist', () {
    test('situation → missing promise', () async {
      final r = await check(
        'situations.json',
        (j) => (recordIn(j, 'situations', 'sit-fear')['promiseIds'] as List).add('pr-nope'),
      );
      expectIssue(r, IntelIssueCode.unknownTarget, 'sit-fear', 'pr-nope');
    });
    test('prayer → missing situation', () async {
      final r = await check('prayers.json', (j) => recordIn(j, 'prayers', 'py-fear')['situationId'] = 'sit-nope');
      expectIssue(r, IntelIssueCode.unknownTarget, 'py-fear', 'sit-nope');
    });
    test('command → a record of the wrong kind', () async {
      final r = await check(
        'commands.json',
        (j) => recordIn(j, 'commands', 'cmd-ask-for-wisdom')['relatedPromiseIds'] = ['py-fear'],
      );
      expectIssue(r, IntelIssueCode.unknownTarget, 'cmd-ask-for-wisdom', 'as that kind');
    });
    test('taxonomy link → missing record', () async {
      final r = await check(
        'taxonomy.json',
        (j) => (j['links'] as List).add({'termId': 'theme-peace', 'objectType': 'promise', 'objectId': 'pr-ghost'}),
      );
      expectIssue(r, IntelIssueCode.unknownTarget, 'pr-ghost');
    });
    test('a rejected seed reappearing in the live corpus', () async {
      final r = await check('promises.json', (j) => recordIn(j, 'promises', 'pr-peace-1')['id'] = 'pr-faith-1');
      expectIssue(r, IntelIssueCode.rejectedSeedReused, 'pr-faith-1');
    });
  });

  group('3. Duplicate ids', () {
    test('two records with one id', () async {
      final r = await check('blessings.json', (j) => recordIn(j, 'blessings', 'bl-peace')['id'] = 'bl-morning');
      expectIssue(r, IntelIssueCode.duplicateId, 'bl-morning');
    });
    test('an id shared across kinds', () async {
      final r = await check('blessings.json', (j) => recordIn(j, 'blessings', 'bl-peace')['id'] = 'py-fear');
      expectIssue(r, IntelIssueCode.duplicateId, 'py-fear', 'Prayer');
    });
  });

  group('4. Orphans', () {
    test('a record citing no Scripture', () async {
      final r = await check(
        'worship_themes.json',
        (j) => recordIn(j, 'worshipThemes', 'ws-faithfulness')['references'] = [],
      );
      expectIssue(r, IntelIssueCode.orphan, 'ws-faithfulness');
    });
    test('an unused taxonomy term', () async {
      final raw = mutated(
        'taxonomy.json',
        (j) => (j['terms'] as List).add({'id': 'theme-unused', 'label': 'Unused', 'kind': 'theme'}),
      );
      // Keep the manifest count honest so the orphan check is what fails.
      final manifest = jsonDecode(raw['manifest.json']!) as Map<String, dynamic>;
      ((manifest['files'] as Map)['taxonomy.json'] as Map)['count'] += 1;
      raw['manifest.json'] = jsonEncode(manifest);
      expectIssue(await validateRaw(raw), IntelIssueCode.orphan, 'theme-unused');
    });
    test('a one-step journey', () async {
      final r = await check('journeys.json', (j) {
        final fear = recordIn(j, 'journeys', 'dp-fear');
        fear['steps'] = [(fear['steps'] as List).first];
      });
      expectIssue(r, IntelIssueCode.orphan, 'dp-fear', 'two steps');
    });
  });

  test('5. A prayer with one reference', () async {
    final r = await check('prayers.json', (j) => recordIn(j, 'prayers', 'py-rest')['references'] = ['MAT 11:28']);
    expectIssue(r, IntelIssueCode.prayerNeedsTwoReferences, 'py-rest', 'it has 1');
  });

  group('6. Declaration safety', () {
    test('a gendered pronoun for the reader', () async {
      final r = await check(
        'declarations.json',
        (j) => recordIn(j, 'declarations', 'dc-faith')['text'] =
            '{name} stands in faith; with God all things are possible for him.',
      );
      expectIssue(r, IntelIssueCode.genderedPronoun, 'dc-faith', 'him');
    });
    test('a feminine pronoun in the first-person form', () async {
      final r = await check(
        'declarations.json',
        (j) => recordIn(j, 'declarations', 'dc-faith')['firstPersonText'] = 'Her faith stands.',
      );
      expectIssue(r, IntelIssueCode.genderedPronoun, 'dc-faith', 'Her');
    });
    test('reverent capitalised pronouns for God are allowed', () async {
      final r = await check(
        'declarations.json',
        (j) => recordIn(j, 'declarations', 'dc-faith')['text'] = '{name} trusts Him; His word stands.',
      );
      expect(r.has(IntelIssueCode.genderedPronoun, 'dc-faith'), isFalse);
    });
    test('the demo\'s first-name token', () async {
      final r = await check(
        'declarations.json',
        (j) => recordIn(j, 'declarations', 'dc-faith')['text'] = '⟦F⟧ stands in faith.',
      );
      expectIssue(r, IntelIssueCode.placeholderMisuse, 'dc-faith', '⟦F⟧');
    });
    test('a name placeholder outside declarations', () async {
      final r = await check(
        'prayers.json',
        (j) => recordIn(j, 'prayers', 'py-fear')['text'] = 'Father, keep {name} today.',
      );
      expectIssue(r, IntelIssueCode.placeholderMisuse, 'py-fear');
    });
  });

  test('7. A relationship without an explanation', () async {
    final r = await check(
      'relationships.json',
      (j) => recordIn(j, 'relationships', 'rel-john14-27-isa26-3')['explanation'] = 'Similar.',
    );
    expectIssue(r, IntelIssueCode.missingExplanation, 'rel-john14-27-isa26-3');
  });

  group('8. Journey steps', () {
    test('a step pointing at a missing promise', () async {
      final r = await check(
        'journeys.json',
        (j) => ((recordIn(j, 'journeys', 'dp-anxiety')['steps'] as List)[3] as Map)['targetId'] = 'pr-gone',
      );
      expectIssue(r, IntelIssueCode.journeyStepUnresolved, 'dp-anxiety', 'pr-gone');
    });
    test('steps out of order', () async {
      final r = await check(
        'journeys.json',
        (j) => ((recordIn(j, 'journeys', 'dp-grief')['steps'] as List)[1] as Map)['order'] = 5,
      );
      expectIssue(r, IntelIssueCode.journeyOrder, 'dp-grief');
    });
    test('a verse step that does not resolve', () async {
      final r = await check(
        'journeys.json',
        (j) => ((recordIn(j, 'journeys', 'dp-rest')['steps'] as List)[1] as Map)['reference'] = 'MAT 11:99',
      );
      expectIssue(r, IntelIssueCode.unresolvedReference, 'dp-rest');
    });
  });

  group('9. Context integrity', () {
    test('an empty speaker', () async {
      final r = await check('contexts.json', (j) => recordIn(j, 'contexts', 'ctx-JHN-3-16')['speaker'] = ' ');
      expectIssue(r, IntelIssueCode.contextIncomplete, 'ctx-JHN-3-16', 'speaker');
    });
    test('an empty audience', () async {
      final r = await check('contexts.json', (j) => recordIn(j, 'contexts', 'ctx-JHN-3-16')['originalAudience'] = '');
      expectIssue(r, IntelIssueCode.contextIncomplete, 'ctx-JHN-3-16', 'originalAudience');
    });
    test('divine speech with understated personalisation risk', () async {
      final r = await check(
        'contexts.json',
        (j) => (recordIn(j, 'contexts', 'ctx-ISA-41-10')['personalisation'] as Map)['risk'] = 'low',
      );
      expectIssue(r, IntelIssueCode.riskUnderstated, 'ctx-ISA-41-10', 'Critical');
    });
  });

  group('10. Conditions', () {
    test('a conditional context without its condition', () async {
      final r = await check('contexts.json', (j) => recordIn(j, 'contexts', 'ctx-PSA-91-11')['conditionNote'] = '');
      expectIssue(r, IntelIssueCode.conditionMissing, 'ctx-PSA-91-11');
    });
    test('a promise that drops its condition', () async {
      final r = await check('promises.json', (j) => recordIn(j, 'promises', 'pr-prot-2')['conditions'] = []);
      expectIssue(r, IntelIssueCode.conditionMissing, 'pr-prot-2', 'habitation');
    });
  });

  group('11. Corporate passages', () {
    test('a promise to Zion recast as a general promise', () async {
      final r = await check('promises.json', (j) => recordIn(j, 'promises', 'pr-fam-1')['scope'] = 'general');
      expectIssue(r, IntelIssueCode.corporateAsIndividual, 'pr-fam-1', 'given to a people');
    });
    test('a declaration on a corporate passage without a grounding note', () async {
      final r = await check('declarations.json', (j) => recordIn(j, 'declarations', 'dc-family')['groundingNote'] = '');
      expectIssue(r, IntelIssueCode.corporateAsIndividual, 'dc-family', 'ISA 54:13');
    });
    test('a promise whose verse has no context', () async {
      final r = await check('promises.json', (j) => recordIn(j, 'promises', 'pr-peace-1')['references'] = ['PSA 4:8']);
      expectIssue(r, IntelIssueCode.missingContext, 'pr-peace-1', 'PSA 4:8');
    });
  });

  group('12/14. Scripture stays Scripture', () {
    test('editorial text that copies a verse', () async {
      final r = await check(
        'blessings.json',
        (j) => recordIn(j, 'blessings', 'bl-peace')['text'] =
            'The LORD lift up his countenance upon thee, and give thee peace.',
      );
      expectIssue(r, IntelIssueCode.scriptureCopiedAsEditorial, 'bl-peace', 'NUM 6:26');
    });
    test('verse text cannot be smuggled in as a field', () {
      final raw = mutated('contexts.json', (j) => recordIn(j, 'contexts', 'ctx-JHN-3-16')['kjv'] = 'For God so loved…');
      expect(
        () => parseIntelligenceCorpus(raw),
        throwsA(predicate((e) => '$e'.contains('ctx-JHN-3-16') && '$e'.contains('kjv'))),
      );
    });
  });

  group('13. Review integrity', () {
    test('marked reviewed with no reviewer', () async {
      final r = await check(
        'promises.json',
        (j) => recordIn(j, 'promises', 'pr-peace-1')['review'] = {'status': 'editoriallyReviewed'},
      );
      expectIssue(r, IntelIssueCode.approvalNotRecorded, 'pr-peace-1');
    });
    test('an "approved" personalisation eligibility is not a valid value', () {
      final raw = mutated(
        'contexts.json',
        (j) => (recordIn(j, 'contexts', 'ctx-JHN-3-16')['personalisation'] as Map)['eligibility'] = 'approved',
      );
      expect(() => parseIntelligenceCorpus(raw), throwsA(predicate((e) => '$e'.contains('unknown value "approved"'))));
    });
    test('seed provenance without a seed id', () async {
      final r = await check(
        'promises.json',
        (j) => (recordIn(j, 'promises', 'pr-peace-1')['provenance'] as Map).remove('seedId'),
      );
      expectIssue(r, IntelIssueCode.provenanceIncomplete, 'pr-peace-1');
    });
  });
}
