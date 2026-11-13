import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../data/models/scripture_reference.dart';
import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';
import '../../library/application/library_controllers.dart';
import '../../profile/application/profile_controllers.dart';
import '../../share/scripture_image_composer.dart';
import '../domain/share_links.dart';

/// Bumped after every social change so derived providers re-read the
/// repositories (which are the source of truth).
final socialRevisionProvider = NotifierProvider<SocialRevision, int>(SocialRevision.new);

class SocialRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// The current user's MWB identity on this device.
final socialIdentityProvider = Provider<SocialIdentity>((ref) {
  ref.watch(socialRevisionProvider);
  final profile = ref.watch(userProfileProvider);
  final name = [profile?.firstName.trim() ?? '', profile?.lastName.trim() ?? ''].where((s) => s.isNotEmpty).join(' ');
  return ref.read(socialSettingsRepositoryProvider).identity(displayName: name);
});

final socialPrivacyProvider = Provider<SocialPrivacySettings>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(socialSettingsRepositoryProvider).privacy();
});

final sentSharesProvider = Provider<List<ScriptureShare>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(scriptureShareRepositoryProvider).sent();
});

final receivedSharesProvider = Provider<List<ScriptureShare>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(scriptureShareRepositoryProvider).received();
});

final openedLinksProvider = Provider<List<OpenedShareLink>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(scriptureShareRepositoryProvider).openedLinks();
});

final notificationsProvider = Provider<List<InAppNotification>>((ref) {
  ref.watch(socialRevisionProvider);
  final blocked = ref.watch(blockedUsersProvider);
  return ref.watch(notificationRepositoryProvider).all().where((n) => !blocked.contains(n.actorId)).toList();
});

final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.isRead).length,
);

final followingProvider = Provider<Set<String>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(followRepositoryProvider).following();
});

final followersProvider = Provider<Set<String>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(followRepositoryProvider).followers();
});

final blockedUsersProvider = Provider<Set<String>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(safetyRepositoryProvider).blocked();
});

final recentRecipientIdsProvider = Provider<List<String>>((ref) {
  ref.watch(socialRevisionProvider);
  return ref.watch(socialSettingsRepositoryProvider).recentRecipients();
});

/// A public profile by id (null when unknown, malformed or blocked). A
/// person who follows the user (locally recorded) is marked as such.
final publicProfileProvider = FutureProvider.family<PublicProfile?, String>((ref, id) async {
  ref.watch(socialRevisionProvider);
  final p = await ref.watch(userDirectoryProvider).byId(id);
  if (p == null) return null;
  final followsYou = p.followsYou || ref.watch(followRepositoryProvider).followers().contains(id);
  return p.copyWith(followsYou: followsYou);
});

final profilesProvider = FutureProvider.family<List<PublicProfile>, List<String>>((ref, ids) async {
  final out = <PublicProfile>[];
  for (final id in ids) {
    final p = await ref.watch(publicProfileProvider(id).future);
    if (p != null) out.add(p);
  }
  return out;
});

/// Public Scripture shared by people the user follows (Discover).
final followingActivityProvider = FutureProvider<List<(PublicProfile, PublicScriptureActivity)>>((ref) async {
  final ids = ref.watch(followingProvider).toList();
  final people = await ref.watch(profilesProvider(ids).future);
  final items = [
    for (final p in people)
      if (!p.isRestricted) for (final a in p.publicActivity) (p, a),
  ];
  items.sort((a, b) => b.$2.at.compareTo(a.$2.at));
  return items;
});

final socialActionsProvider = Provider<SocialActions>(SocialActions.new);

/// Every social operation goes through here so screens stay thin and the
/// repositories can be swapped for remote ones.
class SocialActions {
  SocialActions(this._ref);
  final Ref _ref;

  DateTime get _now => _ref.read(socialClockProvider)();
  SocialIdentity get _me => _ref.read(socialIdentityProvider);
  void _bump() => _ref.read(socialRevisionProvider.notifier).bump();

  Future<List<PublicProfile>> search(String query) async {
    final blocked = _ref.read(safetyRepositoryProvider).blocked();
    final results = await _ref.read(userDirectoryProvider).search(query, exclude: {_me.userId, ...blocked});
    final followers = _ref.read(followRepositoryProvider).followers();
    return [for (final p in results) p.copyWith(followsYou: p.followsYou || followers.contains(p.userId))];
  }

  /// Creates and sends a direct share. The canonical text is re-read from the
  /// installed Bible; a personalised rendering is never sent as Scripture.
  Future<ScriptureShare> sendScripture({
    required ShareScripture scripture,
    required PublicProfile recipient,
    String? message,
    CareIntent? careIntent,
    String templateId = 'classic',
    SharePrivacy privacy = SharePrivacy.private,
  }) async {
    if (!scripture.isResolvable) throw SocialFailure.invalidScripture;
    // Recipient flags (e.g. "follows you") are re-derived here, never trusted from the UI.
    final verified = await _ref.read(publicProfileProvider(recipient.userId).future);
    final refused = SharePolicy.check(
      sender: _me,
      recipient: verified,
      blocked: _ref.read(safetyRepositoryProvider).blocked(),
    );
    if (refused != null) throw refused;
    final repo = _ref.read(scriptureShareRepositoryProvider);
    final draft = ShareDraft(
      recipientId: verified!.userId,
      references: scripture.sources,
      referenceLabel: scripture.reference,
      translationId: scripture.sourceVersionId!,
      receptionEdition: scripture.personalised ? scripture.translation : null,
      message: message,
      careIntent: careIntent,
      templateId: templateId,
      privacy: privacy,
    );
    final created = await repo.create(draft, sender: _me);
    final delivered = await repo.deliver(created.id);
    await _ref.read(socialSettingsRepositoryProvider).addRecentRecipient(verified.userId);
    _bump();
    return delivered;
  }

  /// Stores an incoming share (from the server, or the on-device demo) and
  /// notifies, respecting the user's privacy and blocking choices.
  Future<bool> receiveShare(ScriptureShare share) async {
    final privacy = _ref.read(socialPrivacyProvider);
    final accepted = SharePolicy.acceptsIncoming(
      senderId: share.senderId,
      privacy: privacy,
      blocked: _ref.read(safetyRepositoryProvider).blocked(),
      following: _ref.read(followRepositoryProvider).following(),
    );
    if (!accepted) return false;
    final added = await _ref.read(scriptureShareRepositoryProvider).receive(share);
    if (!added) return false;
    if (privacy.notifyOnScripture) {
      final preview = share.text.length > 140 ? '${share.text.substring(0, 137).trimRight()}…' : share.text;
      await _ref.read(notificationRepositoryProvider).add(
        InAppNotification(
          id: 'n_${share.id}',
          category: share.careIntent == null ? NotificationCategory.scriptureReceived : NotificationCategory.encouragement,
          title: '${share.senderName} shared a Scripture with you',
          body: share.careIntent?.label,
          actorId: share.senderId,
          actorName: share.senderName,
          shareId: share.id,
          referenceLabel: '${share.referenceLabel} · ${share.translationId}',
          preview: preview,
          message: share.message,
          createdAt: share.createdAt,
          dedupeKey: 'share:${share.id}',
          simulated: share.simulated,
        ),
      );
    }
    _bump();
    return true;
  }

  /// On-device demonstration of receiving a Scripture from a demo person.
  /// Clearly marked as simulated everywhere it appears.
  Future<ScriptureShare?> simulateIncoming({
    required PublicProfile from,
    required ScriptureReference reference,
    String versionId = 'KJV',
    CareIntent? careIntent,
    String? message,
  }) async {
    final passage = await _ref.read(bibleRepositoryProvider).passage(versionId, reference);
    final ids = SocialIds();
    final id = ids.shareId();
    final share = ScriptureShare(
      id: id,
      idempotencyKey: id,
      direction: ShareDirection.received,
      senderId: from.userId,
      senderName: from.displayName,
      recipientId: _me.userId,
      recipientName: _me.displayName,
      references: [reference],
      referenceLabel: reference.label,
      translationId: versionId,
      verses: [
        for (final v in passage.verses)
          if (!v.isOmitted) SharedVerse(bookId: v.bookId, chapter: v.chapter, number: v.number, text: v.text),
      ],
      createdAt: _now,
      status: DeliveryStatus.simulated,
      message: message ?? careIntent?.suggestion,
      careIntent: careIntent,
      simulated: true,
    );
    await _ref.read(userDirectoryProvider).remember(from);
    return await receiveShare(share) ? share : null;
  }

  /// On-device demonstration of a new follower.
  Future<bool> simulateFollower(PublicProfile from) async {
    final added = await _ref.read(followRepositoryProvider).addFollower(from.userId);
    if (added && _ref.read(socialPrivacyProvider).notifyOnFollow) {
      await _ref.read(notificationRepositoryProvider).add(
        InAppNotification(
          id: SocialIds().notificationId(),
          category: NotificationCategory.newFollower,
          title: '${from.displayName} started following you',
          actorId: from.userId,
          actorName: from.displayName,
          createdAt: _now,
          dedupeKey: 'follow:${from.userId}',
          simulated: from.isDemo,
        ),
      );
    }
    _bump();
    return added;
  }

  /// Opens a received or sent share: marks it read and its notification read.
  Future<void> markOpened(ScriptureShare share) async {
    if (share.direction == ShareDirection.received) {
      await _ref.read(scriptureShareRepositoryProvider).markOpened(share.id);
    }
    final notes = _ref.read(notificationRepositoryProvider);
    for (final n in notes.all().where((n) => n.shareId == share.id && !n.isRead)) {
      await notes.markRead(n.id);
    }
    _bump();
  }

  /// Saves a received Scripture to the share history and the Library.
  Future<void> saveShare(ScriptureShare share, {required bool saved}) async {
    await _ref.read(scriptureShareRepositoryProvider).setSaved(share.id, saved);
    final library = _ref.read(savedScriptureProvider.notifier);
    for (final r in share.references) {
      final already = _ref.read(savedScriptureProvider).any((s) => s.reference == r);
      if (saved && !already) await library.toggle(r, versionId: share.translationId);
      if (!saved && already) await library.remove(r);
    }
    _bump();
  }

  Future<ScriptureShare?> acknowledge(ScriptureShare share, AcknowledgementKind kind, {String? message}) async {
    final updated = await _ref
        .read(scriptureShareRepositoryProvider)
        .acknowledge(share.id, kind, fromUserId: _me.userId, message: message);
    _bump();
    return updated;
  }

  Future<void> follow(String userId) async {
    await _ref.read(followRepositoryProvider).follow(userId);
    _bump();
  }

  Future<void> unfollow(String userId) async {
    await _ref.read(followRepositoryProvider).unfollow(userId);
    _bump();
  }

  /// Blocks [userId]: unfollows both ways and removes their notifications.
  Future<void> block(String userId) async {
    await _ref.read(safetyRepositoryProvider).block(userId);
    await _ref.read(followRepositoryProvider).unfollow(userId);
    await _ref.read(followRepositoryProvider).removeFollower(userId);
    await _ref.read(notificationRepositoryProvider).removeFrom(userId);
    _bump();
  }

  Future<void> unblock(String userId) async {
    await _ref.read(safetyRepositoryProvider).unblock(userId);
    _bump();
  }

  Future<void> report(String userId, String reason, {String? shareId, String? details}) async {
    await _ref
        .read(safetyRepositoryProvider)
        .report(SafetyReport(userId: userId, reason: reason, at: _now, shareId: shareId, details: details));
    _bump();
  }

  Future<void> savePrivacy(SocialPrivacySettings settings) async {
    await _ref.read(socialSettingsRepositoryProvider).savePrivacy(settings);
    _bump();
  }

  Future<void> markNotificationRead(String id) async {
    await _ref.read(notificationRepositoryProvider).markRead(id);
    _bump();
  }

  Future<void> markAllNotificationsRead() async {
    await _ref.read(notificationRepositoryProvider).markAllRead();
    _bump();
  }

  Future<void> removeNotification(String id) async {
    await _ref.read(notificationRepositoryProvider).remove(id);
    _bump();
  }

  /// Resolves a share link opened on this device and records it.
  Future<ShareResolution> openLink(String shareId) async {
    final repo = _ref.read(scriptureShareRepositoryProvider);
    final resolution = ShareLinkResolver(repo, currentUserId: _me.userId).resolve(shareId);
    if (resolution.outcome != ShareLinkOutcome.invalid) {
      await repo.recordOpenedLink(
        OpenedShareLink(
          shareId: shareId,
          openedAt: _now,
          outcome: resolution.outcome.name,
          label: resolution.share?.referenceLabel,
        ),
      );
    }
    if (resolution.share case final s?) await markOpened(s);
    _bump();
    return resolution;
  }
}

/// A share link that arrived before onboarding finished (or before sign-in,
/// once accounts exist). Kept on the device so the original share and its
/// attribution are recovered afterwards.
class PendingShareLinkStore {
  PendingShareLinkStore(this._store);
  final KeyValueStore _store;

  String? get pending {
    final id = _store.getString(StorageKeys.pendingShareLink);
    return id != null && shareIdPattern.hasMatch(id) ? id : null;
  }

  Future<void> save(String shareId) async {
    if (shareIdPattern.hasMatch(shareId)) await _store.setString(StorageKeys.pendingShareLink, shareId);
  }

  /// Returns and clears the pending link.
  String? take() {
    final id = pending;
    if (id != null) _store.remove(StorageKeys.pendingShareLink);
    return id;
  }
}

final pendingShareLinkProvider = Provider<PendingShareLinkStore>(
  (ref) => PendingShareLinkStore(ref.watch(keyValueStoreProvider)),
);
