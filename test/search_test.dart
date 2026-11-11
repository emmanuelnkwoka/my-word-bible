import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/widgets/section_heading.dart';
import 'package:my_word_bible/data/mock/mock_content.dart';
import 'package:my_word_bible/data/models/content.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/models/search.dart';
import 'package:my_word_bible/data/repositories/content_repository.dart';
import 'package:my_word_bible/data/repositories/search_repository.dart';
import 'package:my_word_bible/features/discovery/application/discover_filter.dart';
import 'package:my_word_bible/features/library/application/library_controllers.dart';

import 'helpers/test_app.dart';

void main() {
  group('Reference parsing', () {
    test('recognises common reference forms', () {
      expect(ScriptureReference.tryParse('John 3:16')!.key, 'JHN.3.16-16');
      expect(ScriptureReference.tryParse('jn 3:16')!.bookId, 'JHN');
      expect(ScriptureReference.tryParse('1 Cor 13')!.bookId, '1CO');
      expect(ScriptureReference.tryParse('1cor 13:4-7')!.verseEnd, 7);
      expect(ScriptureReference.tryParse('Psalm 23')!.isWholeChapter, isTrue);
      expect(ScriptureReference.tryParse('ps 23:1')!.bookId, 'PSA');
      expect(ScriptureReference.tryParse('Phil 4:6–7')!.verseEnd, 7);
      expect(ScriptureReference.tryParse('revelation 22')!.bookId, 'REV');
      expect(ScriptureReference.tryParse('Song of Solomon 2:4')!.bookId, 'SNG');
    });

    test('rejects non-references and impossible chapters', () {
      expect(ScriptureReference.tryParse('fear'), isNull);
      expect(ScriptureReference.tryParse('John'), isNull);
      expect(ScriptureReference.tryParse('John 22'), isNull);
      expect(ScriptureReference.tryParse('Jude 2'), isNull);
      expect(ScriptureReference.tryParse('John 3:5-2'), isNull);
      expect(ScriptureReference.tryParse('Hezekiah 1'), isNull);
    });

    test('labels and JSON round-trip', () {
      final r = ScriptureReference.parseCompact('PSA 23:1');
      expect(r.label, 'Psalm 23:1');
      expect(ScriptureReference.parseCompact('PSA 23').label, 'Psalms 23');
      expect(ScriptureReference.parseCompact('PHP 4:6-7').label, 'Philippians 4:6–7');
      expect(ScriptureReference.fromJson(r.toJson()), r);
    });
  });

  group('Unified local search', () {
    final repo = LocalSearchRepository(sharedTestBible, MockContentRepository(latency: Duration.zero));

    test('"fear" brings Scripture, topics, audio and video together', () async {
      final r = await repo.search('fear', versionId: 'KJV');
      expect(r.reference, isNull);
      expect(r.verses, isNotEmpty);
      expect(r.topics.map((t) => t.id), contains('fear'));
      expect(r.ofType(ContentType.audio), isNotEmpty);
      expect(r.ofType(ContentType.video), isNotEmpty);
      expect(r.ofType(ContentType.article), isNotEmpty);
      expect(r.countFor(SearchCategory.all), r.totalCount);
    });

    test('topic keywords match content even without the word in the title', () async {
      final r = await repo.search('anxious', versionId: 'KJV');
      expect(r.topics.map((t) => t.id), containsAll(['fear', 'anxiety']));
      expect(r.content.any((c) => c.id == 'a-fear-night'), isTrue);
    });

    test('a reference query returns the passage', () async {
      final r = await repo.search('John 3:16', versionId: 'KJV');
      expect(r.reference, ScriptureReference.parseCompact('JHN 3:16'));
      expect(r.referencePassage!.text, startsWith('For God so loved the world'));
      expect(r.countFor(SearchCategory.scripture), 1);
    });

    test('creator search and saved filter', () async {
      final r = await repo.search('Ruth', versionId: 'KJV', savedContentIds: {'a-prayer-lords'});
      expect(r.creators.map((c) => c.id), contains('ruth-adeyemi'));
      expect(r.saved.map((c) => c.id), contains('a-prayer-lords'));
    });

    test('empty and no-result queries', () async {
      expect((await repo.search('   ', versionId: 'KJV')).isEmpty, isTrue);
      expect((await repo.search('zzqxw', versionId: 'KJV')).isEmpty, isTrue);
    });
  });

  group('Discovery filters', () {
    test('applyFilter keeps only the chosen type', () {
      for (final f in ContentFilter.values) {
        final out = applyFilter(mockContent, f);
        if (f.type == null) {
          expect(out, hasLength(mockContent.length));
        } else {
          expect(out, isNotEmpty);
          expect(out.every((c) => c.type == f.type), isTrue);
        }
      }
    });

    testWidgets('Discover filter chips change the visible sections', (tester) async {
      await pumpMwbApp(tester, onboardedStore());
      await tester.tap(find.text('Discover').last);
      await settle(tester);
      expect(find.text('Featured resources'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('discover.filter.audio')));
      await tester.tap(find.byKey(const Key('discover.filter.audio')));
      await settle(tester);
      // Only audio cards remain in the featured carousel.
      expect(find.text('FEATURED AUDIO'), findsWidgets);
      expect(find.text('FEATURED VIDEO'), findsNothing);
      expect(find.text('FEATURED ARTICLE'), findsNothing);
    });

    testWidgets('topic page for Fear shows mixed content and filters by type', (tester) async {
      await pumpMwbApp(tester, onboardedStore());
      await tester.tap(find.text('Discover').last);
      await settle(tester);
      await scrollTo(tester, find.byKey(const Key('topic.fear')));
      await tester.tap(find.byKey(const Key('topic.fear')));
      await settle(tester);

      expect(find.text('What the Bible says'), findsOneWidget);
      expect(find.textContaining('ISAIAH 41:10'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('topic.filter.video')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('topic.filter.video')));
      await settle(tester);
      expect(find.text('What the Bible says'), findsNothing);
      expect(find.text('Video excerpts'), findsOneWidget);
      expect(find.text('Audio messages'), findsNothing);
    });

    testWidgets('search screen finds results and records recent searches', (tester) async {
      final store = onboardedStore();
      await pumpMwbApp(tester, store);
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'fear');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      expect(find.byKey(const Key('search.category.audio')), findsOneWidget);
      expect(find.widgetWithText(MwbSectionHeading, 'Audio'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('search.category.video')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('search.category.video')));
      await settle(tester);
      // Only the Video section remains; category chips stay visible.
      expect(find.widgetWithText(MwbSectionHeading, 'Video'), findsOneWidget);
      expect(find.widgetWithText(MwbSectionHeading, 'Audio'), findsNothing);
      expect(find.widgetWithText(MwbSectionHeading, 'Scripture'), findsNothing);

      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      expect(container.read(recentSearchesProvider), contains('fear'));
    });
  });
}
