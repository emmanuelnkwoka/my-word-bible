import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/app/app.dart';
import 'package:my_word_bible/app/app_providers.dart';
import 'package:my_word_bible/app/app_router.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/data/models/library_items.dart';
import 'package:my_word_bible/features/bible/widgets/scripture_card.dart';
import 'package:my_word_bible/data/models/mwb_presentation_layer.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/models/user_profile.dart';
import 'package:my_word_bible/data/repositories/mwb_presentation_repository.dart';
import 'package:my_word_bible/features/personalisation/application/personalisation_providers.dart';
import 'package:my_word_bible/features/personalisation/application/scripture_presentation.dart';
import 'package:my_word_bible/features/personalisation/domain/personal_name.dart';
import 'package:my_word_bible/features/personalisation/domain/presentation_layer_resolver.dart';
import 'package:my_word_bible/features/share/scripture_image_composer.dart';
import 'package:my_word_bible/features/share/scripture_share_sheet.dart';
import 'package:my_word_bible/features/share/studio/card_design.dart';
import 'package:my_word_bible/features/share/studio/card_studio_renderer.dart';

import '../daily_word/daily_word_test_support.dart';
import '../helpers/test_app.dart';
import 'r3_test_support.dart';

final _repo = AssetMwbPresentationRepository(loader: readTestAsset);
Future<MwbPresentationCatalogue> cat(String edition) =>
    _repo.catalogue(edition, sourceVersionId: edition.split('-').first);

NameResolution named(UserProfile p) => PersonalNameResolver.resolve(p);
final grace = named(profile());

Future<VerseEditorialLayers> layers(String edition, String key, [NameResolution? name]) async =>
    PresentationLayerResolver.resolve(await cat(edition), key, name ?? grace);

/// Fill an r3 template the way the specification describes, for comparison.
String expected(String template, String name) =>
    template.replaceFirst(RegExp(r'^(\{name\}|\[Name\]), '), '$name, ');

const _internalLanguage = [
  'Proposed',
  'PROPOSED',
  'Not Approved',
  'NOT APPROVED',
  'not approved',
  'Awaiting Approval',
  'Pending Ratification',
  'Rejected',
  'REJECTED',
  'Internal Review',
  'Reviewer',
  'reviewer',
  'Editorial Decision',
  'Unresolved',
  'Correction Required',
  'Review preview',
  'approvedPresentation',
  'editorial_eligible',
  'requires_human_ratification',
  'unresolved_withhold',
];

void expectNoInternalLanguage(WidgetTester tester) {
  final texts = <String>[
    for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? '',
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) w.text.toPlainText(),
  ].join('\n');
  for (final phrase in _internalLanguage) {
    expect(texts.contains(phrase), isFalse, reason: 'ordinary UI shows "$phrase"');
  }
}

InMemoryKeyValueStore storeFor(String versionId, {UserProfile? user}) {
  final store = onboardedStore()..writeJson(StorageKeys.readingPreferences, {'versionId': versionId});
  if (user != null) store.writeJson(StorageKeys.userProfile, user.toJson());
  return store;
}

Finder verseLabel(String pattern) =>
    find.byWidgetPredicate((w) => w is Semantics && RegExp(pattern).hasMatch(w.properties.label ?? ''));

Future<void> openReader(WidgetTester tester, String bookId, int chapter, {int? verse}) async {
  final router = ProviderScope.containerOf(tester.element(find.byType(MwbApp))).read(appRouterProvider);
  router.push('/read/$bookId/$chapter${verse == null ? '' : '?v=$verse'}');
  await settle(tester);
}

void main() {
  group('Complete r3 data import', () {
    for (final edition in ['KJV-MWB', 'WEB-MWB']) {
      test('$edition: every r3 layer is present, keyed exactly, with approved wording only where eligible', () async {
        final c = await cat(edition);
        final csv = r3Layers(edition);
        expect(c.package, '2026.11-revised-r3');
        expect(c.layerCount, csv.length);
        for (final row in csv) {
          final layer = c.layersFor(row['verse_key']!).where((l) => l.id == row['layer_id']).single;
          expect(layer.type.name, row['layer_type']);
          expect(layer.disposition.code, row['publication_disposition']);
          if (row['publication_disposition'] == 'editorial_eligible') {
            expect(layer.content, row['content'], reason: row['layer_id']);
            expect(layer.isDisplayable, isTrue);
          } else {
            expect(layer.content, isNull, reason: 'withheld wording is not shipped: ${row['layer_id']}');
            expect(layer.isDisplayable, isFalse);
          }
        }
      });

      test('$edition: every eligible title and reception renders with the name, exactly as approved', () async {
        final c = await cat(edition);
        var titles = 0, receptions = 0;
        for (final row in r3Layers(edition).where((r) => r['publication_disposition'] == 'editorial_eligible')) {
          final l = PresentationLayerResolver.resolve(c, row['verse_key']!, grace);
          final shown = row['layer_type'] == 'personalTitle' ? l.title : l.reception;
          expect(shown?.text, expected(row['content']!, 'Grace Okafor'), reason: row['layer_id']);
          expect(shown!.layerId, row['layer_id']);
          row['layer_type'] == 'personalTitle' ? titles++ : receptions++;
        }
        final counts = edition == 'KJV-MWB' ? (33, 50) : (30, 50);
        expect((titles, receptions), counts);
      });

      test('$edition: the per-verse index agrees with the layers for all verses', () async {
        final c = await cat(edition);
        final rows = r3Csv('MWB_COMPLETE_PRESENTATIONS_${edition.split('-').first}.csv');
        expect(rows, hasLength(edition == 'KJV-MWB' ? 31102 : 31103));
        for (final r in rows) {
          final l = PresentationLayerResolver.resolve(c, r['verse_key']!, grace);
          expect(l.title != null, r['has_personal_title'] == 'yes', reason: r['verse_key']);
          expect(l.reception != null, r['has_personal_reception'] == 'yes', reason: r['verse_key']);
        }
      });
    }

    test('canonical Scripture integrity: all 62,205 r3 verses equal the app text, character for character', () async {
      for (final (file, version) in [('KJV', 'KJV'), ('WEB', 'WEB')]) {
        final rows = r3Csv('MWB_COMPLETE_PRESENTATIONS_$file.csv');
        final byChapter = <String, List<Map<String, String>>>{};
        for (final r in rows) {
          (byChapter['${r['book_id']}.${r['chapter']}'] ??= []).add(r);
        }
        for (final e in byChapter.entries) {
          final first = e.value.first;
          final verses = await sharedTestBible.chapter(version, first['book_id']!, int.parse(first['chapter']!));
          expect(verses, hasLength(e.value.length), reason: e.key);
          for (final r in e.value) {
            expect(verses[int.parse(r['verse']!) - 1].text, r['original_text'], reason: '$version ${r['verse_key']}');
          }
        }
      }
    });

    test('the layer assets are bundled (offline) and declared in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/mwb/presentation/'));
      for (final path in AssetMwbPresentationRepository.assets.values) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });
  });

  group('Deterministic lookup and publication policy', () {
    test('KJV and WEB lookups use their own edition wording', () async {
      expect((await layers('KJV-MWB', 'PSA.30.5')).title!.text, 'Grace Okafor, joy cometh in the morning');
      expect((await layers('WEB-MWB', 'PSA.30.5')).title!.text, 'Grace Okafor, joy comes in the morning');
    });

    test('original Scripture only: no layers', () async {
      expect((await layers('KJV-MWB', 'GEN.1.1')).isEmpty, isTrue);
      expect((await layers('WEB-MWB', 'GEN.1.1')).isEmpty, isTrue);
    });

    test('title only, reception only, and both', () async {
      final titleOnly = await layers('KJV-MWB', 'PSA.30.5');
      expect((titleOnly.title != null, titleOnly.reception != null), (true, false));
      final receptionOnly = await layers('KJV-MWB', 'ISA.41.10');
      expect((receptionOnly.title != null, receptionOnly.reception != null), (false, true));
      final both = await layers('KJV-MWB', 'ROM.8.37');
      expect(both.title!.text, 'Grace Okafor, more than conquerors');
      expect(both.reception!.text, startsWith('Grace Okafor, in all these things you are more than a conqueror'));
    });

    test('name-in-text is withheld everywhere (requires human ratification)', () async {
      for (final edition in ['KJV-MWB', 'WEB-MWB']) {
        final c = await cat(edition);
        final direct = c.allLayers.where((l) => l.type == MwbLayerType.directPersonalisation).toList();
        expect(direct, hasLength(edition == 'KJV-MWB' ? 111 : 106));
        for (final l in direct) {
          expect(l.disposition, PublicationDisposition.requiresHumanRatification);
          expect(l.isDisplayable, isFalse);
          expect(l.content, isNull);
        }
      }
      // Proverbs 3:5 has a name-in-text layer in r3: it is never shown.
      final kjv = await cat('KJV-MWB');
      expect(kjv.layerOf('PRO.3.5', MwbLayerType.directPersonalisation)!.isDisplayable, isFalse);
      expect(PresentationLayerResolver.resolve(kjv, 'PRO.3.5', grace).isEmpty, isTrue);
      // ISA 41:10: the reception shows; r3 has no name-in-text layer for it.
      expect((await layers('KJV-MWB', 'ISA.41.10')).reception, isNotNull);
      expect(kjv.layerOf('ISA.41.10', MwbLayerType.directPersonalisation), isNull);
    });

    test('all 15 withheld titles stay withheld; their verses still show any eligible reception', () async {
      final audit = r3Csv('MWB_TITLE_FAITHFULNESS_AUDIT.csv');
      expect(audit, hasLength(15));
      for (final a in audit) {
        final c = await cat(a['edition']!);
        final layer = c.layerOf(a['verse_key']!, MwbLayerType.personalTitle)!;
        expect(layer.disposition, PublicationDisposition.unresolvedWithhold, reason: a['verse_key']);
        expect(PresentationLayerResolver.resolve(c, a['verse_key']!, grace).title, isNull, reason: a['verse_key']);
      }
      // Ephesians 2:10: title withheld, reception independently shown.
      final eph = await layers('KJV-MWB', 'EPH.2.10');
      expect(eph.title, isNull);
      expect(eph.reception!.text, startsWith('Grace Okafor, in Christ you are God'));
      expect((await layers('KJV-MWB', 'ROM.5.1')).isEmpty, isTrue);
    });

    test('the five non-renderable WEB records carry no layer and no text', () async {
      final c = await cat('WEB-MWB');
      final audit = {for (final a in r3Csv('MWB_WEB_EMPTY_RECORD_AUDIT.csv')) '${a['book_id']}.${a['chapter']}.${a['verse']}'};
      expect(audit, {'LUK.17.36', 'ACT.8.37', 'ACT.15.34', 'ACT.24.7', 'ROM.16.25'});
      expect(c.nonRenderable, audit);
      for (final key in audit) {
        expect(PresentationLayerResolver.resolve(c, key, grace).isEmpty, isTrue);
        final p = key.split('.');
        final verses = await sharedTestBible.chapter('WEB', p[0], int.parse(p[1]));
        expect(verses[int.parse(p[2]) - 1].text, isEmpty, reason: 'WEB text is not fabricated or copied from KJV');
      }
    });

    test('Psalm/Psalms: the verse key, never the display name, finds layers (7 recovered receptions)', () async {
      final c = await cat('KJV-MWB');
      final psalmReceptions = r3Layers('KJV-MWB').where((r) => r['book_id'] == 'PSA' && r['layer_type'] == 'personalReception');
      expect(psalmReceptions, isNotEmpty);
      for (final r in psalmReceptions) {
        expect(r['reference'], startsWith('Psalms '));
        final ref = ScriptureReference(bookId: 'PSA', chapter: int.parse(r['chapter']!), verseStart: int.parse(r['verse']!));
        expect(ref.label, startsWith('Psalm '), reason: 'the app shows "Psalm" for a verse');
        expect(editorialLayersFor(c, ref, grace)[ref.verseStart]!.reception, isNotNull, reason: r['verse_key']);
      }
      expect(c.layersFor('Psalms 30:5'), isEmpty);
      expect(c.layersFor('Psalm.30.5'), isEmpty);
    });

    test('an edition without layers, or a layer file for another edition, shows the original', () async {
      final none = await _repo.catalogue('NKJV-MWB', sourceVersionId: 'NKJV');
      expect(none.layerCount, 0);
      final wrong = AssetMwbPresentationRepository(
        loader: (p) => readTestAsset('assets/mwb/presentation/web-mwb.layers.json'),
      );
      expect((await wrong.catalogue('KJV-MWB', sourceVersionId: 'KJV')).layerCount, 0);
    });
  });

  group('Name preferences', () {
    test('full, first, preferred and no name', () async {
      final key = 'ROM.8.37';
      expect((await layers('KJV-MWB', key, named(profile()))).title!.text, 'Grace Okafor, more than conquerors');
      expect(
        (await layers('KJV-MWB', key, named(profile(pref: NamePreference.firstName)))).title!.text,
        'Grace, more than conquerors',
      );
      expect(
        (await layers('KJV-MWB', key, named(profile(preferred: 'Gracie', pref: NamePreference.preferredName))))
            .title!
            .text,
        'Gracie, more than conquerors',
      );
      final none = await layers('KJV-MWB', key, named(profile(pref: NamePreference.none)));
      expect(none.title!.text, 'More than conquerors');
      expect(none.title!.name, isNull);
      expect(none.reception!.text, 'In all these things you are more than a conqueror through Him who loved you.');
    });

    test('a missing preferred name falls back to the first name; no name set gives the nameless form', () async {
      final fallback = await layers('KJV-MWB', 'PSA.30.5', named(profile(pref: NamePreference.preferredName)));
      expect(fallback.title!.text, 'Grace, joy cometh in the morning');
      final empty = await layers('KJV-MWB', 'PSA.30.5', named(profile(first: '', last: '')));
      expect(empty.title!.text, 'Joy cometh in the morning');
    });

    test('the production app holds no hard-coded personal name', () {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(f.readAsStringSync().contains('Emmanuel Nkwoka'), isFalse, reason: f.path);
      }
    });

    test('an unresolvable template is omitted, never shown with a placeholder', () {
      expect(PresentationLayerResolver.fill('Joy, {name}, cometh', grace), isNull);
      expect(PresentationLayerResolver.fill('{name}, ', grace), isNull);
      expect(PresentationLayerResolver.fill('{name}, a {name}', grace), isNull);
    });
  });

  test('copied Scripture includes the reception after the canonical verse', () async {
    final passage = await sharedTestBible.passage('KJV', ScriptureReference.parseCompact('ISA 41:10'));
    final r = (await layers('KJV-MWB', 'ISA.41.10')).reception!.text;
    final text = scriptureShareText(passage, 'KJV', reception: r);
    expect(text, startsWith('“Fear thou not; for I am with thee'));
    expect(text, contains('— Isaiah 41:10 (KJV)\n\nPersonal reception: Grace Okafor, the same God'));
    expect(scriptureShareText(passage, 'KJV'), isNot(contains('Personal reception')));
  });

  group('Governing worked cases (actual r3 records)', () {
    Map<String, String> row(String edition, String key, String type) =>
        r3Layers(edition).singleWhere((r) => r['verse_key'] == key && r['layer_type'] == type);

    test('each case renders its approved records, unchanged canonical text alongside', () async {
      final cases = {
        'ISA.43.1': ('Isaiah 43:1', false),
        'ISA.41.10': ('Isaiah 41:10', false),
        'EPH.2.10': ('Ephesians 2:10', false),
        'ROM.8.37': ('Romans 8:37', true),
        'JHN.11.25': ('John 11:25', false),
        'ROM.15.13': ('Romans 15:13', false),
        '3JN.1.2': ('3 John 1:2', false),
        'PRO.1.8': ('Proverbs 1:8', false),
        'PRO.23.18': ('Proverbs 23:18', false),
      };
      for (final MapEntry(key: key, value: (_, hasTitle)) in cases.entries) {
        final l = await layers('KJV-MWB', key);
        expect(l.reception!.text, expected(row('KJV-MWB', key, 'personalReception')['content']!, 'Grace Okafor'));
        expect(l.title != null, hasTitle, reason: key);
      }
    });

    test('speaker, Christology and audience are preserved in the receptions', () async {
      final isa431 = (await layers('KJV-MWB', 'ISA.43.1')).reception!.text;
      expect(isa431, contains('the LORD who created and redeemed His people'));
      expect(isa431, contains('In Christ'));
      final isa4110 = (await layers('KJV-MWB', 'ISA.41.10')).reception!.text;
      expect(isa4110, contains('promised Israel'));
      final jhn = (await layers('KJV-MWB', 'JHN.11.25')).reception!.text;
      expect(jhn, contains('Jesus Christ is the resurrection and the life'));
      expect(jhn.contains('you are the resurrection'), isFalse);
      final eph = (await layers('KJV-MWB', 'EPH.2.10')).reception!.text;
      expect(eph, contains('in Christ you are God'));
      final third = (await layers('KJV-MWB', '3JN.1.2')).reception!.text;
      expect(third, contains('the apostle John had for his friend Gaius'));
      expect(third, contains('in step with a soul'));
      expect(third.toLowerCase().contains('guarantee'), isFalse);
      final pro = (await layers('KJV-MWB', 'PRO.23.18')).reception!.text;
      expect(pro, contains('hold fast to the fear of the LORD'));
      // The canonical verses themselves are untouched.
      expect(
        (await sharedTestBible.passage('KJV', ScriptureReference.parseCompact('JHN 11:25'))).text,
        startsWith('Jesus said unto her, I am the resurrection, and the life'),
      );
    });

    test('Romans 15:13: WEB has title and reception together; KJV has the reception only (as in r3)', () async {
      final web = await layers('WEB-MWB', 'ROM.15.13');
      expect(web.title!.text, 'Grace Okafor, abound in hope');
      expect(web.reception!.text, startsWith('Grace Okafor, may the God of hope fill you'));
      final kjv = await layers('KJV-MWB', 'ROM.15.13');
      expect(kjv.title, isNull, reason: 'the r3 KJV layer mapping has no title layer for ROM.15.13');
      expect(r3Layers('KJV-MWB').where((r) => r['verse_key'] == 'ROM.15.13' && r['layer_type'] == 'personalTitle'), isEmpty);
      expect(kjv.reception, isNotNull);
    });
  });

  group('Shared presentation across the app', () {
    testWidgets('Bible Reader (KJV-MWB): title above, reception below, verse unchanged; KJV shows Scripture only', (
      tester,
    ) async {
      await pumpMwbApp(tester, storeFor('KJV-MWB'));
      await openReader(tester, 'ROM', 8, verse: 37);
      await scrollTo(tester, find.byKey(const ValueKey('verse-reception-37')));
      expect(find.byKey(const ValueKey('verse-title-37')), findsOneWidget);
      expect(find.byKey(const ValueKey('verse-reception-37')), findsOneWidget);
      expect(
        verseLabel(
          r'^Verse 37\. Nay, in all these things we are more than conquerors through him that loved us\.\. '
          r'Personal title: Grace, more than conquerors\. Personal reception: Grace, in all these things',
        ),
        findsOneWidget,
      );
      expectNoInternalLanguage(tester);

      await pumpMwbApp(tester, storeFor('KJV'));
      await openReader(tester, 'ROM', 8, verse: 37);
      expect(find.byKey(const ValueKey('verse-title-37')), findsNothing);
      expect(find.byKey(const ValueKey('verse-reception-37')), findsNothing);
    });

    testWidgets('Reader (WEB-MWB): Romans 15:13 shows both layers; Acts 8:37 shows no verse text or layer', (
      tester,
    ) async {
      await pumpMwbApp(tester, storeFor('WEB-MWB'));
      await openReader(tester, 'ROM', 15, verse: 13);
      await scrollTo(tester, find.byKey(const ValueKey('verse-reception-13')));
      expect(find.byKey(const ValueKey('verse-title-13')), findsOneWidget);
      await openReader(tester, 'ACT', 8, verse: 37);
      await scrollTo(tester, verseLabel(r'^Verse 37\.'));
      expect(verseLabel(r'^Verse 37\. This verse is not included in the WEB text\.$'), findsOneWidget);
      expect(find.byKey(const ValueKey('verse-reception-37')), findsNothing);
      expect(find.byKey(const ValueKey('verse-title-37')), findsNothing);
    });

    testWidgets('Reader: no internal review language in an MWB chapter with withheld layers', (tester) async {
      await pumpMwbApp(tester, storeFor('KJV-MWB'));
      await openReader(tester, 'PRO', 3);
      expectNoInternalLanguage(tester);
      // Withheld name-in-text never replaces Proverbs 3:5.
      await scrollTo(tester, verseLabel(r'^Verse 5\.'));
      expect(verseLabel(r'^Verse 5\. Trust in the LORD with all thine heart; and lean not unto thine own understanding\.'), findsOneWidget);
    });

    testWidgets('Daily Word screen: the same layers (Proverbs 23:18 reception)', (tester) async {
      final store = storeFor('KJV');
      final candidate = shippedCatalogue().candidates.firstWhere((c) => c.id == 'dwc-PRO-23-18');
      await store.writeList(StorageKeys.dailyWordHistory, [entryFor(DateTime(2026, 11, 9), candidate)], (e) => e.toJson());
      await pumpMwbApp(tester, store);
      ProviderScope.containerOf(tester.element(find.byType(MwbApp))).read(appRouterProvider).push('/daily-word?d=2026-11-09');
      await settle(tester);
      expect(find.text('— Proverbs 23:18'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('dailyWord.reception.0')));
      expect(
        find.descendant(
          of: find.byKey(const Key('dailyWord.reception.0')),
          matching: find.textContaining('hold fast to the fear of the LORD', findRichText: true),
        ),
        findsOneWidget,
      );
      expectNoInternalLanguage(tester);
    });

    test('Daily Word with a title: Psalm 30:5 uses the approved title, not the fallback', () async {
      final c = testContainer(storeFor('KJV'));
      final p = await c.read(
        scripturePresentationProvider(
          PresentationRequest(ScriptureReference.parseCompact('PSA 30:5'), fallbackTitle: dailyWordFallbackTitle),
        ).future,
      );
      expect(p.mode, ScriptureMode.nameInTitle);
      expect(p.title, 'Grace, joy cometh in the morning');
      expect(p.titleName, 'Grace');
      expect(p.text, (await sharedTestBible.passage('KJV', ScriptureReference.parseCompact('PSA 30:5'))).text);
    });

    testWidgets('Discover topic, Library and Search show the same layers in KJV-MWB', (tester) async {
      final store = storeFor('KJV-MWB');
      await store.writeList(StorageKeys.savedScripture, [
        SavedScripture(reference: ScriptureReference.parseCompact('ROM 8:37'), versionId: 'KJV', savedAt: fixedNow),
      ], (s) => s.toJson());
      await pumpMwbApp(tester, store);
      final router = ProviderScope.containerOf(tester.element(find.byType(MwbApp))).read(appRouterProvider);

      router.push('/topic/fear');
      await settle(tester);
      await scrollTo(tester, find.byKey(const ValueKey('snippet-reception-ISA.41.10-10')));
      expect(find.byKey(const ValueKey('snippet-reception-ISA.41.10-10')), findsOneWidget);

      router.go('/library');
      await settle(tester);
      await scrollTo(tester, find.byKey(const ValueKey('snippet-title-ROM.8.37-37')));
      expect(find.byKey(const ValueKey('snippet-reception-ROM.8.37-37')), findsOneWidget);

      router.push('/search?q=${Uri.encodeQueryComponent('more than conquerors')}');
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester);
      expect(find.byKey(const ValueKey('snippet-title-ROM.8.37-37')), findsOneWidget);
      expectNoInternalLanguage(tester);

      // A reference search ("Romans 8:37") shows the reference card with the same layers.
      router.pop();
      await settle(tester);
      router.push('/search?q=${Uri.encodeQueryComponent('Romans 8:37')}');
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester);
      final card = find.byKey(const ValueKey('card-layers-ROM.8.37-37'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('more than a conqueror through Him', findRichText: true)),
        findsOneWidget,
      );
    });

    test('Sharing: canonical text plus the approved title and reception, labelled', () async {
      final c = testContainer(storeFor('KJV'));
      final p = await c.read(
        scripturePresentationProvider(PresentationRequest(ScriptureReference.parseCompact('ROM 8:37'))).future,
      );
      final s = shareScriptureFromPresentation(p);
      expect(s.verses.single.text, (await sharedTestBible.passage('KJV', ScriptureReference.parseCompact('ROM 8:37'))).text);
      expect(s.title, 'Grace, more than conquerors');
      expect(s.reception, startsWith('Grace, in all these things'));
      expect(s.translation, 'KJV', reason: 'Scripture is the KJV, not an altered rendering');
      expect(s.personalised, isFalse);
      final text = sharePayloadFor(s).text;
      expect(text, contains('Personal reception: Grace, in all these things'));
      expect(text, contains('— Romans 8:37 (KJV)'));

      final style = ShareStyle.fromPalette(MwbThemes.byId(MwbThemeId.classicGold).paletteFor(Brightness.light));
      for (final f in ShareFormat.values) {
        expect(ScriptureImageComposer.plan(s, f, style), hasLength(1), reason: f.name);
        expect(ScriptureImageComposer.receptionHeight(s, f, style), greaterThan(0));
      }
      final studio = CardStudioRenderer.plan(s, const CardDesign(template: CardTemplate.navy));
      expect(studio.every((page) => page.fits), isTrue);
    });

    testWidgets('Sharing renders cards with a reception at the exact size', (tester) async {
      await tester.runAsync(() async {
        const s = ShareScripture(
          verses: [ShareVerse(37, [ShareSpan('Nay, in all these things we are more than conquerors through him that loved us.')])],
          reference: 'Romans 8:37',
          translation: 'KJV',
          title: 'Grace, more than conquerors',
          titleName: 'Grace',
          reception: 'Grace, in all these things you are more than a conqueror through Him who loved you.',
          receptionName: 'Grace',
        );
        final style = ShareStyle.fromPalette(MwbThemes.byId(MwbThemeId.royalPlum).paletteFor(Brightness.dark));
        final quick = await const ScriptureImageComposer().compose(s, ShareFormat.story, style);
        expect((quick.single.width, quick.single.height), (1080, 1920));
        final card = await const CardStudioRenderer().compose(s, const CardDesign(template: CardTemplate.ivoryGold), classicStyle: style);
        expect((card.single.width, card.single.height), (1080, 1350));
      });
    });

    testWidgets('Reader selection share carries the reception (FakeShareService)', (tester) async {
      final share = FakeShareService();
      await pumpMwbApp(tester, storeFor('KJV-MWB'), extra: [shareServiceProvider.overrideWithValue(share)]);
      await openReader(tester, 'ISA', 41, verse: 10);
      await scrollTo(tester, verseLabel(r'^Verse 10\.'));
      await tester.tap(verseLabel(r'^Verse 10\.'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await settle(tester);
      await tester.tap(find.byKey(const Key('share.text')));
      await settle(tester);
      final text = share.texts.single.text;
      expect(text, startsWith('“Fear thou not; for I am with thee'));
      expect(text, contains('Personal reception: Grace, the same God who promised Israel'));
      expect(text, isNot(contains('Fear thou not, Grace')));
    });

    testWidgets('reader layers render in all seven themes, light and dark', (tester) async {
      for (final theme in MwbThemeId.values) {
        for (final mode in ['light', 'dark']) {
          final store = storeFor('KJV-MWB');
          await store.setString(StorageKeys.themeId, theme.storageKey);
          await store.setString(StorageKeys.themeMode, mode);
          await pumpMwbApp(tester, store);
          await openReader(tester, 'ROM', 8, verse: 37);
          expect(find.byKey(const ValueKey('verse-reception-37')), findsOneWidget, reason: '${theme.name}/$mode');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('Profile and Home show no review tools or review language in an ordinary build', (tester) async {
      final store = storeFor('KJV-MWB')..setBool(StorageKeys.mwbReviewerMode, true);
      await pumpMwbApp(tester, store);
      expectNoInternalLanguage(tester);
      ProviderScope.containerOf(tester.element(find.byType(MwbApp))).read(appRouterProvider).go('/profile');
      await settle(tester);
      for (var i = 0; i < 6; i++) {
        await tester.drag(verticalScrollable(), const Offset(0, -500));
        await settle(tester);
        expect(find.text('Personalisation review'), findsNothing);
        expect(find.text('MWB reviewer preview'), findsNothing);
        expectNoInternalLanguage(tester);
      }
    });
  });
}

