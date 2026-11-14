import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_word_bible/app/app.dart';
import 'package:my_word_bible/app/app_providers.dart';
import 'package:my_word_bible/app/app_router.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/data/local/personal_database.dart';
import 'package:my_word_bible/data/models/library_items.dart';
import 'package:my_word_bible/data/models/personal_rhythm.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/repositories/personal_repositories.dart';
import 'package:my_word_bible/features/daily_word/application/daily_word_providers.dart';
import 'package:my_word_bible/features/fellowship/application/journal_export.dart';
import 'package:my_word_bible/features/fellowship/application/personal_providers.dart';
import 'package:my_word_bible/features/social/application/social_providers.dart';

import '../daily_word/daily_word_test_support.dart';
import '../helpers/test_app.dart';
import 'f1_test_support.dart';

ProviderContainer _c(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(MwbApp)));
GoRouter _router(WidgetTester tester) => _c(tester).read(appRouterProvider);
RhythmRepository _rhythm(WidgetTester tester) => _c(tester).read(rhythmRepositoryProvider)!;
JournalRepository _journal(WidgetTester tester) => _c(tester).read(journalRepositoryProvider)!;

Future<void> _go(WidgetTester tester, String route, {bool push = true}) async {
  push ? _router(tester).push(route) : _router(tester).go(route);
  await settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await settle(tester);
  await tester.tap(f);
  await settle(tester);
}

Future<void> _type(WidgetTester tester, String fieldKey, String text) async {
  await tester.enterText(find.descendant(of: find.byKey(Key(fieldKey)), matching: find.byType(EditableText)), text);
  await tester.pump();
}

Finder _verse(int n) =>
    find.byWidgetPredicate((w) => w is Semantics && RegExp('^Verse $n\\.').hasMatch(w.properties.label ?? ''));

InMemoryKeyValueStore _store({String version = 'KJV'}) =>
    onboardedStore()..writeJson(StorageKeys.readingPreferences, {'versionId': version});

void main() {
  group('Personal Word Rhythm in the app', () {
    testWidgets('opening a chapter records nothing; Complete reading records it once; Undo removes it', (tester) async {
      await pumpMwbApp(tester, _store());
      await _go(tester, '/read/JHN/3');
      await scrollTo(tester, find.byKey(const Key('reader.completionPanel')));
      expect(_rhythm(tester).completedReadings(), isEmpty, reason: 'opening and scrolling count for nothing');

      await _tapKey(tester, 'reader.completeReading');
      final done = _rhythm(tester).completedReadings();
      expect(done.single.reference, const ScriptureReference(bookId: 'JHN', chapter: 3));
      expect(done.single.versionId, 'KJV');
      expect(find.byKey(const Key('reader.readingCompleted')), findsOneWidget);
      expect(find.byKey(const Key('reader.completeReading')), findsNothing, reason: 'no second completion today');

      await _tapKey(tester, 'reader.undoCompletion');
      expect(_rhythm(tester).completedReadings(), isEmpty);
      expect(find.byKey(const Key('reader.completeReading')), findsOneWidget);
    });

    testWidgets('a personalised edition records its canonical translation', (tester) async {
      await pumpMwbApp(tester, _store(version: 'KJV-MWB'));
      await _go(tester, '/read/ROM/8');
      await scrollTo(tester, find.byKey(const Key('reader.completeReading')));
      await _tapKey(tester, 'reader.completeReading');
      expect(_rhythm(tester).completedReadings().single.versionId, 'KJV');
    });

    testWidgets('a session started from Word rhythm is completed in the reader', (tester) async {
      await pumpMwbApp(tester, _store());
      await _go(tester, '/rhythm');
      await _tapKey(tester, 'rhythm.startSession');
      await tester.tap(find.text('John 1'));
      await settle(tester);
      final session = _rhythm(tester).activeSession()!;
      expect(session.chapter, const ScriptureReference(bookId: 'JHN', chapter: 1));
      expect(session.origin, PersonalOrigin.rhythm);

      await scrollTo(tester, find.byKey(const Key('reader.completeReading')));
      expect(find.textContaining('Reading session · started'), findsOneWidget);
      await _tapKey(tester, 'reader.completeReading');
      expect(_rhythm(tester).completedReadings().single.sessionId, session.id);
      expect(_rhythm(tester).activeSession(), isNull);
    });

    testWidgets('Home and Word rhythm show a calm weekly summary and history', (tester) async {
      await pumpMwbApp(tester, _store());
      await scrollTo(tester, find.byKey(const Key('home.rhythm')));
      expect(find.byKey(const Key('home.rhythm')), findsOneWidget);
      expect(find.text('Begin a reading session whenever you are ready'), findsOneWidget);

      _c(tester)
          .read(personalActionsProvider)
          .completeReading(
            const ScriptureReference(bookId: 'PSA', chapter: 23),
            versionId: 'KJV',
            origin: PersonalOrigin.reader,
          );
      await settle(tester);
      expect(find.text('1 reading completed'), findsOneWidget);

      await _go(tester, '/rhythm');
      expect(find.byKey(const Key('rhythm.week')), findsOneWidget);
      expect(find.byKey(const Key('rhythm.day.2026-11-10')), findsOneWidget);
      final reading = _rhythm(tester).completedReadings().single;
      await scrollTo(tester, find.byKey(Key('rhythm.reading.${reading.id}')));
      expect(find.byKey(Key('rhythm.reading.${reading.id}')), findsOneWidget);
      for (final banned in ['streak', 'Streak', 'score', 'missed', 'Missed', 'failed']) {
        expect(find.textContaining(banned), findsNothing, reason: 'no "$banned" wording');
      }
    });

    testWidgets('the reader menu starts a session for the open chapter', (tester) async {
      await pumpMwbApp(tester, _store());
      await _go(tester, '/read/ROM/12');
      await tester.tap(find.byKey(const ValueKey('reader-more')));
      await settle(tester);
      await tester.tap(find.text('Start reading session'));
      await settle(tester);
      expect(_rhythm(tester).activeSession()!.chapter, const ScriptureReference(bookId: 'ROM', chapter: 12));
    });
  });

  group('Private Reflection Journal in the app', () {
    testWidgets('Reflect from a reader selection links the canonical reference', (tester) async {
      await pumpMwbApp(tester, _store(version: 'KJV-MWB'));
      await _go(tester, '/read/JHN/3?v=16');
      await scrollTo(tester, _verse(16));
      await tester.tap(_verse(16));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Reflect'));
      await settle(tester);

      expect(find.byKey(const Key('reflection.scripture')), findsOneWidget);
      expect(
        find.textContaining('For God so loved the world'),
        findsOneWidget,
        reason: 'canonical text shown as Scripture',
      );
      await _type(tester, 'reflection.body', 'Loved, even me.');
      await _tapKey(tester, 'reflection.save');

      final e = _journal(tester).search(const JournalQuery()).single;
      expect(e.reference, const ScriptureReference(bookId: 'JHN', chapter: 3, verseStart: 16));
      expect(e.versionId, 'KJV');
      expect(e.source, PersonalOrigin.reader);
      expect(e.body, 'Loved, even me.');

      await _go(tester, '/library', push: false);
      await scrollTo(tester, find.byKey(const Key('library.reflections')));
      expect(find.byKey(Key('journal.entry.${e.id}')), findsOneWidget);
    });

    testWidgets('Reflect from the Daily Word records the date and passage', (tester) async {
      final store = _store();
      final candidate = shippedCatalogue().candidates.firstWhere(
        (x) => x.reference == const ScriptureReference(bookId: 'PSA', chapter: 91, verseStart: 11),
      );
      await testContainer(store).read(dailyWordHistoryProvider.notifier).deliver(entryFor(fixedNow, candidate));
      await pumpMwbApp(tester, store);
      await _go(tester, '/daily-word');
      await _tapKey(tester, 'dailyWord.reflect');
      await _type(tester, 'reflection.body', 'Kept by angels');
      await _tapKey(tester, 'reflection.save');
      final e = _journal(tester).search(const JournalQuery()).single;
      expect(e.source, PersonalOrigin.dailyWord);
      expect(e.dailyWordDate, '2026-11-10');
      expect(e.reference, candidate.reference);
    });

    testWidgets('Saved Scripture offers a linked reflection', (tester) async {
      final store = _store();
      const ref = ScriptureReference(bookId: 'ROM', chapter: 8, verseStart: 37);
      await store.writeList(StorageKeys.savedScripture, [
        SavedScripture(reference: ref, versionId: 'KJV', savedAt: fixedNow),
      ], (s) => s.toJson());
      await pumpMwbApp(tester, store);
      await _go(tester, '/library', push: false);
      await _tapKey(tester, 'saved.reflect.${ref.key}');
      await _type(tester, 'reflection.body', 'More than a conqueror');
      await _tapKey(tester, 'reflection.save');
      final e = _journal(tester).search(const JournalQuery()).single;
      expect(e.source, PersonalOrigin.savedScripture);
      expect(e.reference, ref);
      _router(tester).pop();
      await settle(tester);
      expect(find.text('1 reflection'), findsOneWidget);
    });

    testWidgets('independent reflection: create, link, edit and delete', (tester) async {
      await pumpMwbApp(tester, _store());
      await _go(tester, '/journal');
      await _tapKey(tester, 'journal.new');
      await _type(tester, 'reflection.title', 'Evening');
      await _type(tester, 'reflection.body', 'Thankful for quiet');
      await _tapKey(tester, 'reflection.link');
      await _type(tester, 'reflection.referenceInput', 'Psalm 4:8');
      await _tapKey(tester, 'reflection.referenceApply');
      await _tapKey(tester, 'reflection.save');
      var e = _journal(tester).search(const JournalQuery()).single;
      expect(e.title, 'Evening');
      expect(e.source, PersonalOrigin.independent);
      expect(e.reference, const ScriptureReference(bookId: 'PSA', chapter: 4, verseStart: 8));

      await _type(tester, 'reflection.body', 'Thankful for quiet sleep');
      await _tapKey(tester, 'reflection.save');
      e = _journal(tester).byId(e.id)!;
      expect(e.body, 'Thankful for quiet sleep');

      await _tapKey(tester, 'reflection.delete');
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(_journal(tester).count(), 0);
    });

    testWidgets('the journal screen searches and filters', (tester) async {
      await pumpMwbApp(tester, _store());
      final actions = _c(tester).read(personalActionsProvider);
      await actions.createReflection(
        const JournalDraft(body: 'Peace in the storm', source: PersonalOrigin.independent),
      );
      await actions.createReflection(
        const JournalDraft(
          body: 'Still waters',
          reference: ScriptureReference(bookId: 'PSA', chapter: 23, verseStart: 2),
          versionId: 'KJV',
          source: PersonalOrigin.reader,
        ),
      );
      await _go(tester, '/journal');
      expect(find.text('2 reflections'), findsOneWidget);

      await tester.enterText(
        find.descendant(of: find.byKey(const Key('journal.search')), matching: find.byType(EditableText)),
        'storm',
      );
      await settle(tester);
      expect(find.text('Peace in the storm'), findsOneWidget);
      expect(find.text('Still waters'), findsNothing);

      await tester.enterText(
        find.descendant(of: find.byKey(const Key('journal.search')), matching: find.byType(EditableText)),
        '',
      );
      await settle(tester);
      await _tapKey(tester, 'journal.filter.linked');
      expect(find.text('Still waters'), findsOneWidget);
      expect(find.text('Peace in the storm'), findsNothing);
      await _tapKey(tester, 'journal.filter.all');
      await _tapKey(tester, 'journal.filter.independent');
      expect(find.text('Peace in the storm'), findsOneWidget);
      expect(find.text('Still waters'), findsNothing);
    });

    testWidgets('export: a warning first, then a file through the share sheet only', (tester) async {
      final exports = FakeJournalExportService();
      final share = FakeShareService();
      final store = _store();
      await pumpMwbApp(
        tester,
        store,
        extra: [journalExportServiceProvider.overrideWithValue(exports), shareServiceProvider.overrideWithValue(share)],
      );
      await _c(tester)
          .read(personalActionsProvider)
          .createReflection(const JournalDraft(title: 'Fear', body: secretSentence));
      await _go(tester, '/journal');
      await _tapKey(tester, 'journal.export');
      expect(find.textContaining('not encrypted'), findsWidgets);
      await _tapKey(tester, 'journal.export.json');

      final file = exports.files.single;
      expect(file.mimeType, 'application/json');
      expect(file.fileName, 'my-word-bible-reflections-2026-11-10.json');
      final json = jsonDecode(utf8.decode(file.bytes)) as Map<String, dynamic>;
      expect(json['format'], JournalExporter.formatId);
      expect((json['entries'] as List).single['body'], secretSentence);
      expect(share.texts, isEmpty);
      expect(share.images, isEmpty);
    });
  });

  group('Profile privacy controls', () {
    testWidgets('journal privacy explains protection and deletes on request', (tester) async {
      await pumpMwbApp(tester, _store());
      final actions = _c(tester).read(personalActionsProvider);
      await actions.createReflection(const JournalDraft(body: 'one'));
      actions.completeReading(
        const ScriptureReference(bookId: 'JHN', chapter: 1),
        versionId: 'KJV',
        origin: PersonalOrigin.reader,
      );
      await _go(tester, '/profile/journal', push: false);
      expect(find.text('Encrypted on this device'), findsNothing, reason: 'tests use an unencrypted in-memory store');
      expect(find.byKey(const Key('journalPrivacy.status')), findsOneWidget);
      await scrollTo(tester, find.textContaining('cannot be recovered by anyone'));
      expect(find.textContaining('cannot be recovered by anyone'), findsOneWidget);

      await _tapKey(tester, 'journalPrivacy.deleteReflections');
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(_journal(tester).count(), 0);
      expect(_rhythm(tester).readingCount(), 1, reason: 'readings are separate');

      await _tapKey(tester, 'journalPrivacy.deleteReadings');
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(_rhythm(tester).readingCount(), 0);
    });

    testWidgets('Profile lists Word rhythm, Reflections and Journal privacy; still five tabs', (tester) async {
      await pumpMwbApp(tester, _store());
      await _go(tester, '/profile', push: false);
      for (final t in ['Word rhythm', 'Reflections', 'Journal privacy']) {
        await scrollTo(tester, find.text(t));
        expect(find.text(t), findsWidgets);
      }
      for (final tab in ['Home', 'Bible', 'Discover', 'Library', 'Profile']) {
        expect(find.text(tab), findsWidgets);
      }
    });
  });

  group('Resilience and rollback', () {
    for (final failure in [PersonalStoreFailure.keyLost, PersonalStoreFailure.keyStoreUnavailable]) {
      testWidgets('with the private store unavailable (${failure.name}) the rest of the app works', (tester) async {
        await pumpMwbApp(tester, _store(), personalStore: () async => PersonalStoreUnavailable(failure));
        expect(find.byKey(const Key('home.rhythm')), findsNothing);
        expect(tester.takeException(), isNull);

        await _go(tester, '/read/JHN/3');
        expect(find.textContaining('For God so loved the world'), findsOneWidget);
        expect(find.byKey(const Key('reader.completionPanel')), findsNothing);
        _router(tester).pop();
        await settle(tester);

        await _go(tester, '/journal');
        expect(
          find.byKey(Key(failure == PersonalStoreFailure.keyLost ? 'personal.keyLost' : 'personal.unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('personal.startAgain')),
          failure == PersonalStoreFailure.keyLost ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('existing user data is untouched by F1 (migration safety)', (tester) async {
      final store = _store();
      const ref = ScriptureReference(bookId: 'PSA', chapter: 23);
      await store.writeList(StorageKeys.readingHistory, [
        ReadingHistoryEntry(reference: ref, versionId: 'KJV', readAt: fixedNow),
      ], (h) => h.toJson());
      await store.writeList(StorageKeys.savedScripture, [
        SavedScripture(
          reference: const ScriptureReference(bookId: 'ROM', chapter: 8, verseStart: 28),
          versionId: 'KJV',
          savedAt: fixedNow,
        ),
      ], (s) => s.toJson());
      await store.writeList(StorageKeys.notes, [
        VerseNote(id: 'n1', reference: ref, text: 'my note', createdAt: fixedNow, updatedAt: fixedNow),
      ], (n) => n.toJson());
      await store.setString(StorageKeys.themeId, MwbThemeId.values.last.storageKey);
      await store.setBool(StorageKeys.mwbReviewerMode, false);
      final before = Map<String, Object>.of(store.snapshot);

      await pumpMwbApp(tester, store);
      final actions = _c(tester).read(personalActionsProvider);
      actions.completeReading(ref, versionId: 'KJV', origin: PersonalOrigin.reader);
      await actions.createReflection(const JournalDraft(body: secretSentence, reference: ref, versionId: 'KJV'));
      actions.startSession(
        const ScriptureReference(bookId: 'JHN', chapter: 1),
        versionId: 'KJV',
        origin: PersonalOrigin.rhythm,
      );
      await settle(tester);

      for (final k in before.keys) {
        expect(store.snapshot[k], before[k], reason: '$k must be unchanged');
      }
      for (final entry in store.snapshot.entries) {
        expect('${entry.value}', isNot(contains('hospital')), reason: '${entry.key} must not hold reflection text');
        expect(entry.key, isNot(contains('personal_db')), reason: 'the key never goes to SharedPreferences');
      }
    });
  });

  group('Privacy isolation', () {
    testWidgets('reflections reach no share, notification or social store', (tester) async {
      final share = FakeShareService();
      final store = _store();
      await pumpMwbApp(tester, store, extra: [shareServiceProvider.overrideWithValue(share)]);
      final c = _c(tester);
      await c.read(personalActionsProvider).createReflection(const JournalDraft(body: secretSentence));
      await _go(tester, '/journal');
      await _go(tester, '/rhythm');
      expect(share.texts, isEmpty);
      expect(share.images, isEmpty);
      expect(c.read(notificationsProvider), isEmpty);
      expect(c.read(sentSharesProvider), isEmpty);
      expect(store.snapshot.values.join(), isNot(contains('hospital results')));
    });

    test('F1 code has no network, notification, social or analytics dependencies', () {
      final files = [
        ...Directory('lib/features/fellowship').listSync(recursive: true).whereType<File>(),
        File('lib/data/local/personal_database.dart'),
        File('lib/data/repositories/personal_repositories.dart'),
        File('lib/data/models/personal_rhythm.dart'),
      ];
      for (final f in files) {
        final imports = f.readAsLinesSync().where((l) => l.startsWith('import ')).join('\n');
        for (final banned in ['dio', 'api_client', 'notification', 'social', 'analytics', 'firebase', 'http']) {
          expect(imports, isNot(contains(banned)), reason: '${f.path} imports $banned');
        }
      }
      // Only the export service touches the share sheet, and only for a user-chosen export.
      final sharers = files
          .where((f) => f.readAsStringSync().contains('share_plus'))
          .map((f) => f.path.replaceAll('\\', '/'));
      expect(sharers, ['lib/features/fellowship/application/journal_export.dart']);
    });
  });

  group('Themes', () {
    testWidgets('F1 screens build in all seven themes, light and dark', (tester) async {
      for (final theme in MwbThemeId.values) {
        for (final mode in ['light', 'dark']) {
          final store = _store();
          await store.setString(StorageKeys.themeId, theme.storageKey);
          await store.setString(StorageKeys.themeMode, mode);
          await pumpMwbApp(tester, store);
          final e = await _c(tester)
              .read(personalActionsProvider)
              .createReflection(
                const JournalDraft(
                  body: 'Theme check',
                  reference: ScriptureReference(bookId: 'PSA', chapter: 23, verseStart: 1),
                  versionId: 'KJV',
                ),
              );
          for (final route in ['/rhythm', '/journal', '/journal/new', '/journal/e/${e.id}', '/profile/journal']) {
            _router(tester).go(route);
            await settle(tester);
            expect(tester.takeException(), isNull, reason: '${theme.name}/$mode $route');
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  });
}
