import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/models/social.dart';
import 'package:my_word_bible/data/repositories/social_repositories.dart';
import 'package:my_word_bible/features/social/domain/share_links.dart';

import '../helpers/test_app.dart';
import 'sharing_test_support.dart';

ScriptureReference r(String s) => ScriptureReference.parseCompact(s);

ShareDraft draft({String to = 'mwb_demo_grace', String tr = 'KJV', List<ScriptureReference>? refs, String? message}) =>
    ShareDraft(
      recipientId: to,
      references: refs ?? [r('ROM 15:13')],
      referenceLabel: 'Romans 15:13',
      translationId: tr,
      message: message,
    );

void main() {
  group('Identity', () {
    test('a local identity is created once, kept, and never claims registration', () {
      final store = InMemoryKeyValueStore();
      final repo = LocalSocialSettingsRepository(store);
      final a = repo.identity(displayName: 'Grace Okoro');
      final b = LocalSocialSettingsRepository(store).identity(displayName: 'Grace Okoro');
      expect(a.userId, b.userId);
      expect(isValidUserId(a.userId), isTrue);
      expect(a.username, 'grace.okoro');
      expect(a.registered, isFalse);
    });

    test('recent recipients are most-recent first and unique', () async {
      final repo = LocalSocialSettingsRepository(InMemoryKeyValueStore());
      await repo.addRecentRecipient('mwb_demo_a');
      await repo.addRecentRecipient('mwb_demo_b');
      await repo.addRecentRecipient('mwb_demo_a');
      expect(repo.recentRecipients(), ['mwb_demo_a', 'mwb_demo_b']);
    });
  });

  group('Recipient search', () {
    test('finds people by @username, username, MWB ID and name', () async {
      final dir = DemoUserDirectory(InMemoryKeyValueStore());
      expect((await dir.search('@grace.okafor')).first.userId, 'mwb_demo_grace');
      expect((await dir.search('daniel.mensah')).single.userId, 'mwb_demo_daniel');
      expect((await dir.search('mwb_demo_ruth')).single.userId, 'mwb_demo_ruth');
      expect((await dir.search('hannah')).single.displayName, 'Hannah Bello');
      expect(await dir.search(''), isEmpty);
    });

    test('private profiles are found only by exact username or ID', () async {
      final dir = DemoUserDirectory(InMemoryKeyValueStore());
      expect(await dir.search('joseph'), isEmpty);
      expect((await dir.search('@joseph.k')).single.userId, 'mwb_demo_joseph');
    });

    test('blocked people are never returned', () async {
      final store = InMemoryKeyValueStore();
      final s = socialStack(store);
      await s.safety.block('mwb_demo_grace');
      expect(await s.directory.search('grace'), isEmpty);
      expect(await s.directory.byId('mwb_demo_grace'), isNull);
    });

    test('malformed or injected IDs are rejected before any lookup', () async {
      final dir = DemoUserDirectory(InMemoryKeyValueStore());
      for (final id in ['', 'grace', "mwb_demo_grace' OR 1=1", 'MWB_DEMO_GRACE', '../mwb_demo_grace', 'mwb_demo_grace/email']) {
        expect(await dir.byId(id), isNull, reason: id);
      }
    });

    test('a public profile carries no private fields', () {
      final json = DemoUserDirectory.people.first.toJson();
      for (final key in json.keys) {
        expect(['email', 'phone', 'birthday', 'location', 'following', 'struggles'], isNot(contains(key)));
      }
    });
  });

  group('Share creation and delivery', () {
    test('the shared text is the canonical text of the installed translation', () async {
      final s = socialStack(InMemoryKeyValueStore());
      final share = await s.shares.create(draft(refs: [r('ROM 15:13-14'), r('ROM 15:16')]), sender: me);
      final p1 = await sharedTestBible.passage('KJV', r('ROM 15:13-14'));
      final p2 = await sharedTestBible.passage('KJV', r('ROM 15:16'));
      expect(share.text, [...p1.verses, ...p2.verses].map((v) => v.text).join(' '));
      expect(share.verses.map((v) => v.number), [13, 14, 16]);
      expect(share.status, DeliveryStatus.preparedOffline);
      expect(shareIdPattern.hasMatch(share.id), isTrue);
    });

    test('a personalised edition is never sent as the translation', () async {
      final s = socialStack(InMemoryKeyValueStore());
      expect(() => s.shares.create(draft(tr: 'KJV-MWB'), sender: me), throwsA(SocialFailure.invalidScripture));
      expect(() => s.shares.create(draft(tr: 'NIV'), sender: me), throwsA(SocialFailure.invalidScripture));
    });

    test('recipient rules: unknown, self, blocked and not accepting are refused', () async {
      final store = InMemoryKeyValueStore();
      final s = socialStack(store);
      expect(() => s.shares.create(draft(to: 'mwb_nobody'), sender: me), throwsA(SocialFailure.notFound));
      expect(
        () => s.shares.create(draft(to: me.userId), sender: me),
        throwsA(anyOf(SocialFailure.self, SocialFailure.notFound)),
      );
      expect(() => s.shares.create(draft(to: 'mwb_demo_esther'), sender: me), throwsA(SocialFailure.notAccepting));
      await s.safety.block('mwb_demo_daniel');
      expect(() => s.shares.create(draft(to: 'mwb_demo_daniel'), sender: me), throwsA(SocialFailure.notFound));
      expect(
        SharePolicy.check(sender: me, recipient: DemoUserDirectory.people[1], blocked: {'mwb_demo_daniel'}),
        SocialFailure.blocked,
      );
    });

    test('a demo recipient gets an honest simulation, never "delivered"', () async {
      final s = socialStack(InMemoryKeyValueStore());
      final share = await s.shares.create(draft(), sender: me);
      final sent = await s.shares.deliver(share.id);
      expect(sent.status, DeliveryStatus.simulated);
      expect(sent.status.reachedRecipient, isFalse);
    });

    test('a real person waits for the sharing service', () async {
      final store = InMemoryKeyValueStore();
      final s = socialStack(store);
      await s.directory.remember(const PublicProfile(userId: 'mwb_real_ada', username: 'ada', displayName: 'Ada'));
      final share = await s.shares.create(draft(to: 'mwb_real_ada'), sender: me);
      expect((await s.shares.deliver(share.id)).status, DeliveryStatus.awaitingServer);
    });

    test('delivery is idempotent (no duplicate delivery)', () async {
      final s = socialStack(InMemoryKeyValueStore());
      final share = await s.shares.create(draft(), sender: me);
      final a = await s.shares.deliver(share.id);
      final b = await s.shares.deliver(share.id);
      expect(b.status, a.status);
      expect(s.shares.sent(), hasLength(1));
    });

    test('a received share is stored once; blocked senders are refused and hidden', () async {
      final store = InMemoryKeyValueStore();
      final s = socialStack(store);
      final incoming = ScriptureShare(
        id: 'AbCdEfGhIjKlMnOpQrStUvWx',
        idempotencyKey: 'AbCdEfGhIjKlMnOpQrStUvWx',
        direction: ShareDirection.received,
        senderId: 'mwb_demo_grace',
        senderName: 'Grace Okafor',
        recipientId: me.userId,
        recipientName: me.displayName,
        references: [r('PSA 46:10')],
        referenceLabel: 'Psalm 46:10',
        translationId: 'KJV',
        verses: const [SharedVerse(bookId: 'PSA', chapter: 46, number: 10, text: 'Be still, and know that I am God')],
        createdAt: fixedNow,
        status: DeliveryStatus.simulated,
        simulated: true,
      );
      expect(await s.shares.receive(incoming), isTrue);
      expect(await s.shares.receive(incoming), isFalse);
      expect(s.shares.received(), hasLength(1));
      await s.safety.block('mwb_demo_grace');
      expect(s.shares.received(), isEmpty);
    });

    test('opened, saved and thanked states persist; one thanks per share', () async {
      final store = InMemoryKeyValueStore();
      final s = socialStack(store);
      final share = await s.shares.create(draft(), sender: me);
      await s.shares.markOpened(share.id);
      await s.shares.setSaved(share.id, true);
      await s.shares.acknowledge(share.id, AcknowledgementKind.thanks, fromUserId: 'x');
      await s.shares.acknowledge(share.id, AcknowledgementKind.thanks, fromUserId: 'x');
      final again = socialStack(store).shares.byId(share.id)!;
      expect(again.isRead, isTrue);
      expect(again.isSaved, isTrue);
      expect(again.acknowledgements, hasLength(1));
    });
  });

  group('Notifications', () {
    InAppNotification note(String key, {String actor = 'mwb_demo_grace'}) => InAppNotification(
      id: 'n_$key',
      category: NotificationCategory.scriptureReceived,
      title: 'Grace shared a Scripture with you',
      createdAt: fixedNow,
      dedupeKey: key,
      actorId: actor,
    );

    test('records persist across restarts and are de-duplicated', () async {
      final store = InMemoryKeyValueStore();
      final repo = LocalNotificationRepository(store, clock: () => fixedNow);
      expect(await repo.add(note('share:1')), isTrue);
      expect(await repo.add(note('share:1')), isFalse);
      await repo.add(note('share:2'));
      final reopened = LocalNotificationRepository(store, clock: () => fixedNow);
      expect(reopened.all(), hasLength(2));
      expect(reopened.unreadCount(), 2);
      await reopened.markRead('n_share:1');
      expect(reopened.unreadCount(), 1);
      await reopened.markAllRead();
      expect(reopened.unreadCount(), 0);
    });

    test('blocking removes a person’s notifications', () async {
      final repo = LocalNotificationRepository(InMemoryKeyValueStore());
      await repo.add(note('a'));
      await repo.add(note('b', actor: 'mwb_demo_ruth'));
      await repo.removeFrom('mwb_demo_grace');
      expect(repo.all().map((n) => n.actorId), ['mwb_demo_ruth']);
    });
  });

  group('Follow system', () {
    test('follow and unfollow are explicit and persist', () async {
      final store = InMemoryKeyValueStore();
      final s = socialStack(store);
      await s.follows.follow('mwb_demo_grace');
      expect(socialStack(store).follows.isFollowing('mwb_demo_grace'), isTrue);
      await s.follows.unfollow('mwb_demo_grace');
      expect(s.follows.following(), isEmpty);
    });

    test('blocked people cannot be followed and their follows are ignored', () async {
      final s = socialStack(InMemoryKeyValueStore());
      await s.safety.block('mwb_demo_grace');
      expect(() => s.follows.follow('mwb_demo_grace'), throwsA(SocialFailure.blocked));
      expect(await s.follows.addFollower('mwb_demo_grace'), isFalse);
      expect(() => s.follows.follow('not-an-id'), throwsA(SocialFailure.notFound));
    });

    test('incoming shares respect "who can send me Scripture"', () {
      bool ok(DirectShareAudience a, {Set<String> following = const {}}) => SharePolicy.acceptsIncoming(
        senderId: 'mwb_demo_grace',
        privacy: SocialPrivacySettings(whoCanSendScripture: a),
        blocked: const {},
        following: following,
      );
      expect(ok(DirectShareAudience.everyone), isTrue);
      expect(ok(DirectShareAudience.nobody), isFalse);
      expect(ok(DirectShareAudience.peopleIFollow), isFalse);
      expect(ok(DirectShareAudience.peopleIFollow, following: {'mwb_demo_grace'}), isTrue);
    });
  });

  group('Deep links', () {
    const id = 'AbCdEfGhIjKlMnOpQrStUvWx';

    test('web, www, app-scheme and route forms parse; others are rejected', () {
      expect(ShareLinkCodec.parse(Uri.parse('https://mywordbible.com/s/$id')), id);
      expect(ShareLinkCodec.parse(Uri.parse('https://www.mywordbible.com/s/$id')), id);
      expect(ShareLinkCodec.parse(Uri.parse('mywordbible://app/s/$id')), id);
      expect(ShareLinkCodec.parse(Uri.parse('/s/$id')), id);
      for (final bad in [
        'https://evil.example/s/$id',
        'http://mywordbible.com/s/$id',
        'https://mywordbible.com/s/short',
        'https://mywordbible.com/s/$id/extra',
        'https://mywordbible.com/x/$id',
        'mywordbible://other/s/$id',
      ]) {
        expect(ShareLinkCodec.parse(Uri.parse(bad)), isNull, reason: bad);
      }
      expect(ShareLinkCodec.webUrl(id).toString(), 'https://mywordbible.com/s/$id');
      expect(ShareLinkCodec.appUrl(id).toString(), 'mywordbible://app/s/$id');
    });

    test('private shares open only for sender and recipient', () async {
      final s = socialStack(InMemoryKeyValueStore());
      final share = await s.shares.create(draft(), sender: me);
      ShareLinkOutcome as(String user) => ShareLinkResolver(s.shares, currentUserId: user).resolve(share.id).outcome;
      expect(as(me.userId), ShareLinkOutcome.opened);
      expect(as('mwb_demo_grace'), ShareLinkOutcome.opened);
      expect(as('mwb_someone_else'), ShareLinkOutcome.forbidden);
      expect(ShareLinkResolver(s.shares, currentUserId: me.userId).resolve(id).outcome, ShareLinkOutcome.notOnDevice);
      expect(ShareLinkResolver(s.shares, currentUserId: me.userId).resolve('../x').outcome, ShareLinkOutcome.invalid);
    });

    test('public link metadata never contains the message or recipient', () async {
      final s = socialStack(InMemoryKeyValueStore());
      final share = await s.shares.create(draft(message: 'Praying for you through this hard week'), sender: me);
      final meta = PublicShareMetadata.of(share).toOpenGraph().values.join(' ');
      expect(meta, isNot(contains('Praying')));
      expect(meta, isNot(contains('Grace Okafor')));
      expect(meta, contains('Romans 15:13'));
      expect(meta, contains(me.displayName));
    });
  });
}
