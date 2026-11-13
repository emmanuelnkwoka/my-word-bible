import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/data/models/intelligence.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart' show RiskLevel;
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/features/intelligence/domain/intelligence_validator.dart';

import '../helpers/test_app.dart';
import 'intel_test_support.dart';

ScriptureReference ref(String s) => ScriptureReference.parseCompact(s);

void main() {
  final corpus = shippedCorpus();

  group('Shipped corpus', () {
    test('decodes every file and matches the manifest counts', () {
      expect(corpus.manifest.schemaVersion, 1);
      expect(corpus.manifest.corpusVersion, '1.0.0');
      expect(corpus.manifest.canonicalVersion, 'KJV');
      expect(corpus.manifest.files['contexts.json'], corpus.contexts.length);
      expect(corpus.contexts, hasLength(117));
      expect(corpus.situations, hasLength(35));
      expect(corpus.promises, hasLength(23));
      expect(corpus.blessings, hasLength(12));
      expect(corpus.prayers, hasLength(15));
      expect(corpus.declarations, hasLength(10));
      expect(corpus.commands, hasLength(20));
      expect(corpus.identityThemes, hasLength(8));
      expect(corpus.worshipThemes, hasLength(8));
      expect(corpus.relationships, hasLength(24));
      expect(corpus.journeys, hasLength(11));
      expect(corpus.journeys.fold<int>(0, (n, j) => n + j.steps.length), 55);
      expect(corpus.manifest.rejected, hasLength(9));
    });

    test('every data file carries a schema and corpus version', () {
      for (final f in intelFiles) {
        final json = jsonDecode(File('$intelDir/$f').readAsStringSync()) as Map<String, dynamic>;
        expect(json['schemaVersion'], 1, reason: f);
        expect(json['corpusVersion'], '1.0.0', reason: f);
      }
    });

    test('passes the validator with no errors', () async {
      final report = (await validator()).validate(corpus);
      expect(report.errors, isEmpty, reason: report.errors.join('\n'));
      expect(report.recordsChecked, corpus.records.length);
      expect(report.referencesChecked, greaterThan(300));
    });

    test('warns only about verses the WEB numbers differently or omits', () async {
      final report = (await validator()).validate(corpus);
      for (final w in report.warnings) {
        expect(w.code, anyOf(IntelIssueCode.omittedInTranslation, IntelIssueCode.contextIncomplete), reason: '$w');
      }
    });

    test('no record stores translated verse text', () {
      for (final f in intelFiles) {
        final text = File('$intelDir/$f').readAsStringSync();
        expect(text.contains('"kjv"'), isFalse, reason: f);
        expect(text.contains('"verseText"'), isFalse, reason: f);
      }
    });

    test('every record awaits editorial review; none is marked reviewed', () {
      for (final r in corpus.records) {
        expect(r.review.status, EditorialStatus.pendingEditorialReview, reason: r.id);
        expect(r.review.reviewer, isNull, reason: r.id);
      }
    });

    test('every record records where it came from', () {
      final origins = corpus.records.map((r) => r.provenance.origin).toSet();
      expect(origins, {ProvenanceOrigin.demoSeed, ProvenanceOrigin.newlyCurated});
      for (final r in corpus.records.where((r) => r.provenance.origin == ProvenanceOrigin.demoSeed)) {
        expect(r.provenance.seedId, isNotEmpty, reason: r.id);
      }
    });

    test('loading the corpus leaves canonical Scripture untouched', () async {
      final before = (await sharedTestBible.passage('KJV', ref('EPH 2:10'))).verses.single.text;
      (await validator()).validate(corpus);
      expect(
        before,
        'For we are his workmanship, created in Christ Jesus unto good works, which God hath before ordained '
        'that we should walk in them.',
      );
      expect((await sharedTestBible.passage('KJV', ref('EPH 2:10'))).verses.single.text, before);
    });
  });

  group('Curation decisions', () {
    test('identity statements are not promises (Psalm 139:14, Ephesians 2:10)', () {
      final promiseRefs = corpus.promises.expand((p) => p.references).toSet();
      expect(promiseRefs, isNot(contains(ref('EPH 2:10'))));
      expect(promiseRefs, isNot(contains(ref('PSA 139:14'))));
      final workmanship = corpus.typed<IdentityTheme>('id-workmanship')!;
      expect(workmanship.references, [ref('EPH 2:10')]);
      expect(workmanship.holder, contains('Believers together'));
    });

    test('rejected seeds are recorded with reasons and replacements', () {
      final rejected = {for (final r in corpus.manifest.rejected) r.seedId: r};
      expect(rejected.keys, containsAll(['pr-ident-2', 'pr-faith-1', 'pres-always', 'heb13-5|isa41-10']));
      expect(rejected['pres-always']!.replacement, 'pr-pres-2');
      expect(rejected['heb13-5|isa41-10']!.reason, contains('Deuteronomy 31:6'));
      for (final r in rejected.values) {
        expect(corpus.byId(r.seedId), isNull, reason: r.seedId);
      }
    });

    test('Hebrews 13:5 is linked to the passage it quotes', () {
      final quotes = corpus
          .relationshipsFor(ref('HEB 13:5'))
          .where((r) => r.relationship.type == RelationshipType.quotation);
      expect(quotes.map((r) => r.other), [ref('DEU 31:6')]);
    });

    test('Jeremiah 29:11 keeps its exile audience and is not personalised', () {
      final c = corpus.contextsFor(ref('JER 29:11')).single;
      expect(c.originalAudience, contains('exiles'));
      expect(c.addressee, IntelAddressee.collective);
      expect(c.voice, IntelVoice.god);
      expect(c.eligibility, PersonalisationEligibility.notEligible);
      expect(c.personalisationRisk, RiskLevel.critical);
    });

    test('speaker and author are kept distinct', () {
      final john = corpus.contextsFor(ref('JHN 3:16')).single;
      expect(john.speaker, 'Jesus');
      expect(john.author, startsWith('John'));
      final ps46 = corpus.contextsFor(ref('PSA 46:1')).single;
      expect(ps46.author, contains('sons of Korah'));
      expect(ps46.provenance.changes.join(), contains('David'));
    });

    test('conditional promises keep their conditions', () {
      final ps91 = corpus.typed<IntelPromise>('pr-prot-2')!;
      expect(ps91.conditions.single, contains('habitation'));
      final prov = corpus.typed<IntelPromise>('pr-fut-2')!;
      expect(prov.conditions.single, contains('fear of the LORD'));
    });

    test('corporate promises stay corporate', () {
      final zion = corpus.typed<IntelPromise>('pr-fam-1')!;
      expect(zion.scope, PromiseScope.corporate);
      expect(zion.receptionGuidance, contains('not a guarantee'));
    });

    test('declarations are free of gendered pronouns and personalise safely', () {
      final d = corpus.typed<Declaration>('dc-strength')!;
      expect(d.text, isNot(contains(' him')));
      expect(d.personalised('Grace'), startsWith('Through Christ who strengthens, Grace can'));
      expect(d.personalised(null), d.firstPersonText);
      expect(d.personalised('  '), d.firstPersonText);
      expect(d.isScripture, isFalse);
      expect(d.displayLabel, contains('not Scripture text'));
    });

    test('commands are separate from promises', () {
      final ask = corpus.typed<IntelCommand>('cmd-ask-for-wisdom')!;
      expect(ask.relatedPromiseIds, ['pr-wis-1']);
      expect(corpus.typed<IntelPromise>(ask.id), isNull);
    });

    test('journeys keep their order and resolve every step', () {
      final fear = corpus.typed<Journey>('dp-fear')!;
      expect(fear.steps.map((s) => s.order), [1, 2, 3, 4, 5]);
      expect(fear.steps.first.targetId, 'sit-fear');
      expect(fear.steps[3].type, JourneyStepType.identity);
      expect(fear.steps[3].targetId, 'id-spirit-of-power');
    });
  });
}
