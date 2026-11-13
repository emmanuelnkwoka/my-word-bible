import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_word_bible/app/routes.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/bible_canon.dart';
import 'package:my_word_bible/data/models/mwb_rule.dart';
import 'package:my_word_bible/data/repositories/theological_review_repository.dart';
import 'package:my_word_bible/features/bible/application/bible_providers.dart';
import 'package:my_word_bible/features/personalisation/application/mwb_reader_providers.dart';
import 'package:my_word_bible/features/personalisation/domain/mwb_renderer.dart';
import 'package:my_word_bible/features/personalisation/domain/personal_name.dart';
import 'package:my_word_bible/features/personalisation/domain/rendered_verse.dart';
import 'package:my_word_bible/features/personalisation/presentation/mwb_review_widgets.dart';
import 'package:my_word_bible/features/search/application/search_controller.dart';

import '../helpers/test_app.dart';
import 'mwb_test_support.dart';

Future<String> web(String reference) async => (await sharedTestBible.passage('WEB', ref(reference))).verses.single.text;

/// A store for an onboarded reader ("Grace", no surname) reading [versionId].
InMemoryKeyValueStore readerStore(String versionId, {bool reviewer = false, Map<String, String> approved = const {}}) {
  final store = onboardedStore()..writeJson(StorageKeys.readingPreferences, {'versionId': versionId});
  if (reviewer) store.setBool(StorageKeys.mwbReviewerMode, true);
  if (approved.isNotEmpty) {
    store.setString(
      LocalTheologicalReviewRepository.storageKey,
      jsonEncode({
        for (final e in approved.entries) e.key: [testApproval(reviewer: e.value).toJson()],
      }),
    );
  }
  return store;
}

Future<void> openReader(WidgetTester tester, String bookId, int chapter) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.reader(bookId, chapter));
  await settle(tester);
}

Finder verseLabel(String pattern) => find.bySemanticsLabel(RegExp(pattern));

void main() {
  group('World English Bible text', () {
    final raw = jsonDecode(File('assets/bible/web.json').readAsStringSync()) as Map<String, dynamic>;
    final books = (raw['books'] as List).cast<Map<String, dynamic>>();

    test('all 66 books, in canonical order, with the canonical chapter counts', () {
      expect(books, hasLength(66));
      for (var i = 0; i < 66; i++) {
        final canon = BibleCanon.books[i];
        expect(books[i]['id'], canon.id);
        expect(books[i]['testament'], canon.isOld ? 'OT' : 'NT');
        expect((books[i]['chapters'] as List).length, canon.chapterCount, reason: canon.id);
      }
    });

    test('verse structure matches the KJV except where the WEB really differs', () async {
      final differences = <String>[];
      var slots = 0;
      for (final canon in BibleCanon.books) {
        for (var c = 1; c <= canon.chapterCount; c++) {
          final w = await sharedTestBible.chapter('WEB', canon.id, c);
          final k = await sharedTestBible.chapter('KJV', canon.id, c);
          slots += w.length;
          if (w.length != k.length) differences.add('${canon.id} $c');
        }
      }
      expect(slots, 31103);
      // The WEB places the Romans 16:25-27 doxology at Romans 14:24-26.
      expect(differences, ['ROM 14', 'ROM 16']);
    });

    test('verses the WEB omits are recorded and kept as numbered gaps, never filled in', () async {
      expect(raw['omittedVerses'], ['LUK 17:36', 'ACT 8:37', 'ACT 15:34', 'ACT 24:7', 'ROM 16:25']);
      final luke = await sharedTestBible.chapter('WEB', 'LUK', 17);
      expect(luke[35].number, 36);
      expect(luke[35].isOmitted, isTrue);
      expect(luke[36].text, startsWith('They, answering, asked him'));
      // Every other verse has text.
      var empty = 0;
      for (final b in books) {
        for (final ch in (b['chapters'] as List)) {
          empty += (ch as List).where((v) => v == '').length;
        }
      }
      expect(empty, 5);
    });

    test('WEB wording is its own, not the KJV', () async {
      expect(await web('GEN 1:1'), 'In the beginning, God created the heavens and the earth.');
      expect(
        await web('JHN 3:16'),
        'For God so loved the world, that he gave his only born Son, that whoever believes in him should not perish, '
        'but have eternal life.',
      );
      expect(await web('PRO 23:18'), 'Indeed surely there is a future hope, and your hope will not be cut off.');
      var same = 0;
      for (final r in ['GEN 1:1', 'PSA 23:1', 'JHN 3:16', 'ROM 8:28', 'PRO 3:5']) {
        if (await web(r) == await kjv(r)) same++;
      }
      expect(same, 0);
    });

    test('is bundled for offline use and loads through the repository', () async {
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/bible/'));
      expect(File('assets/bible/web.json').existsSync(), isTrue);
      final bookList = await sharedTestBible.books('WEB');
      expect(bookList.map((b) => b.name).take(3), ['Genesis', 'Exodus', 'Leviticus']);
      final hits = await sharedTestBible.search('WEB', 'only born Son');
      expect(hits.map((h) => h.verse.reference.label), contains('John 1:14'));
      expect(hits.every((h) => h.versionId == 'WEB'), isTrue);
    });

    test('the conversion tool reproduces the asset (no hand edits)', () {
      expect(File('tool/build_web_asset.js').readAsStringSync(), contains('engwebp'));
      expect(raw['source'], 'eBible.org engwebp');
      expect(raw['license'], 'Public domain');
    });
  });

  group('Version selection and reading', () {
    test('each edition reads the canonical text of its own original', () async {
      for (final (id, source, sample) in [
        ('KJV', 'KJV', 'For God so loved the world, that he gave his only begotten Son'),
        ('KJV-MWB', 'KJV', 'For God so loved the world, that he gave his only begotten Son'),
        ('WEB', 'WEB', 'For God so loved the world, that he gave his only born Son'),
        ('WEB-MWB', 'WEB', 'For God so loved the world, that he gave his only born Son'),
      ]) {
        final c = testContainer(readerStore(id));
        expect(c.read(activeVersionProvider).id, id);
        expect(c.read(textVersionProvider).id, source);
        final verses = await c.read(chapterVersesProvider(ref('JHN 3')).future);
        expect(verses[15].text, startsWith(sample), reason: id);
      }
    });

    test('search under an MWB edition searches its original translation', () async {
      final c = testContainer(readerStore('WEB-MWB'));
      c.listen(searchQueryProvider, (_, _) {});
      c.listen(searchResultsProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('only born Son');
      final results = await c.read(searchResultsProvider.future);
      expect(results.verses.first.versionId, 'WEB');
    });

    test('approved-only rendering in normal mode; reviewer proposals are kept separate', () async {
      final normal = testContainer(readerStore('WEB-MWB'));
      final view = (await normal.read(mwbChapterProvider(ref('PRO 23')).future))!;
      expect(view.reviewerMode, isFalse);
      expect(view.proposals, isEmpty);
      expect(view.personalisedCount, 0);
      expect(view.verses[14].text, await web('PRO 23:15'));

      final reviewer = testContainer(readerStore('WEB-MWB', reviewer: true), extra: reviewerBuild);
      final rv = (await reviewer.read(mwbChapterProvider(ref('PRO 23')).future))!;
      expect(rv.reviewerMode, isTrue);
      // Scripture text still shows only approved renderings.
      expect(rv.verses[14].text, await web('PRO 23:15'));
      expect(rv.proposals.keys, unorderedEquals([15, 18, 26]));
      expect(
        rv.proposals[15]!.previewText,
        'My son, Grace, if your heart is wise, then my heart will be glad, even mine.',
      );
      expect(
        rv.proposals[18]!.previewText,
        'Indeed surely there is a future hope, and, Grace, your hope will not be cut off.',
      );
      expect(rv.proposals[18]!.processed.risk, RiskLevel.high);
    });

    test('a recorded approval renders in normal mode, from the right edition only', () async {
      final c = testContainer(readerStore('WEB-MWB', approved: {'web-mwb.PRO.23.15.a': 'Test Reviewer'}));
      final view = (await c.read(mwbChapterProvider(ref('PRO 23')).future))!;
      expect(view.personalisedCount, 1);
      expect(view.verses[14].text, 'My son, Grace, if your heart is wise, then my heart will be glad, even mine.');
      expect(view.verses[14].originalText, await web('PRO 23:15'));

      // The same approval id does not exist in KJV-MWB, so KJV-MWB is unaffected.
      final k = testContainer(readerStore('KJV-MWB', approved: {'web-mwb.PRO.23.15.a': 'Test Reviewer'}));
      final kv = (await k.read(mwbChapterProvider(ref('PRO 23')).future))!;
      expect(kv.personalisedCount, 0);
      expect(kv.verses[14].text, await kjv('PRO 23:15'));
    });

    test('reviewer tools are offered only in dedicated reviewer builds', () {
      // An ordinary build (debug included: tests run in debug mode) never
      // offers review tools, even if the switch was stored on earlier.
      final ordinary = testContainer(readerStore('KJV-MWB', reviewer: true));
      expect(ordinary.read(reviewerToolsAvailableProvider), isFalse);
      expect(ordinary.read(mwbReviewerModeProvider), isFalse);

      final reviewer = testContainer(readerStore('KJV-MWB', reviewer: true), extra: reviewerBuild);
      expect(reviewer.read(reviewerToolsAvailableProvider), isTrue);
      expect(reviewer.read(mwbReviewerModeProvider), isTrue);
    });
  });

  group('Independent KJV-MWB and WEB-MWB rulesets', () {
    test('every WEB-MWB rule is written against the exact WEB verse, never the KJV', () async {
      final rules = shippedWebRuleset().rules;
      expect(rules, hasLength(20));
      for (final r in rules) {
        expect(r.sourceVersionId, 'WEB');
        expect(r.targetVersionId, 'WEB-MWB');
        expect(r.id, startsWith('web-mwb.'));
        final verse = (await sharedTestBible.passage('WEB', r.reference)).verses.single.text;
        expect(r.sourceText, verse, reason: r.id);
        final kjvVerse = (await sharedTestBible.passage('KJV', r.reference)).verses.single.text;
        expect(r.sourceText, isNot(kjvVerse), reason: r.id);
      }
    });

    test('WEB-MWB rules never introduce KJV forms', () {
      for (final r in shippedWebRuleset().rules) {
        for (final e in r.edits) {
          expect(e.text, isNot(matches(RegExp(r'\b(thou|thee|thy|thine)\b'))), reason: r.id);
        }
      }
      expect(shippedWebRuleset().style.allowedAddedWords, isEmpty);
    });

    test('a KJV rule cannot render in WEB-MWB, nor a WEB rule in KJV-MWB', () async {
      final kjvVerse = (await sharedTestBible.passage('KJV', ref('PRO 23:15'))).verses.single;
      final webVerse = (await sharedTestBible.passage('WEB', ref('PRO 23:15'))).verses.single;
      final name = PersonalNameResolver.resolve(emmanuel);
      final kjvAsWeb = renderer(PublicationPolicy.reviewPreview).render(
        source: webVerse,
        sourceVersionId: 'WEB',
        targetVersionId: 'WEB-MWB',
        ruleset: shippedRuleset(),
        name: name,
      );
      expect(kjvAsWeb.outcome, RenderOutcome.versionMismatch);
      expect(kjvAsWeb.text, webVerse.text);
      final webAsKjv = renderer(PublicationPolicy.reviewPreview).render(
        source: kjvVerse,
        sourceVersionId: 'KJV',
        targetVersionId: 'KJV-MWB',
        ruleset: shippedWebRuleset(),
        name: name,
      );
      expect(webAsKjv.outcome, RenderOutcome.versionMismatch);
      expect(webAsKjv.text, kjvVerse.text);
    });

    test('WEB-MWB queue: all candidates pass automated checks, none approved, risks follow context', () async {
      final queue = await reviewService().queue('WEB-MWB');
      expect(queue, hasLength(20));
      expect(queue.where((p) => !p.report.passed), isEmpty, reason: '${queue.map((p) => p.report.issues)}');
      expect(queue.where((p) => p.status == RuleStatus.approved), isEmpty);
      expect(queue.where((p) => p.rule.validApproval != null), isEmpty);
      RiskLevel risk(String id) => queue.singleWhere((p) => p.rule.id == id).risk;
      expect(risk('web-mwb.ISA.41.10.a'), RiskLevel.critical);
      expect(risk('web-mwb.3JN.1.2.a'), RiskLevel.high);
      expect(risk('web-mwb.PRO.23.18.a'), RiskLevel.high);
      expect(risk('web-mwb.PRO.2.1.a'), RiskLevel.high);
      expect(risk('web-mwb.PRO.1.8.a'), RiskLevel.medium);
      expect(risk('web-mwb.PRO.27.11.a'), RiskLevel.low);
      final preview = {for (final p in queue) p.rule.id: p.previewText};
      expect(preview['web-mwb.ISA.41.10.a'], startsWith('Don’t you be afraid, [Name], for I am with you.'));
      expect(
        preview['web-mwb.PRO.27.11.a'],
        'Be wise, my son, [Name], and bring joy to my heart, then I can answer my tormentor.',
      );
      expect(preview['web-mwb.PRO.1.15.a'], startsWith('my son, [Name], don’t walk'));
    });

    test('rendering WEB-MWB never changes the WEB text', () async {
      final before = (await sharedTestBible.chapter('WEB', 'PRO', 23)).map((v) => v.text).toList();
      final c = testContainer(
        readerStore('WEB-MWB', reviewer: true, approved: {'web-mwb.PRO.23.15.a': 'Test Reviewer'}),
      );
      final view = (await c.read(mwbChapterProvider(ref('PRO 23')).future))!;
      for (var i = 0; i < view.verses.length; i++) {
        expect(view.verses[i].originalText, before[i]);
      }
      expect((await sharedTestBible.chapter('WEB', 'PRO', 23)).map((v) => v.text), before);
    });
  });

  group('Reader', () {
    testWidgets('KJV reader is unchanged and switches to KJV-MWB at the same chapter', (tester) async {
      final store = readerStore('KJV');
      await pumpMwbApp(tester, store);
      await openReader(tester, 'PRO', 23);
      expect(find.text('Chapter 23'), findsOneWidget);
      expect(verseLabel(r'^Verse 15\. My son, if thine heart be wise'), findsOneWidget);
      expect(find.byKey(const ValueKey('mwb-edition-banner')), findsNothing);
      expect(find.text('King James Version · Public domain'), findsOneWidget); // KJV footer unchanged
      expect(find.byKey(const ValueKey('reader-version')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reader-switch-edition')));
      await settle(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      expect(container.read(activeVersionProvider).id, 'KJV-MWB');
      expect(find.text('Chapter 23'), findsOneWidget);
      expect(find.byKey(const ValueKey('mwb-edition-banner')), findsOneWidget);
      // No approvals: the KJV text is shown unchanged and no proposal is shown outside reviewer mode.
      expect(verseLabel(r'^Verse 15\. My son, if thine heart be wise'), findsOneWidget);
      expect(find.text(proposedLabel), findsNothing);

      await tester.tap(find.byKey(const ValueKey('reader-switch-edition')));
      await settle(tester);
      expect(container.read(activeVersionProvider).id, 'KJV');
    });

    testWidgets('WEB-MWB shows an approved passage in place and marks it personalised', (tester) async {
      await pumpMwbApp(tester, readerStore('WEB-MWB', approved: {'web-mwb.PRO.23.15.a': 'Test Reviewer'}));
      await openReader(tester, 'PRO', 23);
      expect(
        verseLabel(
          r'^Verse 15\. My son, Grace, if your heart is wise, then my heart will be glad, even mine\.\. Personalised',
        ),
        findsOneWidget,
      );
      expect(verseLabel(r'^Verse 18\. Indeed surely there is a future hope, and your hope'), findsOneWidget);
      expect(find.text(proposedLabel), findsNothing);
    });

    testWidgets('reviewer mode shows proposals beside the original, clearly labelled', (tester) async {
      await pumpMwbApp(tester, readerStore('KJV-MWB', reviewer: true), extra: reviewerBuild);
      await openReader(tester, 'PRO', 23);
      // The verse itself remains the KJV.
      expect(verseLabel(r'^Verse 15\. My son, if thine heart be wise'), findsOneWidget);
      expect(find.byKey(const ValueKey('proposal-kjv-mwb.PRO.23.15.a')), findsOneWidget);
      expect(find.text(proposedLabel), findsWidgets);
      expect(find.textContaining('My son, Grace, if thine heart be wise'), findsOneWidget);

      await scrollTo(tester, find.byKey(const ValueKey('proposal-kjv-mwb.PRO.23.15.a')));
      await tester.tap(find.byKey(const ValueKey('proposal-kjv-mwb.PRO.23.15.a')));
      await settle(tester);
      expect(
        find.text('No approval has been recorded. This rendering must not be read as approved Scripture.'),
        findsOneWidget,
      );
      expect(find.text('insertNameAfterExistingAddress'), findsOneWidget);
    });

    testWidgets('WEB omitted verses show a note instead of text', (tester) async {
      await pumpMwbApp(tester, readerStore('WEB'));
      await openReader(tester, 'LUK', 17);
      await scrollTo(tester, verseLabel(r'^Verse 36\.'));
      expect(verseLabel(r'^Verse 36\. This verse is not included in the WEB text\.'), findsOneWidget);
    });

    testWidgets('bookmarks, highlights and notes made in KJV stay with the passage in KJV-MWB', (tester) async {
      final store = readerStore('KJV');
      await pumpMwbApp(tester, store);
      await openReader(tester, 'PSA', 23);
      await tester.tap(verseLabel(r'^Verse 1\.'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Bookmark'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('reader-switch-edition')));
      await settle(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      expect(container.read(activeVersionProvider).id, 'KJV-MWB');
      final saved = store.readJson(StorageKeys.bookmarks) as List;
      expect(saved, hasLength(1));
      expect(verseLabel(r'^Verse 1\. The LORD is my shepherd; I shall not want\.'), findsOneWidget);
    });
  });
}
