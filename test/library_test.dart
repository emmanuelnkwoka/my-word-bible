import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/mock/mock_content.dart';
import 'package:my_word_bible/data/models/library_items.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/features/bible/presentation/reader_screen.dart';
import 'package:my_word_bible/features/library/application/library_controllers.dart';
import 'package:my_word_bible/features/library/presentation/note_editor.dart';

import 'helpers/test_app.dart';

void main() {
  final john316 = ScriptureReference.parseCompact('JHN 3:16');
  final psalm23 = ScriptureReference.parseCompact('PSA 23');

  group('Bookmarks', () {
    test('toggle adds and removes, and persists across restarts', () async {
      final store = InMemoryKeyValueStore();
      final c = testContainer(store);
      final ctrl = c.read(bookmarksProvider.notifier);

      expect(await ctrl.toggle(john316), isTrue);
      expect(await ctrl.toggle(psalm23), isTrue);
      expect(c.read(bookmarksProvider).map((b) => b.reference), [psalm23, john316]);
      expect(store.getString(StorageKeys.bookmarks), isNotNull);

      final restarted = testContainer(store);
      expect(restarted.read(bookmarksProvider).map((b) => b.reference), [psalm23, john316]);

      expect(await restarted.read(bookmarksProvider.notifier).toggle(john316), isFalse);
      expect(testContainer(store).read(bookmarksProvider).map((b) => b.reference), [psalm23]);
    });

    test('adding the same bookmark twice does not duplicate', () async {
      final c = testContainer(InMemoryKeyValueStore());
      await c.read(bookmarksProvider.notifier).add(john316);
      await c.read(bookmarksProvider.notifier).add(john316);
      expect(c.read(bookmarksProvider), hasLength(1));
    });

    test('corrupt stored data is ignored safely', () {
      final store = InMemoryKeyValueStore({StorageKeys.bookmarks: '{not json'});
      expect(testContainer(store).read(bookmarksProvider), isEmpty);
    });
  });

  group('Notes and highlights', () {
    test('notes can be created, edited and deleted, and persist', () async {
      final store = InMemoryKeyValueStore();
      final c = testContainer(store);
      final note = await c.read(notesProvider.notifier).addNote(john316, '  God’s love is personal.  ');
      expect(note.text, 'God’s love is personal.');

      await c.read(notesProvider.notifier).updateNote(note.id, 'Edited');
      final restarted = testContainer(store);
      expect(restarted.read(notesProvider).single.text, 'Edited');
      expect(restarted.read(chapterNotesProvider(john316.chapterOnly)), {16});

      await restarted.read(notesProvider.notifier).deleteNote(note.id);
      expect(testContainer(store).read(notesProvider), isEmpty);
    });

    test('note validation', () {
      expect(validateNote(''), isNotNull);
      expect(validateNote('   '), isNotNull);
      expect(validateNote('x' * 2001), isNotNull);
      expect(validateNote('A thought'), isNull);
    });

    test('highlights replace tone per verse and can be removed', () async {
      final c = testContainer(InMemoryKeyValueStore());
      final v1 = ScriptureReference.parseCompact('PSA 23:1');
      final v2 = ScriptureReference.parseCompact('PSA 23:2');
      await c.read(highlightsProvider.notifier).setTone([v1, v2], HighlightTone.gold);
      await c.read(highlightsProvider.notifier).setTone([v1], HighlightTone.sky);
      expect(c.read(chapterHighlightsProvider(psalm23)), {1: HighlightTone.sky, 2: HighlightTone.gold});
      await c.read(highlightsProvider.notifier).removeAll([v1]);
      expect(c.read(chapterHighlightsProvider(psalm23)), {2: HighlightTone.gold});
    });

    test('verse selection groups into contiguous references', () {
      final refs = groupSelection('JHN', 3, {18, 16, 17, 20});
      expect(refs.map((r) => r.label), ['John 3:16–18', 'John 3:20']);
    });
  });

  group('Saved content, collections and history', () {
    test('save and remove content', () async {
      final store = InMemoryKeyValueStore();
      final c = testContainer(store);
      final item = mockContent.first;
      expect(await c.read(savedContentProvider.notifier).toggle(item), isTrue);
      expect(c.read(isContentSavedProvider(item.id)), isTrue);
      expect(testContainer(store).read(savedContentIdsProvider), {item.id});
      expect(await c.read(savedContentProvider.notifier).toggle(item), isFalse);
      expect(c.read(isContentSavedProvider(item.id)), isFalse);
    });

    test('collections: create, add, rename, delete', () async {
      final c = testContainer(InMemoryKeyValueStore());
      final ctrl = c.read(collectionsProvider.notifier);
      final col = await ctrl.create(' Prayer series ');
      expect(col.name, 'Prayer series');
      await ctrl.toggleItem(col.id, 'a-prayer-lords');
      expect(c.read(collectionsProvider).single.contentIds, ['a-prayer-lords']);
      await ctrl.toggleItem(col.id, 'a-prayer-lords');
      expect(c.read(collectionsProvider).single.contentIds, isEmpty);
      await ctrl.rename(col.id, 'Renamed');
      expect(c.read(collectionsProvider).single.name, 'Renamed');
      await ctrl.delete(col.id);
      expect(c.read(collectionsProvider), isEmpty);
    });

    test('reading history de-duplicates and caps entries', () async {
      final c = testContainer(InMemoryKeyValueStore());
      final h = c.read(readingHistoryProvider.notifier);
      await h.record(john316);
      await h.record(psalm23);
      await h.record(ScriptureReference.parseCompact('JHN 3'));
      expect(c.read(readingHistoryProvider).map((e) => e.reference.label), ['John 3', 'Psalms 23']);
      for (var i = 1; i <= 60; i++) {
        await h.record(ScriptureReference(bookId: 'PSA', chapter: i));
      }
      expect(c.read(readingHistoryProvider), hasLength(ReadingHistoryController.maxEntries));
    });

    test('recent searches keep the newest ten without duplicates', () async {
      final c = testContainer(InMemoryKeyValueStore());
      final r = c.read(recentSearchesProvider.notifier);
      for (var i = 0; i < 12; i++) {
        await r.add('query $i');
      }
      await r.add('QUERY 5');
      final list = c.read(recentSearchesProvider);
      expect(list, hasLength(10));
      expect(list.first, 'QUERY 5');
      expect(list.where((q) => q.toLowerCase() == 'query 5'), hasLength(1));
    });

    test('clear library removes every list', () async {
      final store = onboardedStore();
      final c = testContainer(store);
      await c.read(bookmarksProvider.notifier).add(john316);
      await c.read(savedContentProvider.notifier).toggle(mockContent.first);
      await c.read(libraryActionsProvider).clearLibrary();
      expect(c.read(bookmarksProvider), isEmpty);
      expect(c.read(savedContentProvider), isEmpty);
      // Profile is not part of the library.
      expect(store.getBool(StorageKeys.onboardingComplete), isTrue);
    });
  });

  group('Library UI', () {
    testWidgets('saving content from detail shows it in the Library and removing works', (tester) async {
      final store = onboardedStore();
      await pumpMwbApp(tester, store);
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

      await tester.tap(find.text('Library').last);
      await settle(tester);
      await tester.tap(find.text('Media'));
      await settle(tester);
      expect(find.text('Save audio messages to listen again.'), findsOneWidget);

      await container.read(savedContentProvider.notifier).toggle(mockContent.first);
      await settle(tester);
      expect(find.text(mockContent.first.title), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from library').first);
      await settle(tester);
      expect(find.text(mockContent.first.title), findsNothing);
      expect(container.read(savedContentProvider), isEmpty);
    });
  });
}
