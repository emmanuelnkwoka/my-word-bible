import 'package:flutter/foundation.dart';

import 'scripture_reference.dart';

/// Scripture Sharing & Christian Social Connection models (Phase I).
///
/// Every model here is a plain, JSON-serialisable value so the local
/// repositories can persist it today and a remote API can carry it later
/// without changes to the Flutter features.

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

/// MWB user ids: `mwb_` followed by 3–40 lowercase letters, digits or `_`.
/// Anything else is rejected before any lookup happens.
final mwbUserIdPattern = RegExp(r'^mwb_[a-z0-9_]{3,40}$');

/// Usernames: 3–30 lowercase letters, digits, `.` or `_` (without the `@`).
final mwbUsernamePattern = RegExp(r'^[a-z0-9._]{3,30}$');

bool isValidUserId(String id) => mwbUserIdPattern.hasMatch(id);

/// Who may see a profile.
enum ProfileVisibility {
  everyone('Everyone'),
  followers('People who follow me'),
  onlyMe('Only me');

  const ProfileVisibility(this.label);
  final String label;
}

/// Who may send this person Scripture directly.
enum DirectShareAudience {
  everyone('Anyone on My Word Bible'),
  peopleIFollow('Only people I follow'),
  nobody('No one');

  const DirectShareAudience(this.label);
  final String label;
}

/// The public face of a user. It deliberately holds **no** private data
/// (no email, phone, birthday, location, private follows or struggles):
/// a lookup by id can never reveal more than this.
@immutable
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.visibility = ProfileVisibility.everyone,
    this.acceptsSharesFrom = DirectShareAudience.everyone,
    this.followsYou = false,
    this.isDemo = false,
    this.publicActivity = const [],
    this.tone = 0,
  });

  final String userId;
  final String username;
  final String displayName;
  final String bio;
  final ProfileVisibility visibility;
  final DirectShareAudience acceptsSharesFrom;

  /// Whether this person follows the current user (needed for
  /// [DirectShareAudience.peopleIFollow]).
  final bool followsYou;

  /// Sample person in the on-device demo community, not a real account.
  final bool isDemo;

  /// Scripture this person has chosen to share publicly.
  final List<PublicScriptureActivity> publicActivity;

  /// Avatar tone index (0–5), purely visual.
  final int tone;

  String get handle => '@$username';

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  /// Profiles marked "only me" are found by exact id or username only and
  /// show nothing beyond name and handle.
  bool get isRestricted => visibility != ProfileVisibility.everyone;

  PublicProfile copyWith({bool? followsYou}) => PublicProfile(
    userId: userId,
    username: username,
    displayName: displayName,
    bio: bio,
    visibility: visibility,
    acceptsSharesFrom: acceptsSharesFrom,
    followsYou: followsYou ?? this.followsYou,
    isDemo: isDemo,
    publicActivity: publicActivity,
    tone: tone,
  );

  Map<String, dynamic> toJson() => {
    'id': userId,
    'u': username,
    'n': displayName,
    'bio': bio,
    'vis': visibility.name,
    'acc': acceptsSharesFrom.name,
    'fy': followsYou,
    'demo': isDemo,
    'act': publicActivity.map((a) => a.toJson()).toList(),
    'tone': tone,
  };

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    userId: j['id'] as String,
    username: j['u'] as String,
    displayName: j['n'] as String,
    bio: j['bio'] as String? ?? '',
    visibility: ProfileVisibility.values.asNameMap()[j['vis']] ?? ProfileVisibility.everyone,
    acceptsSharesFrom: DirectShareAudience.values.asNameMap()[j['acc']] ?? DirectShareAudience.everyone,
    followsYou: j['fy'] as bool? ?? false,
    isDemo: j['demo'] as bool? ?? false,
    publicActivity: [
      for (final a in (j['act'] as List? ?? const []))
        if (a is Map<String, dynamic>) PublicScriptureActivity.fromJson(a),
    ],
    tone: j['tone'] as int? ?? 0,
  );
}

/// A verse a person has shared publicly ("Discover public Scripture activity").
@immutable
class PublicScriptureActivity {
  const PublicScriptureActivity({required this.reference, required this.versionId, required this.at, this.note});

  final ScriptureReference reference;
  final String versionId;
  final DateTime at;

  /// A short public reflection (never a private struggle).
  final String? note;

  Map<String, dynamic> toJson() => {
    'ref': reference.toJson(),
    'v': versionId,
    'at': at.toIso8601String(),
    if (note != null) 'note': note,
  };

  factory PublicScriptureActivity.fromJson(Map<String, dynamic> j) => PublicScriptureActivity(
    reference: ScriptureReference.fromJson(j['ref'] as Map<String, dynamic>),
    versionId: j['v'] as String? ?? 'KJV',
    at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    note: j['note'] as String?,
  );
}

/// The current user's MWB identity on this device.
///
/// Until MWB accounts exist, the id is generated locally and the username is
/// only *proposed*: [registered] is false and nothing is published.
@immutable
class SocialIdentity {
  const SocialIdentity({
    required this.userId,
    required this.username,
    required this.displayName,
    this.registered = false,
  });

  final String userId;
  final String username;
  final String displayName;
  final bool registered;

  String get handle => '@$username';

  Map<String, dynamic> toJson() => {'id': userId, 'u': username, 'n': displayName, 'reg': registered};
  factory SocialIdentity.fromJson(Map<String, dynamic> j) => SocialIdentity(
    userId: j['id'] as String,
    username: j['u'] as String,
    displayName: j['n'] as String? ?? '',
    registered: j['reg'] as bool? ?? false,
  );
}

/// The user's sharing and privacy choices.
@immutable
class SocialPrivacySettings {
  const SocialPrivacySettings({
    this.profileVisibility = ProfileVisibility.followers,
    this.whoCanSendScripture = DirectShareAudience.everyone,
    this.showNameOnCards = true,
    this.sharePublicActivity = false,
    this.notifyOnScripture = true,
    this.notifyOnFollow = true,
    this.notifyOnEncouragement = true,
  });

  final ProfileVisibility profileVisibility;
  final DirectShareAudience whoCanSendScripture;

  /// Default for "Shared by …" on new cards (each card can still change it).
  final bool showNameOnCards;

  /// Whether verses you share appear on your public profile. Off by default.
  final bool sharePublicActivity;

  final bool notifyOnScripture;
  final bool notifyOnFollow;
  final bool notifyOnEncouragement;

  SocialPrivacySettings copyWith({
    ProfileVisibility? profileVisibility,
    DirectShareAudience? whoCanSendScripture,
    bool? showNameOnCards,
    bool? sharePublicActivity,
    bool? notifyOnScripture,
    bool? notifyOnFollow,
    bool? notifyOnEncouragement,
  }) => SocialPrivacySettings(
    profileVisibility: profileVisibility ?? this.profileVisibility,
    whoCanSendScripture: whoCanSendScripture ?? this.whoCanSendScripture,
    showNameOnCards: showNameOnCards ?? this.showNameOnCards,
    sharePublicActivity: sharePublicActivity ?? this.sharePublicActivity,
    notifyOnScripture: notifyOnScripture ?? this.notifyOnScripture,
    notifyOnFollow: notifyOnFollow ?? this.notifyOnFollow,
    notifyOnEncouragement: notifyOnEncouragement ?? this.notifyOnEncouragement,
  );

  Map<String, dynamic> toJson() => {
    'vis': profileVisibility.name,
    'who': whoCanSendScripture.name,
    'names': showNameOnCards,
    'public': sharePublicActivity,
    'nScripture': notifyOnScripture,
    'nFollow': notifyOnFollow,
    'nCare': notifyOnEncouragement,
  };

  factory SocialPrivacySettings.fromJson(Map<String, dynamic> j) {
    const d = SocialPrivacySettings();
    return SocialPrivacySettings(
      profileVisibility: ProfileVisibility.values.asNameMap()[j['vis']] ?? d.profileVisibility,
      whoCanSendScripture: DirectShareAudience.values.asNameMap()[j['who']] ?? d.whoCanSendScripture,
      showNameOnCards: j['names'] as bool? ?? d.showNameOnCards,
      sharePublicActivity: j['public'] as bool? ?? d.sharePublicActivity,
      notifyOnScripture: j['nScripture'] as bool? ?? true,
      notifyOnFollow: j['nFollow'] as bool? ?? true,
      notifyOnEncouragement: j['nCare'] as bool? ?? true,
    );
  }
}

// ---------------------------------------------------------------------------
// Care & encouragement
// ---------------------------------------------------------------------------

/// Gentle, optional framing for a shared Scripture. None of these labels
/// implies anything about the recipient's circumstances, and none is ever
/// shown publicly.
enum CareIntent {
  thinkingOfYou("I'm thinking of you", 'I was thinking of you today and wanted to share this.'),
  prayingForYou("I'm praying for you", "I'm praying for you."),
  notAlone("You're not alone", "You're not alone. I'm here with you."),
  dontLoseHope("Don't lose hope", 'This verse reminded me not to lose hope. I hope it encourages you too.'),
  encouragedByThis("I'm encouraged by this", 'This verse encouraged me and I wanted to pass it on.'),
  wantedToShare('I wanted to share this', 'I wanted to share this with you.');

  const CareIntent(this.label, this.suggestion);
  final String label;

  /// Editable starting text. It never asks the recipient to disclose anything.
  final String suggestion;
}

/// Foundation for prayer requests (Phase II). Requests are private by
/// default and are never inferred from shares or reading activity.
enum PrayerRequestVisibility { privateToSelected, circle, followers }

@immutable
class PrayerRequest {
  const PrayerRequest({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.visibility = PrayerRequestVisibility.privateToSelected,
    this.audienceIds = const [],
    this.answeredAt,
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final PrayerRequestVisibility visibility;
  final List<String> audienceIds;
  final DateTime? answeredAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': authorId,
    'text': text,
    'at': createdAt.toIso8601String(),
    'vis': visibility.name,
    'aud': audienceIds,
    if (answeredAt != null) 'answered': answeredAt!.toIso8601String(),
  };

  factory PrayerRequest.fromJson(Map<String, dynamic> j) => PrayerRequest(
    id: j['id'] as String,
    authorId: j['author'] as String,
    text: j['text'] as String,
    createdAt: DateTime.parse(j['at'] as String),
    visibility: PrayerRequestVisibility.values.asNameMap()[j['vis']] ?? PrayerRequestVisibility.privateToSelected,
    audienceIds: [...(j['aud'] as List? ?? const []).whereType<String>()],
    answeredAt: j['answered'] == null ? null : DateTime.tryParse(j['answered'] as String),
  );
}

// ---------------------------------------------------------------------------
// Direct Scripture shares
// ---------------------------------------------------------------------------

/// Who may see a direct share.
enum SharePrivacy {
  /// Only the sender and the recipient.
  private('Private', 'Only you and the recipient can open it'),

  /// The recipient may pass the Scripture on (never your personal message).
  recipientMayReshare('Recipient may pass it on', 'They can share the Scripture onward, without your message');

  const SharePrivacy(this.label, this.description);
  final String label;
  final String description;
}

/// Honest delivery states. Nothing here claims a remote person received
/// anything unless a server confirmed it.
enum DeliveryStatus {
  /// Prepared on this device; not yet handed to any server.
  preparedOffline('Saved on this device'),

  /// Waiting for the MWB sharing service (not connected in this build).
  awaitingServer('Waiting for MWB accounts'),

  /// Sent to a sample person in the on-device demo community. No one else
  /// received it.
  simulated('Simulated (demo person)'),

  /// The server accepted it (remote implementation only).
  sent('Sent'),

  /// The server confirmed delivery to the recipient's device(s).
  delivered('Delivered'),

  /// Could not be sent.
  failed('Not sent');

  const DeliveryStatus(this.label);
  final String label;

  bool get reachedRecipient => this == DeliveryStatus.delivered;
}

enum ShareDirection { sent, received }

/// One canonical verse inside a share: a snapshot of the source translation,
/// verified against the installed Bible when the share is created.
@immutable
class SharedVerse {
  const SharedVerse({required this.bookId, required this.chapter, required this.number, required this.text});

  final String bookId;
  final int chapter;
  final int number;
  final String text;

  ScriptureReference get reference => ScriptureReference(bookId: bookId, chapter: chapter, verseStart: number);

  Map<String, dynamic> toJson() => {'b': bookId, 'c': chapter, 'n': number, 't': text};
  factory SharedVerse.fromJson(Map<String, dynamic> j) => SharedVerse(
    bookId: j['b'] as String,
    chapter: j['c'] as int,
    number: j['n'] as int,
    text: j['t'] as String,
  );
}

/// Acknowledgements a recipient can send back.
enum AcknowledgementKind {
  thanks('Thank you'),
  amen('Amen'),
  prayed('Prayed with this'),
  reply('Replied');

  const AcknowledgementKind(this.label);
  final String label;
}

@immutable
class ShareAcknowledgement {
  const ShareAcknowledgement({
    required this.shareId,
    required this.fromUserId,
    required this.kind,
    required this.at,
    this.message,
    this.status = DeliveryStatus.preparedOffline,
  });

  final String shareId;
  final String fromUserId;
  final AcknowledgementKind kind;
  final DateTime at;
  final String? message;
  final DeliveryStatus status;

  Map<String, dynamic> toJson() => {
    'share': shareId,
    'from': fromUserId,
    'kind': kind.name,
    'at': at.toIso8601String(),
    if (message != null) 'msg': message,
    'st': status.name,
  };

  factory ShareAcknowledgement.fromJson(Map<String, dynamic> j) => ShareAcknowledgement(
    shareId: j['share'] as String,
    fromUserId: j['from'] as String,
    kind: AcknowledgementKind.values.asNameMap()[j['kind']] ?? AcknowledgementKind.thanks,
    at: DateTime.parse(j['at'] as String),
    message: j['msg'] as String?,
    status: DeliveryStatus.values.asNameMap()[j['st']] ?? DeliveryStatus.preparedOffline,
  );
}

/// A Scripture shared directly with one person.
///
/// The Scripture is held as canonical references, the translation id and a
/// verified canonical snapshot. Canonical Bible records are never copied
/// into or changed by a share. A personalised edition is only ever named as
/// [receptionEdition], a hint that the recipient may read the passage in
/// their *own* approved personal presentation; the sender's name-in-text
/// rendering is never sent.
@immutable
class ScriptureShare {
  const ScriptureShare({
    required this.id,
    required this.idempotencyKey,
    required this.direction,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.references,
    required this.referenceLabel,
    required this.translationId,
    required this.verses,
    required this.createdAt,
    required this.status,
    this.receptionEdition,
    this.message,
    this.careIntent,
    this.templateId = 'classic',
    this.privacy = SharePrivacy.private,
    this.simulated = false,
    this.openedAt,
    this.savedAt,
    this.acknowledgements = const [],
  });

  /// Unguessable id; also the deep-link id (`/s/{id}`).
  final String id;

  /// Prevents the same share being delivered twice.
  final String idempotencyKey;
  final ShareDirection direction;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final List<ScriptureReference> references;
  final String referenceLabel;

  /// Source translation id (e.g. "KJV", "WEB"). Never an MWB edition.
  final String translationId;
  final List<SharedVerse> verses;
  final DateTime createdAt;
  final DeliveryStatus status;
  final String? receptionEdition;

  /// Private personal message. Never shown in public link previews.
  final String? message;
  final CareIntent? careIntent;
  final String templateId;
  final SharePrivacy privacy;

  /// Created by the on-device demo community, not a real person.
  final bool simulated;
  final DateTime? openedAt;
  final DateTime? savedAt;
  final List<ShareAcknowledgement> acknowledgements;

  String get deepLinkId => id;
  String get text => verses.map((v) => v.text).join(' ');
  bool get isRead => openedAt != null;
  bool get isSaved => savedAt != null;

  /// Only the two people in the share may open a private share.
  bool canBeOpenedBy(String userId) => userId == senderId || userId == recipientId;

  ScriptureShare copyWith({
    DeliveryStatus? status,
    DateTime? openedAt,
    DateTime? savedAt,
    bool clearSaved = false,
    List<ShareAcknowledgement>? acknowledgements,
  }) => ScriptureShare(
    id: id,
    idempotencyKey: idempotencyKey,
    direction: direction,
    senderId: senderId,
    senderName: senderName,
    recipientId: recipientId,
    recipientName: recipientName,
    references: references,
    referenceLabel: referenceLabel,
    translationId: translationId,
    verses: verses,
    createdAt: createdAt,
    status: status ?? this.status,
    receptionEdition: receptionEdition,
    message: message,
    careIntent: careIntent,
    templateId: templateId,
    privacy: privacy,
    simulated: simulated,
    openedAt: openedAt ?? this.openedAt,
    savedAt: clearSaved ? null : (savedAt ?? this.savedAt),
    acknowledgements: acknowledgements ?? this.acknowledgements,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'idem': idempotencyKey,
    'dir': direction.name,
    'from': senderId,
    'fromName': senderName,
    'to': recipientId,
    'toName': recipientName,
    'refs': references.map((r) => r.toJson()).toList(),
    'label': referenceLabel,
    'tr': translationId,
    'verses': verses.map((v) => v.toJson()).toList(),
    'at': createdAt.toIso8601String(),
    'st': status.name,
    if (receptionEdition != null) 'rx': receptionEdition,
    if (message != null) 'msg': message,
    if (careIntent != null) 'care': careIntent!.name,
    'tpl': templateId,
    'priv': privacy.name,
    'sim': simulated,
    if (openedAt != null) 'opened': openedAt!.toIso8601String(),
    if (savedAt != null) 'saved': savedAt!.toIso8601String(),
    'acks': acknowledgements.map((a) => a.toJson()).toList(),
  };

  factory ScriptureShare.fromJson(Map<String, dynamic> j) => ScriptureShare(
    id: j['id'] as String,
    idempotencyKey: j['idem'] as String? ?? j['id'] as String,
    direction: ShareDirection.values.asNameMap()[j['dir']] ?? ShareDirection.sent,
    senderId: j['from'] as String,
    senderName: j['fromName'] as String? ?? '',
    recipientId: j['to'] as String,
    recipientName: j['toName'] as String? ?? '',
    references: [
      for (final r in (j['refs'] as List? ?? const []))
        if (r is Map<String, dynamic>) ScriptureReference.fromJson(r),
    ],
    referenceLabel: j['label'] as String? ?? '',
    translationId: j['tr'] as String? ?? 'KJV',
    verses: [
      for (final v in (j['verses'] as List? ?? const []))
        if (v is Map<String, dynamic>) SharedVerse.fromJson(v),
    ],
    createdAt: DateTime.parse(j['at'] as String),
    status: DeliveryStatus.values.asNameMap()[j['st']] ?? DeliveryStatus.preparedOffline,
    receptionEdition: j['rx'] as String?,
    message: j['msg'] as String?,
    careIntent: CareIntent.values.asNameMap()[j['care']],
    templateId: j['tpl'] as String? ?? 'classic',
    privacy: SharePrivacy.values.asNameMap()[j['priv']] ?? SharePrivacy.private,
    simulated: j['sim'] as bool? ?? false,
    openedAt: j['opened'] == null ? null : DateTime.tryParse(j['opened'] as String),
    savedAt: j['saved'] == null ? null : DateTime.tryParse(j['saved'] as String),
    acknowledgements: [
      for (final a in (j['acks'] as List? ?? const []))
        if (a is Map<String, dynamic>) ShareAcknowledgement.fromJson(a),
    ],
  );
}

/// What the sender prepares before a share is created.
@immutable
class ShareDraft {
  const ShareDraft({
    required this.recipientId,
    required this.references,
    required this.referenceLabel,
    required this.translationId,
    this.receptionEdition,
    this.message,
    this.careIntent,
    this.templateId = 'classic',
    this.privacy = SharePrivacy.private,
  });

  final String recipientId;
  final List<ScriptureReference> references;
  final String referenceLabel;
  final String translationId;
  final String? receptionEdition;
  final String? message;
  final CareIntent? careIntent;
  final String templateId;
  final SharePrivacy privacy;
}

/// A link that was opened on this device ("Recently opened shared links").
@immutable
class OpenedShareLink {
  const OpenedShareLink({required this.shareId, required this.openedAt, required this.outcome, this.label});

  final String shareId;
  final DateTime openedAt;

  /// `opened`, `notOnDevice`, `forbidden` or `invalid`.
  final String outcome;
  final String? label;

  Map<String, dynamic> toJson() => {'id': shareId, 'at': openedAt.toIso8601String(), 'o': outcome, 'l': label};
  factory OpenedShareLink.fromJson(Map<String, dynamic> j) => OpenedShareLink(
    shareId: j['id'] as String,
    openedAt: DateTime.parse(j['at'] as String),
    outcome: j['o'] as String? ?? 'opened',
    label: j['l'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

enum NotificationCategory {
  scriptureReceived('Scripture'),
  newFollower('Followers'),
  encouragement('Encouragement'),
  prayer('Prayer'),
  acknowledgement('Replies');

  const NotificationCategory(this.label);
  final String label;
}

/// A persistent in-app notification record.
@immutable
class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.createdAt,
    required this.dedupeKey,
    this.body,
    this.actorId,
    this.actorName,
    this.shareId,
    this.referenceLabel,
    this.preview,
    this.message,
    this.readAt,
    this.simulated = false,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String? body;
  final String? actorId;
  final String? actorName;
  final String? shareId;
  final String? referenceLabel;

  /// Short Scripture preview.
  final String? preview;
  final String? message;
  final DateTime createdAt;
  final DateTime? readAt;

  /// One notification per event: a second record with the same key is ignored.
  final String dedupeKey;

  /// Created on this device to demonstrate the experience.
  final bool simulated;

  bool get isRead => readAt != null;

  InAppNotification markRead(DateTime at) => InAppNotification(
    id: id,
    category: category,
    title: title,
    createdAt: createdAt,
    dedupeKey: dedupeKey,
    body: body,
    actorId: actorId,
    actorName: actorName,
    shareId: shareId,
    referenceLabel: referenceLabel,
    preview: preview,
    message: message,
    readAt: readAt ?? at,
    simulated: simulated,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'cat': category.name,
    'title': title,
    if (body != null) 'body': body,
    if (actorId != null) 'actor': actorId,
    if (actorName != null) 'actorName': actorName,
    if (shareId != null) 'share': shareId,
    if (referenceLabel != null) 'ref': referenceLabel,
    if (preview != null) 'preview': preview,
    if (message != null) 'msg': message,
    'at': createdAt.toIso8601String(),
    if (readAt != null) 'read': readAt!.toIso8601String(),
    'key': dedupeKey,
    'sim': simulated,
  };

  factory InAppNotification.fromJson(Map<String, dynamic> j) => InAppNotification(
    id: j['id'] as String,
    category: NotificationCategory.values.asNameMap()[j['cat']] ?? NotificationCategory.scriptureReceived,
    title: j['title'] as String,
    body: j['body'] as String?,
    actorId: j['actor'] as String?,
    actorName: j['actorName'] as String?,
    shareId: j['share'] as String?,
    referenceLabel: j['ref'] as String?,
    preview: j['preview'] as String?,
    message: j['msg'] as String?,
    createdAt: DateTime.parse(j['at'] as String),
    readAt: j['read'] == null ? null : DateTime.tryParse(j['read'] as String),
    dedupeKey: j['key'] as String? ?? j['id'] as String,
    simulated: j['sim'] as bool? ?? false,
  );
}

/// A report about a person (kept on this device until moderation exists).
@immutable
class SafetyReport {
  const SafetyReport({required this.userId, required this.reason, required this.at, this.shareId, this.details});

  final String userId;
  final String reason;
  final DateTime at;
  final String? shareId;
  final String? details;

  Map<String, dynamic> toJson() => {
    'user': userId,
    'reason': reason,
    'at': at.toIso8601String(),
    if (shareId != null) 'share': shareId,
    if (details != null) 'details': details,
  };

  factory SafetyReport.fromJson(Map<String, dynamic> j) => SafetyReport(
    userId: j['user'] as String,
    reason: j['reason'] as String,
    at: DateTime.parse(j['at'] as String),
    shareId: j['share'] as String?,
    details: j['details'] as String?,
  );
}
