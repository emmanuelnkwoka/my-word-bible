import 'dart:convert';
import 'dart:math';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/key_value_store.dart';
import '../models/bible.dart';
import '../models/scripture_reference.dart';
import '../models/social.dart';
import 'bible_repository.dart';

/// Repositories for the Scripture Sharing & Christian Social Connection
/// engine. Every interface has an on-device implementation now; a remote
/// implementation (see docs/sharing/MWB_BACKEND_API_CONTRACT.md) can replace
/// it through the providers without changing any screen.

// ---------------------------------------------------------------------------
// Failures and ids
// ---------------------------------------------------------------------------

/// Why a social action was refused. Messages are safe to show to the user
/// and never reveal private information about the other person.
class SocialFailure implements Exception {
  const SocialFailure(this.code, this.message);
  final String code;
  final String message;

  static const notFound = SocialFailure('not_found', 'We couldn’t find that person.');
  static const blocked = SocialFailure('blocked', 'You can’t share with this person.');
  static const notAccepting = SocialFailure(
    'not_accepting',
    'This person isn’t receiving Scripture from you right now.',
  );
  static const self = SocialFailure('self', 'You can’t send Scripture to yourself.');
  static const invalidScripture = SocialFailure('invalid_scripture', 'This Scripture couldn’t be verified.');
  static const forbidden = SocialFailure('forbidden', 'This shared Scripture is private.');

  @override
  String toString() => 'SocialFailure($code)';
}

/// Unguessable identifiers (share ids double as deep-link ids).
class SocialIds {
  SocialIds([Random? random]) : _random = random ?? Random.secure();
  final Random _random;

  String _token(int bytes) =>
      base64Url.encode(List<int>.generate(bytes, (_) => _random.nextInt(256))).replaceAll('=', '');

  /// 24 url-safe characters (144 bits).
  String shareId() => _token(18);
  String notificationId() => 'n_${_token(9)}';
  String localUserId() => 'mwb_local_${_token(6).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
}

final shareIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

// ---------------------------------------------------------------------------
// Identity & privacy settings
// ---------------------------------------------------------------------------

abstract interface class SocialSettingsRepository {
  /// The user's MWB identity on this device, created on first use.
  SocialIdentity identity({required String displayName});
  Future<void> saveIdentity(SocialIdentity identity);

  SocialPrivacySettings privacy();
  Future<void> savePrivacy(SocialPrivacySettings settings);

  /// Most recent first.
  List<String> recentRecipients();
  Future<void> addRecentRecipient(String userId);
}

class LocalSocialSettingsRepository implements SocialSettingsRepository {
  LocalSocialSettingsRepository(this._store, {SocialIds? ids}) : _ids = ids ?? SocialIds();
  final KeyValueStore _store;
  final SocialIds _ids;

  static String suggestUsername(String displayName) {
    final base = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '.').replaceAll(RegExp(r'^\.+|\.+$'), '');
    return base.length >= 3 ? (base.length > 24 ? base.substring(0, 24) : base) : 'mwb.reader';
  }

  @override
  SocialIdentity identity({required String displayName}) {
    final data = _store.readJson(StorageKeys.socialIdentity);
    if (data is Map<String, dynamic>) {
      try {
        final saved = SocialIdentity.fromJson(data);
        // Keep the display name in step with the profile.
        if (displayName.isNotEmpty && saved.displayName != displayName) {
          final next = SocialIdentity(
            userId: saved.userId,
            username: saved.username,
            displayName: displayName,
            registered: saved.registered,
          );
          _store.writeJson(StorageKeys.socialIdentity, next.toJson());
          return next;
        }
        return saved;
      } catch (_) {
        // Fall through and recreate.
      }
    }
    final created = SocialIdentity(
      userId: _ids.localUserId(),
      username: suggestUsername(displayName),
      displayName: displayName.isEmpty ? 'My Word Bible reader' : displayName,
    );
    _store.writeJson(StorageKeys.socialIdentity, created.toJson());
    return created;
  }

  @override
  Future<void> saveIdentity(SocialIdentity identity) => _store.writeJson(StorageKeys.socialIdentity, identity.toJson());

  @override
  SocialPrivacySettings privacy() {
    final data = _store.readJson(StorageKeys.socialPrivacy);
    return data is Map<String, dynamic> ? SocialPrivacySettings.fromJson(data) : const SocialPrivacySettings();
  }

  @override
  Future<void> savePrivacy(SocialPrivacySettings settings) =>
      _store.writeJson(StorageKeys.socialPrivacy, settings.toJson());

  @override
  List<String> recentRecipients() {
    final data = _store.readJson(StorageKeys.socialRecentRecipients);
    return data is List ? data.whereType<String>().toList() : <String>[];
  }

  @override
  Future<void> addRecentRecipient(String userId) => _store.writeJson(
    StorageKeys.socialRecentRecipients,
    [userId, ...recentRecipients().where((id) => id != userId)].take(12).toList(),
  );
}

// ---------------------------------------------------------------------------
// Safety: blocking and reporting
// ---------------------------------------------------------------------------

abstract interface class SafetyRepository {
  Set<String> blocked();
  bool isBlocked(String userId);
  Future<void> block(String userId);
  Future<void> unblock(String userId);
  List<SafetyReport> reports();
  Future<void> report(SafetyReport report);
}

class LocalSafetyRepository implements SafetyRepository {
  LocalSafetyRepository(this._store);
  final KeyValueStore _store;

  @override
  Set<String> blocked() {
    final data = _store.readJson(StorageKeys.socialBlocked);
    return data is List ? data.whereType<String>().toSet() : <String>{};
  }

  @override
  bool isBlocked(String userId) => blocked().contains(userId);

  @override
  Future<void> block(String userId) => _store.writeJson(StorageKeys.socialBlocked, {...blocked(), userId}.toList());

  @override
  Future<void> unblock(String userId) =>
      _store.writeJson(StorageKeys.socialBlocked, blocked().where((id) => id != userId).toList());

  @override
  List<SafetyReport> reports() => _store.readList(StorageKeys.socialReports, SafetyReport.fromJson);

  @override
  Future<void> report(SafetyReport report) =>
      _store.writeList(StorageKeys.socialReports, [...reports(), report], (r) => r.toJson());
}

// ---------------------------------------------------------------------------
// Follow relationships
// ---------------------------------------------------------------------------

abstract interface class FollowRepository {
  Set<String> following();
  Set<String> followers();
  bool isFollowing(String userId);

  /// Explicit user action only. Throws [SocialFailure.blocked] for blocked people.
  Future<void> follow(String userId);
  Future<void> unfollow(String userId);

  /// Records that [userId] followed the current user (remote push, or the
  /// on-device demo). Returns false if it was already recorded or blocked.
  Future<bool> addFollower(String userId);
  Future<void> removeFollower(String userId);
}

class LocalFollowRepository implements FollowRepository {
  LocalFollowRepository(this._store, this._safety);
  final KeyValueStore _store;
  final SafetyRepository _safety;

  Set<String> _read(String key) {
    final data = _store.readJson(key);
    return data is List ? data.whereType<String>().toSet() : <String>{};
  }

  @override
  Set<String> following() => _read(StorageKeys.socialFollowing);

  @override
  Set<String> followers() => _read(StorageKeys.socialFollowers).difference(_safety.blocked());

  @override
  bool isFollowing(String userId) => following().contains(userId);

  @override
  Future<void> follow(String userId) async {
    if (!isValidUserId(userId)) throw SocialFailure.notFound;
    if (_safety.isBlocked(userId)) throw SocialFailure.blocked;
    await _store.writeJson(StorageKeys.socialFollowing, {...following(), userId}.toList());
  }

  @override
  Future<void> unfollow(String userId) =>
      _store.writeJson(StorageKeys.socialFollowing, following().where((id) => id != userId).toList());

  @override
  Future<bool> addFollower(String userId) async {
    if (_safety.isBlocked(userId)) return false;
    final all = _read(StorageKeys.socialFollowers);
    if (all.contains(userId)) return false;
    await _store.writeJson(StorageKeys.socialFollowers, {...all, userId}.toList());
    return true;
  }

  @override
  Future<void> removeFollower(String userId) => _store.writeJson(
    StorageKeys.socialFollowers,
    _read(StorageKeys.socialFollowers).where((id) => id != userId).toList(),
  );
}

// ---------------------------------------------------------------------------
// User directory (recipient search, public profiles)
// ---------------------------------------------------------------------------

abstract interface class UserDirectoryRepository {
  /// Whether results come from the real MWB service (false: demo community).
  bool get isLive;

  /// Searches by username (with or without `@`), exact user id or name.
  /// Blocked people and "only me" profiles (except on an exact match) are
  /// never returned.
  Future<List<PublicProfile>> search(String query, {Set<String> exclude = const {}});

  /// Exact lookup. Malformed ids return null without any lookup.
  Future<PublicProfile?> byId(String userId);

  /// Remembers a person seen in a received share so they can be found again.
  Future<void> remember(PublicProfile profile);
}

/// The on-device demo community: invented sample people, clearly labelled,
/// used until MWB accounts exist. No real person is represented.
class DemoUserDirectory implements UserDirectoryRepository {
  DemoUserDirectory(this._store);
  final KeyValueStore _store;

  static final _day = DateTime(2026, 11, 1);

  static final List<PublicProfile> people = [
    PublicProfile(
      userId: 'mwb_demo_grace',
      username: 'grace.okafor',
      displayName: 'Grace Okafor',
      bio: 'Morning Psalms and evening gratitude.',
      isDemo: true,
      tone: 0,
      publicActivity: [
        PublicScriptureActivity(reference: ScriptureReference.parseCompact('PSA 46:10'), versionId: 'KJV', at: _day),
        PublicScriptureActivity(
          reference: ScriptureReference.parseCompact('LAM 3:22-23'),
          versionId: 'KJV',
          at: _day.subtract(const Duration(days: 2)),
          note: 'New every morning.',
        ),
      ],
    ),
    PublicProfile(
      userId: 'mwb_demo_daniel',
      username: 'daniel.mensah',
      displayName: 'Daniel Mensah',
      bio: 'Reading through the Gospels this year.',
      isDemo: true,
      tone: 1,
      publicActivity: [
        PublicScriptureActivity(reference: ScriptureReference.parseCompact('JHN 15:5'), versionId: 'KJV', at: _day),
      ],
    ),
    PublicProfile(
      userId: 'mwb_demo_ruth',
      username: 'ruth.adeyemi',
      displayName: 'Ruth Adeyemi',
      bio: 'Choir, family and the book of Ruth.',
      isDemo: true,
      tone: 2,
      followsYou: true,
      publicActivity: [
        PublicScriptureActivity(reference: ScriptureReference.parseCompact('RUT 1:16'), versionId: 'KJV', at: _day),
        PublicScriptureActivity(
          reference: ScriptureReference.parseCompact('ISA 40:31'),
          versionId: 'KJV',
          at: _day.subtract(const Duration(days: 4)),
        ),
      ],
    ),
    const PublicProfile(
      userId: 'mwb_demo_samuel',
      username: 'samuel.eze',
      displayName: 'Samuel Eze',
      bio: 'Youth leader. Proverbs on Fridays.',
      isDemo: true,
      tone: 3,
    ),
    PublicProfile(
      userId: 'mwb_demo_hannah',
      username: 'hannah.bello',
      displayName: 'Hannah Bello',
      bio: 'Prayer walks and Philippians.',
      isDemo: true,
      tone: 4,
      publicActivity: [
        PublicScriptureActivity(reference: ScriptureReference.parseCompact('PHP 4:6-7'), versionId: 'KJV', at: _day),
      ],
    ),
    // Accepts Scripture only from people she follows (she does not follow
    // the demo user), so sending to her is refused politely.
    const PublicProfile(
      userId: 'mwb_demo_esther',
      username: 'esther.nwosu',
      displayName: 'Esther Nwosu',
      bio: 'Receives Scripture from people she follows.',
      acceptsSharesFrom: DirectShareAudience.peopleIFollow,
      isDemo: true,
      tone: 5,
    ),
    // A private profile: found only by exact id or username.
    const PublicProfile(
      userId: 'mwb_demo_joseph',
      username: 'joseph.k',
      displayName: 'Joseph K.',
      visibility: ProfileVisibility.onlyMe,
      isDemo: true,
      tone: 1,
    ),
  ];

  List<PublicProfile> _remembered() => _store.readList(StorageKeys.socialKnownPeople, PublicProfile.fromJson);

  List<PublicProfile> get _all {
    final known = {for (final p in people) p.userId: p};
    for (final p in _remembered()) {
      known.putIfAbsent(p.userId, () => p);
    }
    return known.values.toList();
  }

  Set<String> _blocked() {
    final data = _store.readJson(StorageKeys.socialBlocked);
    return data is List ? data.whereType<String>().toSet() : <String>{};
  }

  @override
  bool get isLive => false;

  @override
  Future<List<PublicProfile>> search(String query, {Set<String> exclude = const {}}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final blocked = _blocked();
    final handle = q.startsWith('@') ? q.substring(1) : q;
    final out = <PublicProfile>[];
    for (final p in _all) {
      if (blocked.contains(p.userId) || exclude.contains(p.userId)) continue;
      final exact = p.userId == q || p.username == handle;
      if (p.visibility == ProfileVisibility.onlyMe && !exact) continue;
      final partial =
          p.username.contains(handle) ||
          p.displayName.toLowerCase().contains(q) ||
          p.displayName.toLowerCase().split(' ').any((w) => w.startsWith(q));
      if (exact || (q.length >= 2 && partial)) out.add(p);
    }
    out.sort((a, b) {
      final ae = a.username == handle || a.userId == q ? 0 : 1;
      final be = b.username == handle || b.userId == q ? 0 : 1;
      return ae != be ? ae - be : a.displayName.compareTo(b.displayName);
    });
    return out;
  }

  @override
  Future<PublicProfile?> byId(String userId) async {
    if (!isValidUserId(userId)) return null;
    if (_blocked().contains(userId)) return null;
    for (final p in _all) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  @override
  Future<void> remember(PublicProfile profile) async {
    if (!isValidUserId(profile.userId) || people.any((p) => p.userId == profile.userId)) return;
    final list = [..._remembered().where((p) => p.userId != profile.userId), profile];
    await _store.writeList(StorageKeys.socialKnownPeople, list, (p) => p.toJson());
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

abstract interface class NotificationRepository {
  List<InAppNotification> all();
  int unreadCount();

  /// Adds [n] unless a notification with the same dedupe key exists.
  /// Returns whether it was added.
  Future<bool> add(InAppNotification n);
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> remove(String id);

  /// Drops notifications from [userId] (after blocking).
  Future<void> removeFrom(String userId);
}

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final KeyValueStore _store;
  final DateTime Function() _clock;

  static const maxKept = 300;

  @override
  List<InAppNotification> all() {
    final list = _store.readList(StorageKeys.socialNotifications, InAppNotification.fromJson);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _write(List<InAppNotification> list) =>
      _store.writeList(StorageKeys.socialNotifications, list.take(maxKept).toList(), (n) => n.toJson());

  @override
  int unreadCount() => all().where((n) => !n.isRead).length;

  @override
  Future<bool> add(InAppNotification n) async {
    final list = all();
    if (list.any((x) => x.dedupeKey == n.dedupeKey)) return false;
    await _write([n, ...list]);
    return true;
  }

  @override
  Future<void> markRead(String id) =>
      _write([for (final n in all()) n.id == id ? n.markRead(_clock()) : n]);

  @override
  Future<void> markAllRead() => _write([for (final n in all()) n.markRead(_clock())]);

  @override
  Future<void> remove(String id) => _write(all().where((n) => n.id != id).toList());

  @override
  Future<void> removeFrom(String userId) => _write(all().where((n) => n.actorId != userId).toList());
}

// ---------------------------------------------------------------------------
// Direct Scripture shares
// ---------------------------------------------------------------------------

/// Pure rules for whether [sender] may send Scripture to [recipient].
abstract final class SharePolicy {
  static SocialFailure? check({
    required SocialIdentity sender,
    required PublicProfile? recipient,
    required Set<String> blocked,
  }) {
    if (recipient == null) return SocialFailure.notFound;
    if (recipient.userId == sender.userId) return SocialFailure.self;
    if (blocked.contains(recipient.userId)) return SocialFailure.blocked;
    return switch (recipient.acceptsSharesFrom) {
      DirectShareAudience.everyone => null,
      DirectShareAudience.peopleIFollow => recipient.followsYou ? null : SocialFailure.notAccepting,
      DirectShareAudience.nobody => SocialFailure.notAccepting,
    };
  }

  /// Whether a received share from [senderId] should be accepted on this
  /// device given the user's own settings.
  static bool acceptsIncoming({
    required String senderId,
    required SocialPrivacySettings privacy,
    required Set<String> blocked,
    required Set<String> following,
  }) {
    if (blocked.contains(senderId)) return false;
    return switch (privacy.whoCanSendScripture) {
      DirectShareAudience.everyone => true,
      DirectShareAudience.peopleIFollow => following.contains(senderId),
      DirectShareAudience.nobody => false,
    };
  }
}

abstract interface class ScriptureShareRepository {
  /// Whether shares really leave the device (false: local only).
  bool get isLive;

  List<ScriptureShare> sent();
  List<ScriptureShare> received();
  ScriptureShare? byId(String id);

  /// Verifies the recipient and the Scripture, snapshots the canonical text
  /// and stores the share. Nothing is delivered yet.
  Future<ScriptureShare> create(ShareDraft draft, {required SocialIdentity sender});

  /// Hands the share to the delivery channel. Idempotent: a share that has
  /// already left [DeliveryStatus.preparedOffline] is returned unchanged.
  Future<ScriptureShare> deliver(String shareId);

  /// Stores a share received from someone else. Returns false for a
  /// duplicate (same id or idempotency key).
  Future<bool> receive(ScriptureShare share);

  Future<ScriptureShare?> markOpened(String shareId);
  Future<ScriptureShare?> setSaved(String shareId, bool saved);
  Future<ScriptureShare?> acknowledge(String shareId, AcknowledgementKind kind, {required String fromUserId, String? message});

  List<OpenedShareLink> openedLinks();
  Future<void> recordOpenedLink(OpenedShareLink link);
}

class LocalScriptureShareRepository implements ScriptureShareRepository {
  LocalScriptureShareRepository({
    required this._store,
    required this._bible,
    required this._directory,
    required this._safety,
    DateTime Function()? clock,
    SocialIds? ids,
  }) : _clock = clock ?? DateTime.now,
       _ids = ids ?? SocialIds();

  final KeyValueStore _store;
  final BibleRepository _bible;
  final UserDirectoryRepository _directory;
  final SafetyRepository _safety;
  final DateTime Function() _clock;
  final SocialIds _ids;

  @override
  bool get isLive => false;

  List<ScriptureShare> _all() => _store.readList(StorageKeys.socialShares, ScriptureShare.fromJson);
  Future<void> _write(List<ScriptureShare> list) =>
      _store.writeList(StorageKeys.socialShares, list, (s) => s.toJson());

  List<ScriptureShare> _sorted(Iterable<ScriptureShare> it) => it.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  List<ScriptureShare> sent() => _sorted(_all().where((s) => s.direction == ShareDirection.sent));

  @override
  List<ScriptureShare> received() {
    final blocked = _safety.blocked();
    return _sorted(_all().where((s) => s.direction == ShareDirection.received && !blocked.contains(s.senderId)));
  }

  @override
  ScriptureShare? byId(String id) {
    if (!shareIdPattern.hasMatch(id)) return null;
    for (final s in _all()) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Canonical verses for [refs] in the source translation [versionId].
  Future<List<SharedVerse>> _canonical(String versionId, List<ScriptureReference> refs) async {
    final info = _bible.versions.where((v) => v.id == versionId).firstOrNull;
    if (info == null || info.isPersonalised || !info.isInstalled) throw SocialFailure.invalidScripture;
    final out = <SharedVerse>[];
    final seen = <String>{};
    for (final r in refs) {
      final Passage p;
      try {
        p = await _bible.passage(versionId, r);
      } catch (_) {
        throw SocialFailure.invalidScripture;
      }
      for (final v in p.verses) {
        if (v.isOmitted || !seen.add('${v.bookId}.${v.chapter}.${v.number}')) continue;
        out.add(SharedVerse(bookId: v.bookId, chapter: v.chapter, number: v.number, text: v.text));
      }
    }
    if (out.isEmpty) throw SocialFailure.invalidScripture;
    return out;
  }

  @override
  Future<ScriptureShare> create(ShareDraft draft, {required SocialIdentity sender}) async {
    if (draft.references.isEmpty) throw SocialFailure.invalidScripture;
    final recipient = await _directory.byId(draft.recipientId);
    final refused = SharePolicy.check(sender: sender, recipient: recipient, blocked: _safety.blocked());
    if (refused != null) throw refused;
    final verses = await _canonical(draft.translationId, draft.references);
    final message = draft.message?.trim();
    final id = _ids.shareId();
    final share = ScriptureShare(
      id: id,
      idempotencyKey: id,
      direction: ShareDirection.sent,
      senderId: sender.userId,
      senderName: sender.displayName,
      recipientId: recipient!.userId,
      recipientName: recipient.displayName,
      references: draft.references,
      referenceLabel: draft.referenceLabel,
      translationId: draft.translationId,
      verses: verses,
      createdAt: _clock(),
      status: DeliveryStatus.preparedOffline,
      receptionEdition: draft.receptionEdition,
      message: message == null || message.isEmpty ? null : message,
      careIntent: draft.careIntent,
      templateId: draft.templateId,
      privacy: draft.privacy,
    );
    await _write([..._all(), share]);
    return share;
  }

  @override
  Future<ScriptureShare> deliver(String shareId) async {
    final list = _all();
    final i = list.indexWhere((s) => s.id == shareId && s.direction == ShareDirection.sent);
    if (i < 0) throw SocialFailure.notFound;
    final share = list[i];
    if (share.status != DeliveryStatus.preparedOffline && share.status != DeliveryStatus.failed) return share;
    // Re-verify at the moment of sending: blocks may have changed.
    final recipient = await _directory.byId(share.recipientId);
    if (recipient == null || _safety.isBlocked(share.recipientId)) {
      list[i] = share.copyWith(status: DeliveryStatus.failed);
      await _write(list);
      return list[i];
    }
    // No sharing server is connected: demo people get an honest simulation,
    // anyone else waits for MWB accounts.
    list[i] = share.copyWith(status: recipient.isDemo ? DeliveryStatus.simulated : DeliveryStatus.awaitingServer);
    await _write(list);
    return list[i];
  }

  @override
  Future<bool> receive(ScriptureShare share) async {
    final list = _all();
    if (list.any((s) => s.id == share.id || s.idempotencyKey == share.idempotencyKey)) return false;
    if (_safety.isBlocked(share.senderId)) return false;
    await _write([...list, share]);
    return true;
  }

  Future<ScriptureShare?> _update(String id, ScriptureShare Function(ScriptureShare) change) async {
    final list = _all();
    final i = list.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    list[i] = change(list[i]);
    await _write(list);
    return list[i];
  }

  @override
  Future<ScriptureShare?> markOpened(String shareId) =>
      _update(shareId, (s) => s.openedAt == null ? s.copyWith(openedAt: _clock()) : s);

  @override
  Future<ScriptureShare?> setSaved(String shareId, bool saved) =>
      _update(shareId, (s) => saved ? s.copyWith(savedAt: _clock()) : s.copyWith(clearSaved: true));

  @override
  Future<ScriptureShare?> acknowledge(
    String shareId,
    AcknowledgementKind kind, {
    required String fromUserId,
    String? message,
  }) => _update(shareId, (s) {
    // One acknowledgement of each kind per share (a reply may repeat).
    if (kind != AcknowledgementKind.reply && s.acknowledgements.any((a) => a.kind == kind && a.fromUserId == fromUserId)) {
      return s;
    }
    final ack = ShareAcknowledgement(
      shareId: shareId,
      fromUserId: fromUserId,
      kind: kind,
      at: _clock(),
      message: message,
      status: s.simulated ? DeliveryStatus.simulated : DeliveryStatus.awaitingServer,
    );
    return s.copyWith(acknowledgements: [...s.acknowledgements, ack]);
  });

  @override
  List<OpenedShareLink> openedLinks() {
    final list = _store.readList(StorageKeys.socialOpenedLinks, OpenedShareLink.fromJson);
    list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  @override
  Future<void> recordOpenedLink(OpenedShareLink link) => _store.writeList(
    StorageKeys.socialOpenedLinks,
    [link, ...openedLinks().where((l) => l.shareId != link.shareId)].take(50).toList(),
    (l) => l.toJson(),
  );
}
