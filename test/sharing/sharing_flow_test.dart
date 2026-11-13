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
import 'package:my_word_bible/data/models/social.dart';
import 'package:my_word_bible/features/profile/application/profile_controllers.dart';

import '../daily_word/daily_word_test_support.dart';
import '../helpers/test_app.dart';
import 'sharing_test_support.dart';

const _shareId = 'AbCdEfGhIjKlMnOpQrStUvWx';

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(MwbApp)));
GoRouter _router(WidgetTester tester) => _container(tester).read(appRouterProvider);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await settle(tester);
  await tester.tap(f);
  await settle(tester);
}

Future<void> _render(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await settle(tester);
}

Future<void> _openDailyWordShare(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('home.dailyWord')), matching: find.byKey(const Key('dailyWord.title'))));
  await settle(tester);
  await _tap(tester, find.byKey(const Key('dailyWord.share')));
  await _render(tester);
}

void main() {
  group('Quick share is preserved and extended', () {
    testWidgets('quick share still works, with optional extras beneath it', (tester) async {
      final share = FakeShareService();
      final export = FakeCardExportService();
      await pumpMwbApp(
        tester,
        onboardedStore(),
        extra: [shareServiceProvider.overrideWithValue(share), cardExportServiceProvider.overrideWithValue(export)],
      );
      await _openDailyWordShare(tester);

      // Unchanged: preview, three format chips, Share, Share as text.
      expect(find.byKey(const Key('share.preview')), findsOneWidget);
      for (final f in ['portrait', 'square', 'story']) {
        expect(find.byKey(Key('share.format.$f')), findsOneWidget);
      }
      expect(find.byKey(const Key('share.format.landscape')), findsNothing);
      await _tap(tester, find.byKey(const Key('share.go')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      expect(share.images, isNotEmpty);

      // New, optional.
      for (final k in ['share.studio', 'share.toUser', 'share.save', 'share.encourage', 'share.link']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      await _tap(tester, find.byKey(const Key('share.save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester);
      expect(export.saved.single.mimeType, 'image/png');
      expect(export.saved.single.fileName, endsWith('.png'));
    });
  });

  group('Card Studio', () {
    testWidgets('designs a card and hands it to WhatsApp Status with the caption', (tester) async {
      final export = FakeCardExportService();
      final share = FakeShareService();
      await pumpMwbApp(
        tester,
        onboardedStore(),
        extra: [cardExportServiceProvider.overrideWithValue(export), shareServiceProvider.overrideWithValue(share)],
      );
      await _openDailyWordShare(tester);
      await _tap(tester, find.byKey(const Key('share.studio')));
      await _render(tester);
      expect(find.text('Card Studio'), findsOneWidget);
      expect(find.byKey(const Key('studio.preview')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('studio.template.navy')));
      await _tap(tester, find.byKey(const Key('studio.dest.whatsappStatus')));
      await _render(tester);
      await tester.drag(find.byKey(const Key('studio.scroll')), const Offset(0, 3000));
      await settle(tester);
      expect(find.textContaining('Story · 1080×1920'), findsOneWidget);

      await tester.tap(find.byKey(const Key('studio.share')));
      await _render(tester);
      final sent = export.shared.single;
      expect(sent.package, 'com.whatsapp.w4b', reason: 'WhatsApp Business is the installed WhatsApp');
      expect(sent.text, contains('Shared from My Word Bible'));
      expect(sent.fileNames.single, endsWith('.png'));

      // Instagram is not installed: falls back to the native share sheet.
      await tester.scrollUntilVisible(
        find.byKey(const Key('studio.dest.instagramStory')),
        150,
        scrollable: find.ancestor(of: find.byKey(const Key('studio.dest.whatsappStatus')), matching: find.byType(Scrollable)).first,
      );
      await _tap(tester, find.byKey(const Key('studio.dest.instagramStory')));
      await _render(tester);
      await tester.tap(find.byKey(const Key('studio.share')));
      await _render(tester);
      expect(share.images, isNotEmpty);
    });

    testWidgets('asks which WhatsApp when WhatsApp and WhatsApp Business are both installed', (tester) async {
      final export = FakeCardExportService(installed: {'com.whatsapp', 'com.whatsapp.w4b'});
      await pumpMwbApp(tester, onboardedStore(), extra: [cardExportServiceProvider.overrideWithValue(export)]);
      await _openDailyWordShare(tester);
      await _tap(tester, find.byKey(const Key('share.studio')));
      await _render(tester);
      await _tap(tester, find.byKey(const Key('studio.dest.whatsappChat')));
      await _render(tester);
      await tester.tap(find.byKey(const Key('studio.share')));
      await _render(tester);
      expect(find.text('Which WhatsApp?'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('export.app.com.whatsapp.w4b')));
      await _render(tester);
      expect(export.shared.single.package, 'com.whatsapp.w4b');
    });

    testWidgets('saves a JPG to Photos', (tester) async {
      final export = FakeCardExportService();
      await pumpMwbApp(tester, onboardedStore(), extra: [cardExportServiceProvider.overrideWithValue(export)]);
      await _openDailyWordShare(tester);
      await _tap(tester, find.byKey(const Key('share.studio')));
      await _render(tester);
      await _tap(tester, find.text('Save'));
      await _tap(tester, find.text('JPG'));
      await _tap(tester, find.byKey(const Key('studio.saveGallery')));
      await _render(tester);
      expect(export.saved.single.mimeType, 'image/jpeg');
      expect(export.saved.single.bytes.sublist(0, 2), [0xFF, 0xD8]);
    });
  });

  group('Direct sharing', () {
    testWidgets('sends to a demo person with encouragement; status is honest', (tester) async {
      final store = onboardedStore();
      await pumpMwbApp(tester, store, extra: [socialClockProvider.overrideWithValue(() => fixedNow)]);
      await _openDailyWordShare(tester);
      await _tap(tester, find.byKey(const Key('share.toUser')));
      expect(find.textContaining('sample community'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('send.search')), '@ruth.adeyemi');
      await settle(tester);
      await _tap(tester, find.byKey(const Key('send.person.mwb_demo_ruth')));
      await _tap(tester, find.byKey(const Key('send.care.prayingForYou')));
      await scrollTo(tester, find.byKey(const Key('send.go')));
      await _tap(tester, find.byKey(const Key('send.go')));
      expect(find.text('Sent in the demo'), findsOneWidget);
      expect(find.textContaining('no one else received it'), findsOneWidget);

      final shares = store.readList(StorageKeys.socialShares, ScriptureShare.fromJson);
      final s = shares.single;
      expect(s.recipientId, 'mwb_demo_ruth');
      expect(s.status, DeliveryStatus.simulated);
      expect(s.message, "I'm praying for you.");
      expect(s.translationId, 'KJV');
      final canonical = await sharedTestBible.passage('KJV', s.references.single);
      expect(s.text, canonical.verses.map((v) => v.text).join(' '));
    });

    testWidgets('a person who only accepts Scripture from people they follow is refused politely', (tester) async {
      await pumpMwbApp(tester, onboardedStore());
      await _openDailyWordShare(tester);
      await _tap(tester, find.byKey(const Key('share.toUser')));
      await tester.enterText(find.byKey(const Key('send.search')), 'esther');
      await settle(tester);
      await _tap(tester, find.byKey(const Key('send.person.mwb_demo_esther')));
      await scrollTo(tester, find.byKey(const Key('send.go')));
      await _tap(tester, find.byKey(const Key('send.go')));
      expect(find.textContaining('isn’t receiving Scripture from you'), findsOneWidget);
    });
  });

  group('Inbox and receiving', () {
    testWidgets('a received Scripture notifies, opens, and can be saved and thanked', (tester) async {
      final store = onboardedStore();
      await pumpMwbApp(tester, store, extra: [socialClockProvider.overrideWithValue(() => fixedNow)]);
      expect(find.byKey(const Key('home.inboxBadge')), findsNothing);

      _router(tester).push('/inbox');
      await settle(tester);
      await _tap(tester, find.byKey(const Key('inbox.more')));
      await _tap(tester, find.byKey(const Key('inbox.demo')));
      await _tap(tester, find.byKey(const Key('demo.encouragement')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);

      expect(find.text('Ruth Adeyemi shared a Scripture with you'), findsOneWidget);
      expect(find.text('Demo'), findsWidgets);
      final note = store.readList(StorageKeys.socialNotifications, InAppNotification.fromJson).single;
      expect(note.category, NotificationCategory.encouragement);
      expect(note.simulated, isTrue);

      await _tap(tester, find.byKey(Key('inbox.item.${note.id}')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      expect(find.byKey(const Key('shared.scripture')), findsOneWidget);
      expect(find.textContaining('Fear thou not'), findsOneWidget);
      expect(find.byKey(const Key('shared.message')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('shared.save')));
      await _tap(tester, find.byKey(const Key('shared.thanks')));
      await _tap(tester, find.byKey(const Key('shared.follow')));
      final share = store.readList(StorageKeys.socialShares, ScriptureShare.fromJson).single;
      expect(share.isRead, isTrue);
      expect(share.isSaved, isTrue);
      expect(share.acknowledgements.single.kind, AcknowledgementKind.thanks);
      expect(share.acknowledgements.single.status, DeliveryStatus.simulated);
      expect(store.readJson(StorageKeys.socialFollowing), ['mwb_demo_ruth']);
      expect(store.readJson(StorageKeys.savedScripture), isNotEmpty);
      final read = store.readList(StorageKeys.socialNotifications, InAppNotification.fromJson).single;
      expect(read.isRead, isTrue);
    });

    testWidgets('opening a shared Scripture never follows the sender automatically', (tester) async {
      final store = onboardedStore();
      await pumpMwbApp(tester, store);
      _router(tester).push('/inbox');
      await settle(tester);
      await _tap(tester, find.byKey(const Key('inbox.more')));
      await _tap(tester, find.byKey(const Key('inbox.demo')));
      await _tap(tester, find.byKey(const Key('demo.scripture')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      await _tap(tester, find.textContaining('shared a Scripture with you').first);
      expect(store.readJson(StorageKeys.socialFollowing), isNull);
    });
  });

  group('Deep links', () {
    testWidgets('an unknown share link explains that the sharing service is needed', (tester) async {
      await pumpMwbApp(tester, onboardedStore());
      _router(tester).go('/s/$_shareId');
      await settle(tester);
      expect(find.byKey(const Key('shared.unavailable.notOnDevice')), findsOneWidget);
    });

    testWidgets('a private share between other people cannot be opened', (tester) async {
      final store = onboardedStore();
      final other = ScriptureShare(
        id: _shareId,
        idempotencyKey: _shareId,
        direction: ShareDirection.received,
        senderId: 'mwb_demo_grace',
        senderName: 'Grace',
        recipientId: 'mwb_demo_daniel',
        recipientName: 'Daniel',
        references: const [],
        referenceLabel: 'Psalm 23',
        translationId: 'KJV',
        verses: const [],
        createdAt: fixedNow,
        status: DeliveryStatus.simulated,
        message: 'private words',
      );
      await store.writeList(StorageKeys.socialShares, [other], (s) => s.toJson());
      await pumpMwbApp(tester, store);
      _router(tester).go('/s/$_shareId');
      await settle(tester);
      expect(find.byKey(const Key('shared.unavailable.forbidden')), findsOneWidget);
      expect(find.textContaining('private words'), findsNothing);
    });

    testWidgets('a link opened before onboarding is recovered afterwards', (tester) async {
      final store = InMemoryKeyValueStore();
      await pumpMwbApp(tester, store);
      _router(tester).go('/s/$_shareId');
      await settle(tester);
      expect(_router(tester).routerDelegate.currentConfiguration.uri.path, '/onboarding');
      expect(store.getString(StorageKeys.pendingShareLink), _shareId);

      await _container(tester).read(onboardingCompleteProvider.notifier).set(true);
      await settle(tester);
      expect(_router(tester).routerDelegate.currentConfiguration.uri.path, '/s/$_shareId');
      expect(store.getString(StorageKeys.pendingShareLink), isNull);
    });
  });

  group('Themes', () {
    testWidgets('sharing screens build in all seven themes, light and dark', (tester) async {
      for (final theme in MwbThemeId.values) {
        for (final mode in ['light', 'dark']) {
          final store = onboardedStore();
          await store.setString(StorageKeys.themeId, theme.storageKey);
          await store.setString(StorageKeys.themeMode, mode);
          await pumpMwbApp(tester, store);
          for (final route in ['/inbox', '/sharing/history', '/people', '/sharing/privacy', '/people/mwb_demo_grace']) {
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
