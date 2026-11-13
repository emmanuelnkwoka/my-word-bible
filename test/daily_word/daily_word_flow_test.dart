import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/app/app_providers.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/data/models/daily_word.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/features/daily_word/application/daily_word_providers.dart';
import 'package:my_word_bible/features/library/application/library_controllers.dart';
import 'package:my_word_bible/features/profile/application/profile_controllers.dart';
import 'package:my_word_bible/features/share/scripture_card_renderer.dart';
import 'package:my_word_bible/features/share/share_service.dart';

import '../helpers/test_app.dart';
import 'daily_word_test_support.dart';

ScriptureReference ref(String s) => ScriptureReference.parseCompact(s);

/// Brings an action into view, taps it and clears any snackbar it shows.
Future<void> tapAction(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await settle(tester);
  await tester.tap(f);
  await settle(tester);
  final messenger = find.byType(ScaffoldMessenger);
  if (messenger.evaluate().isNotEmpty) tester.state<ScaffoldMessengerState>(messenger.first).removeCurrentSnackBar();
  await settle(tester);
}

/// Opens the full Daily Word from the Home card's title.
Future<void> openDailyWord(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('home.dailyWord')), matching: find.byKey(const Key('dailyWord.title'))));
  await settle(tester);
}

void main() {
  final today = dateKeyOf(fixedNow);

  group('Delivery and history (offline, local storage)', () {
    test('today\'s word is chosen once, stored, and stable after a restart', () async {
      final store = onboardedStore();
      final c1 = testContainer(store);
      final first = await c1.read(dailyWordForDateProvider(today).future);
      expect(first.dateKey, today);
      expect(first.scheduleVersion, '2026.1');
      expect(first.versionId, 'KJV');

      // New signals today do not change today's word.
      await c1.read(relevanceSignalsProvider.notifier).recordSearch('family household children');
      c1.invalidate(dailyWordForDateProvider(today));
      expect((await c1.read(dailyWordForDateProvider(today).future)).candidateId, first.candidateId);

      // "Restart": a new container over the same device storage.
      final c2 = testContainer(store);
      final again = await c2.read(dailyWordForDateProvider(today).future);
      expect(again.candidateId, first.candidateId);
      expect(again.deliveredAt, first.deliveredAt);
      expect(c2.read(dailyWordHistoryProvider), hasLength(1), reason: 'no duplicate entry');
    });

    test('opening the same word repeatedly never duplicates history', () async {
      final c = testContainer(onboardedStore());
      for (var i = 0; i < 5; i++) {
        c.invalidate(dailyWordForDateProvider(today));
        await c.read(dailyWordForDateProvider(today).future);
        await c.read(dailyWordHistoryProvider.notifier).markOpened(today, fixedNow);
      }
      expect(c.read(dailyWordHistoryProvider), hasLength(1));
      expect(c.read(dailyWordHistoryProvider).single.openedAt, fixedNow);
    });

    test('history is kept newest first and earlier deliveries are never overwritten', () async {
      final c = testContainer(onboardedStore());
      for (final k in ['2026-11-08', '2026-11-10', '2026-11-09']) {
        await c.read(dailyWordForDateProvider(k).future);
      }
      final h = c.read(dailyWordHistoryProvider);
      expect(h.map((e) => e.dateKey), ['2026-11-10', '2026-11-09', '2026-11-08']);
      final original = h.last;
      final replacement = entryFor(DateTime(2026, 11, 8), shippedCatalogue().candidates.last);
      final kept = await c.read(dailyWordHistoryProvider.notifier).deliver(replacement);
      expect(kept.candidateId, original.candidateId);
    });

    test('favourite and save persist and stay consistent with the Library', () async {
      final store = onboardedStore();
      final c1 = testContainer(store);
      final e = await c1.read(dailyWordForDateProvider(today).future);
      expect(await c1.read(dailyWordHistoryProvider.notifier).toggleFavourite(today), isTrue);
      await c1.read(savedScriptureProvider.notifier).toggle(e.reference);

      final c2 = testContainer(store);
      expect(c2.read(dailyWordHistoryProvider).single.favourite, isTrue);
      expect(c2.read(savedScriptureProvider).map((s) => s.reference), [e.reference]);
      expect(await c2.read(dailyWordHistoryProvider.notifier).toggleFavourite(today), isFalse);
      expect(testContainer(store).read(dailyWordHistoryProvider).single.favourite, isFalse);
    });

    test('with personalisation off the annual schedule is used even with strong signals', () async {
      final store = onboardedStore();
      final c = testContainer(store);
      await c.read(interestsProvider.notifier).save({'family'});
      await c.read(dailyWordSettingsProvider.notifier).setAdaptive(false);
      final catalogue = shippedCatalogue();
      for (final k in ['2026-11-10', '2026-11-11', '2026-11-12']) {
        final e = await c.read(dailyWordForDateProvider(k).future);
        expect(e.candidateId, catalogue.scheduledFor(dateFromKey(k)).id);
        expect(e.adaptive, isFalse);
      }
      expect(testContainer(store).read(dailyWordSettingsProvider).adaptiveEnabled, isFalse);
    });

    test('with personalisation on, chosen interests can adapt a future word', () async {
      final store = onboardedStore();
      final c = testContainer(store);
      await c.read(interestsProvider.notifier).save({'family'});
      final catalogue = shippedCatalogue();
      var adapted = 0;
      for (var i = 0; i < 6; i++) {
        final d = fixedNow.add(Duration(days: i));
        final e = await c.read(dailyWordForDateProvider(dateKeyOf(d)).future);
        if (e.adaptive) {
          adapted++;
          expect(e.category, 'Family');
          expect(e.scheduledCandidateId, catalogue.scheduledFor(d).id);
          expect(e.reasons.map((r) => r.code), contains('signal.interest'));
        }
      }
      expect(adapted, greaterThan(0));
    });

    test('clearing signals removes recorded searches and records the time', () async {
      final store = onboardedStore();
      final c = testContainer(store);
      await c.read(relevanceSignalsProvider.notifier).recordSearch('peace of God');
      await c.read(recentSearchesProvider.notifier).add('waiting');
      expect(c.read(relevanceSignalsProvider).map((s) => s.value), ['peace of God', 'waiting']);
      await c.read(dailyWordSettingsProvider.notifier).clearSignals();
      expect(c.read(relevanceSignalsProvider), isEmpty);
      expect(store.getString(StorageKeys.dailyWordSignals), isNull);
      expect(testContainer(store).read(dailyWordSettingsProvider).signalsClearedAt, fixedNow);
      expect(c.read(recentSearchesProvider), ['waiting'], reason: 'the Library is not deleted');
    });
  });

  group('Detail (intelligence integration)', () {
    test('includes passage text, context, related records and related Scripture', () async {
      final c = testContainer(onboardedStore());
      final psalm = shippedCatalogue().candidates.firstWhere((x) => x.reference == ref('PSA 91:11'));
      await c.read(dailyWordHistoryProvider.notifier).deliver(entryFor(DateTime(2026, 11, 10), psalm));
      final d = await c.read(dailyWordDetailProvider(today).future);
      expect(d.passageText, startsWith('For he shall give his angels charge over thee'));
      expect(d.version.id, 'KJV');
      expect(d.context!.isConditional, isTrue);
      expect(d.promises.map((p) => p.id), contains('pr-prot-2'));
      expect(d.related.map((r) => r.reference), containsAll([ref('PSA 34:7'), ref('PSA 91:9')]));
      expect(d.related.every((r) => r.text != null && r.text!.isNotEmpty), isTrue);
      expect(d.surrounding.map((v) => v.number), [8, 9, 10, 11, 12, 13, 14]);
    });

    test('a passage without a context shows no invented context', () async {
      final c = testContainer(onboardedStore());
      final e = entryFor(DateTime(2026, 11, 10), shippedCatalogue().candidates.first);
      await c
          .read(dailyWordHistoryProvider.notifier)
          .deliver(DailyWordHistoryEntry.fromJson({...e.toJson(), 'ref': ref('PSA 4:8').toJson()}));
      final d = await c.read(dailyWordDetailProvider(today).future);
      expect(d.context, isNull);
      expect(d.promises, isEmpty);
      expect(d.passageText, startsWith('I will both lay me down in peace'));
    });

    test('reads the active translation offline', () async {
      final c = testContainer(onboardedStore());
      await c.read(readingPreferencesProvider.notifier).update((p) => p.copyWith(versionId: 'WEB'));
      final e = await c.read(dailyWordForDateProvider(today).future);
      final d = await c.read(dailyWordDetailProvider(today).future);
      expect(e.versionId, 'WEB');
      expect(d.version.id, 'WEB');
      expect(d.passageText, (await sharedTestBible.passage('WEB', e.reference)).text);
    });
  });

  group('Sharing', () {
    test('the share payload carries Scripture, reference and translation', () {
      final p = SharePayload.scripture(
        scripture: 'Thy word is a lamp unto my feet, and a light unto my path.',
        reference: 'Psalm 119:105',
        translation: 'KJV',
        heading: 'Daily Word · Thy word lights the path',
      );
      expect(
        p.text,
        'Daily Word · Thy word lights the path\n\n“Thy word is a lamp unto my feet, and a light unto my path.”\n'
        '— Psalm 119:105 (KJV)\n\nShared from My Word Bible',
      );
      expect(p.subject, 'Psalm 119:105 (KJV)');
    });

    testWidgets('a Scripture card renders to a 1080×1350 PNG and fits long passages', (tester) async {
      final style = ScriptureCardStyle.fromPalette(MwbThemes.byId(MwbThemeId.classicGold).paletteFor(Brightness.light));
      await tester.runAsync(() async {
        final short = await const ScriptureCardRenderer().render(
          const ScriptureCardContent(scripture: 'Jesus wept.', reference: 'John 11:35', translation: 'KJV'),
          style,
        );
        expect(short.width, 1080);
        expect(short.height, 1350);
        expect(short.png.sublist(0, 8), Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
        expect(short.scriptureFontSize, 60);

        final long = await const ScriptureCardRenderer().render(
          ScriptureCardContent(
            scripture: List.filled(
              8,
              'And God saw every thing that he had made, and, behold, it was very good.',
            ).join(' '),
            reference: 'Genesis 1:31',
            translation: 'KJV',
            overline: 'Daily Word · Gratitude',
            heading: 'Very good',
            attribution: 'King James Version · Public domain',
          ),
          style,
        );
        expect(long.scriptureFontSize, lessThan(short.scriptureFontSize));
      });
    });
  });

  group('Daily Word screen', () {
    testWidgets('Home card opens the Daily Word with context, save, favourite and native share', (tester) async {
      final share = FakeShareService();
      final store = onboardedStore();
      await pumpMwbApp(tester, store, extra: [shareServiceProvider.overrideWithValue(share)]);

      expect(find.byKey(const Key('home.dailyWord')), findsOneWidget);
      // Mode C: nothing is approved, so the title is the MWB fallback.
      expect(find.text('Daily Word – MWB'), findsOneWidget);
      expect(find.textContaining('Chosen from your activity'), findsNothing);
      await openDailyWord(tester);

      expect(find.text('Daily Word'), findsOneWidget);
      expect(find.byKey(const Key('dailyWord.scripture')), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tuesday, 10 Nov'), findsOneWidget);
      expect(find.text('Why you’re seeing this'), findsNothing);
      expect(find.textContaining('exactly as written'), findsNothing);

      await tapAction(tester, 'dailyWord.save');
      await settle(tester);
      await tapAction(tester, 'dailyWord.favourite');
      await settle(tester);
      await tapAction(tester, 'dailyWord.share');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await settle(tester);
      await tester.tap(find.byKey(const Key('share.text')));
      await settle(tester);

      final entry = DailyWordHistoryEntry.fromJson(
        (store.readJson(StorageKeys.dailyWordHistory) as List).single as Map<String, dynamic>,
      );
      expect(entry.favourite, isTrue);
      expect(entry.openedAt, isNotNull);
      expect(store.readJson(StorageKeys.savedScripture), isNotEmpty);
      expect(share.texts.single.text, contains('— ${entry.reference.label} (KJV)'));

      await scrollTo(tester, find.text('About this passage'));
      expect(find.byKey(const Key('dailyWord.context')), findsOneWidget);
    });

    testWidgets('previous Daily Words can be revisited from the screen and history', (tester) async {
      final store = onboardedStore();
      final catalogue = shippedCatalogue();
      final yesterday = entryFor(DateTime(2026, 11, 9), catalogue.candidates[3]);
      await store.writeList(StorageKeys.dailyWordHistory, [yesterday], (e) => e.toJson());
      await pumpMwbApp(tester, store);

      await openDailyWord(tester);
      await scrollTo(tester, find.byKey(const Key('dailyWord.previous')));
      await tester.tap(find.byKey(const Key('dailyWord.previous')));
      await settle(tester);
      expect(find.text('Monday, 9 Nov'), findsOneWidget);
      expect(find.text('Today'), findsNothing);

      await tester.tap(find.byKey(const Key('dailyWord.history')));
      await settle(tester);
      expect(find.text('Daily Word history'), findsOneWidget);
      expect(find.byKey(const Key('dailyWordHistory.2026-11-10')), findsOneWidget);
      expect(find.byKey(const Key('dailyWordHistory.2026-11-09')), findsOneWidget);
    });

    testWidgets('Share composes branded images automatically and opens the native share sheet', (tester) async {
      final share = FakeShareService();
      await pumpMwbApp(tester, onboardedStore(), extra: [shareServiceProvider.overrideWithValue(share)]);
      await openDailyWord(tester);
      await tapAction(tester, 'dailyWord.share');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await settle(tester);
      expect(find.text('Scripture card'), findsNothing);
      expect(find.byKey(const Key('share.preview')), findsOneWidget);
      await tester.tap(find.byKey(const Key('share.go')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      expect(share.images, isNotEmpty);
      expect(share.images.first.png.sublist(0, 4), Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
      expect(share.images.first.payload.text, contains('Shared from My Word Bible'));
    });
  });
}
