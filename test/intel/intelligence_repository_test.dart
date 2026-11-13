import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/app/app_providers.dart';
import 'package:my_word_bible/core/errors/app_failure.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/intelligence.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/repositories/intelligence_repository.dart';
import 'package:my_word_bible/features/intelligence/application/intelligence_providers.dart';

import '../helpers/test_app.dart';
import 'intel_test_support.dart';

ScriptureReference ref(String s) => ScriptureReference.parseCompact(s);

void main() {
  final requested = <String>[];
  AssetIntelligenceRepository repo({Map<String, String>? raw}) => AssetIntelligenceRepository(
    parseInBackground: false,
    loader: (path) async {
      requested.add(path);
      final name = path.split('/').last;
      final files = raw ?? shippedRaw();
      final text = files[name];
      if (text == null) throw FlutterAssetMissing(path);
      return text;
    },
  );

  setUp(requested.clear);

  group('Loading', () {
    test('reads only bundled asset files, once', () async {
      final r = repo();
      await Future.wait([r.situations(), r.promises(), r.journeys(), r.corpus()]);
      await r.prayers();
      expect(r.loads, 1);
      expect(requested, hasLength(intelFiles.length));
      expect(requested.every((p) => p.startsWith('assets/intel/') && !p.contains('://')), isTrue);
    });

    test('the corpus is declared as a bundled asset directory', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/intel/'));
      for (final f in intelFiles) {
        expect(File('$intelDir/$f').existsSync(), isTrue, reason: f);
      }
    });

    test('a missing file fails with a clear failure, then can retry', () async {
      final raw = shippedRaw()..remove('journeys.json');
      final r = repo(raw: raw);
      await expectLater(r.corpus(), throwsA(isA<UnknownFailure>()));
      expect(r.loads, 1);
      await expectLater(r.corpus(), throwsA(isA<UnknownFailure>()));
      expect(r.loads, 2, reason: 'a failed load is not cached');
    });

    test('malformed JSON names the file', () async {
      final raw = shippedRaw()..['prayers.json'] = '{ not json';
      await expectLater(
        repo(raw: raw).corpus(),
        throwsA(isA<UnknownFailure>().having((f) => f.message, 'message', contains('prayers.json is not valid JSON'))),
      );
    });

    test('an unsupported schema version is rejected', () {
      final raw = mutated('promises.json', (j) => j['schemaVersion'] = 2);
      expect(() => parseIntelligenceCorpus(raw), throwsA(predicate((e) => '$e'.contains('promises.json: schema 2'))));
    });

    test('a wrongly typed field names the record and field', () {
      final raw = mutated('prayers.json', (j) => recordIn(j, 'prayers', 'py-fear')['references'] = 'ISA 41:10');
      expect(
        () => parseIntelligenceCorpus(raw),
        throwsA(
          predicate((e) => '$e'.contains('prayers.json › py-fear') && '$e'.contains('"references" must be a list')),
        ),
      );
    });

    test('a non-canonical reference string is rejected', () {
      final raw = mutated(
        'promises.json',
        (j) => recordIn(j, 'promises', 'pr-peace-1')['references'] = ['Isaiah 26:3'],
      );
      expect(() => parseIntelligenceCorpus(raw), throwsA(predicate((e) => '$e'.contains('not a canonical reference'))));
    });

    test('a manifest count that does not match is rejected', () {
      final raw = mutated('manifest.json', (j) => (j['files'] as Map)['promises.json']['count'] = 99);
      expect(
        () => parseIntelligenceCorpus(raw),
        throwsA(predicate((e) => '$e'.contains('99 record(s) for promises.json'))),
      );
    });
  });

  group('Queries', () {
    final r = repo();

    test('context by reference, including inside a range', () async {
      final c = (await r.contextFor(ref('ISA 41:10')))!;
      expect(c.voice, IntelVoice.god);
      expect(c.originalAudience, contains('Israel'));
      expect((await r.contextFor(ref('LAM 3:23')))!.reference, ref('LAM 3:22-23'));
      expect(await r.contextFor(ref('GEN 5:1')), isNull);
    });

    test('situations and situation by id', () async {
      expect(await r.situations(), hasLength(35));
      final fear = (await r.situation('sit-fear'))!;
      expect(fear.name, 'Fear');
      expect(fear.references, contains(ref('ISA 41:10')));
      expect(fear.prayerIds, ['py-fear']);
      expect(fear.journeyIds, ['dp-fear']);
      expect(await r.situation('sit-missing'), isNull);
      expect(await r.situation('py-fear'), isNull, reason: 'wrong kind');
    });

    test('lists of each kind', () async {
      expect((await r.promises()).first.id, 'pr-hope-2');
      expect(await r.blessings(), hasLength(12));
      expect(await r.prayers(), hasLength(15));
      expect(await r.declarations(), hasLength(10));
      expect(await r.commands(), hasLength(20));
      expect(await r.identityThemes(), hasLength(8));
      expect(await r.worshipThemes(), hasLength(8));
    });

    test('relationships for a reference are navigable both ways', () async {
      final fromIsa = await r.relationshipsFor(ref('ISA 26:3'));
      expect(fromIsa.map((v) => v.other), contains(ref('JHN 14:27')));
      final fromJohn = await r.relationshipsFor(ref('JHN 14:27'));
      expect(fromJohn.map((v) => v.other), containsAll([ref('ISA 26:3'), ref('PHP 4:7')]));
      expect(fromJohn.every((v) => v.relationship.explanation.isNotEmpty), isTrue);
    });

    test('journeys and journeys for a situation', () async {
      expect(await r.journeys(), hasLength(11));
      final j = await r.journeysForSituation('sit-healing');
      expect(j.map((x) => x.id), ['dp-sickness']);
      expect(await r.journeysForSituation('sit-exams'), isEmpty);
    });

    test('search metadata covers every searchable record', () async {
      final entries = await r.searchEntries();
      final corpus = await r.corpus();
      expect(entries.length, corpus.records.length - corpus.relationships.length);
      final fear = entries.singleWhere((e) => e.id == 'sit-fear');
      expect(fear.kind, IntelKind.situation);
      final prayer = entries.singleWhere((e) => e.id == 'py-fear');
      expect(prayer.body, startsWith('Father'));
      final promise = entries.singleWhere((e) => e.id == 'pr-peace-1');
      expect(promise.keywords, contains('peace'));
    });

    test('records citing a verse', () async {
      final citing = (await r.corpus()).recordsCiting(ref('ISA 41:10'));
      expect(
        citing.map((x) => x.kind).toSet(),
        containsAll([IntelKind.situation, IntelKind.prayer, IntelKind.blessing]),
      );
    });
  });

  test('the app provider loads the corpus offline through the repository', () async {
    final c = testContainer(InMemoryKeyValueStore());
    final info = await c.read(passageIntelligenceProvider(ref('PRO 23:18')).future);
    expect(info.context!.isConditional, isTrue);
    expect(info.relationships.map((v) => v.other), contains(ref('PRO 23:17')));
    expect(info.citedBy.map((x) => x.id), containsAll(['pr-fut-2', 'py-hope']));
    expect(c.read(intelligenceRepositoryProvider), isA<AssetIntelligenceRepository>());
  });
}

class FlutterAssetMissing implements Exception {
  FlutterAssetMissing(this.path);
  final String path;
}
