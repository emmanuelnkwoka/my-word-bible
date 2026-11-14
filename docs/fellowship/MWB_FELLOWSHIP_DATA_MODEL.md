# MWB Fellowship & Growth Engine: Data Model (Phase 0, proposed)

Everything here is a **[PROPOSAL]** unless marked **[FACT]**. Server tables assume PostgreSQL (backend assessment §3). Identifiers:

- user ids keep the existing pattern `^mwb_[a-z0-9_]{3,40}$` [FACT: `mwbUserIdPattern`, `lib/data/models/social.dart`];
- other server ids are UUIDv7;
- client event ids are UUIDv4.

## 1. Data classification

| Class | Examples | Leaves device? | At rest |
|---|---|---|---|
| **P0 Public reference** | Scripture references, translation ids, Daily Word candidate ids | Yes | Plain |
| **P1 Account** | Email, display name, timezone, age attestation | Yes (server) | Encrypted volume |
| **P2 Relationship** | Partnerships, invitations, day participation flags | Yes (members only) | Encrypted volume |
| **P3 Sensitive shared** | Prayer requests, exchange messages, shared thoughts, report details | Yes (explicit audience + moderators on report) | Encrypted volume **and** application-level column encryption |
| **P4 Private** | Journal entries, local activity ledger detail, rhythm history | **Never** in the MVP | On-device encryption (journal) / app sandbox (ledger) |

Religious belief is likely special-category or sensitive data in several jurisdictions, which arguably makes every class above P0 sensitive by association [EXTERNAL legal review].

## 2. Local (device) model, Layer A

Stored in the approved local store (Drift/SQLite proposed; [OPEN]). Today's `KeyValueStore` holds only settings [FACT].

| Entity | Fields | Notes |
|---|---|---|
| `activity_entry` | `id` (uuid), `kind` (`chapter_read`, `daily_word_opened`, `verse_saved`, `reflection_written`, `exchange_sent`, `prayer_prayed`), `reference?` (`BOOK.c.v` / chapter), `version_id?`, `occurred_at` (UTC), `local_date` (yyyy-mm-dd), `tz_offset_min`, `dwell_seconds?` | Append-only. Never uploaded. Source of Rhythm |
| `rhythm_settings` | `reminder_enabled`, `reminder_time`, `week_starts_on`, `show_rhythm_on_home` | KeyValueStore is acceptable |
| `journal_entry` | `id`, `created_at`, `updated_at`, `title?`, `body` (**encrypted**), `reference?`, `version_id?`, `prompt_source?` (`daily_word:<date>`), `tags[]` | Never uploaded. Excluded from analytics, logs and crash reports |
| `outbox_event` | `client_event_id`, `type`, `payload` (minimised JSON), `created_at`, `attempts`, `last_error_code?`, `status` (`pending`, `sent`, `rejected`) | Only Layer B events |
| `fellowship_cache` | Last server snapshots of partnerships, days and exchanges, with `fetched_at` | Read-only mirror; labelled "last updated" |
| `activity_pack` | `pack_id`, `version`, `sha256`, `installed_at` | Downloaded pack verification, like the r3 fingerprint approach [FACT: `tool/build_r3_presentation_layers.js`] |

**Minimisation rule:** an `outbox_event` for participation has the form `{type: "participation", partnership_id, local_date, kind: "engaged"}`. No reference, duration or text.

## 3. Server model, Layer B

### 3.1 Identity

```
users(id pk, email citext unique, email_verified_at, password_hash, display_name varchar(60),
      timezone, locale, status [active|suspended|deleting], created_at, deleted_at)
age_attestations(user_id fk, attested_adult bool, method [self_declared], attested_at, policy_version)
sessions / refresh_tokens(id, user_id, token_hash, device_id, expires_at, revoked_at, rotated_from)
devices(id, user_id, platform [android|ios], push_token_enc, app_version, last_seen_at, revoked_at)
consents(user_id, kind [terms|privacy|prayer_processing], version, granted_at, withdrawn_at)
```

- No date of birth is stored in the MVP: self-declared adult attestation only [OPEN, needs legal review].
- No public username is required for Fellowship (there is no discovery).

### 3.2 Fellowship (extensible to Layer C)

```
fellowships(id, kind [pair] , status [invited|active|paused|ended], timezone, created_by,
            created_at, activated_at, paused_at, paused_by, ended_at, end_reason [left|blocked|deleted|expired],
            organisation_id null /* Layer C, unused */)
  CHECK (kind = 'pair')                              -- MVP constraint
fellowship_members(fellowship_id, user_id, role [member], joined_at, left_at,
            features jsonb {streak:bool, prayer:bool, exchange:bool, together:bool}, muted_until)
  UNIQUE(fellowship_id, user_id); trigger: ≤ 2 active members when kind = pair
invitations(id, fellowship_id, inviter_id, token_hash, channel [link|code], expires_at,
            accepted_by, accepted_at, declined_at, revoked_at)
```

- Invitation tokens are 128-bit random values, stored hashed, valid for 7 days [OPEN] and single-use.
- An invitee must be signed in and must have an adult attestation before accepting.

### 3.3 WordStreak

```
participation_events(id, user_id, fellowship_id, client_event_id, kind [engaged|acted],
            source [client_attested|server_exchange|server_response|server_prayer],
            local_date, occurred_at, received_at, accepted bool, reject_code)
  UNIQUE(user_id, client_event_id)
fellowship_days(fellowship_id, date, state [open|partial|complete|missed|paused],
            member_a_engaged, member_a_acted, member_b_engaged, member_b_acted, closed_at)
  PK(fellowship_id, date)
```

- `fellowship_days` is written only by the server: on accepted events, and by the scheduled close-out job.
- "Days together" is **derived** (consecutive `complete` days, skipping `paused`) and never stored as a trusted client value.
- History is kept as long as the fellowship exists; it is deleted with the fellowship when both members have left or deleted their accounts [OPEN: retention].

### 3.4 Scripture Exchange

```
exchanges(id, fellowship_id, sender_id, recipient_id, idempotency_key, references jsonb,
          reference_label, translation_id, verses_snapshot jsonb /* canonical, server-resolved */,
          message_enc, care_intent, created_at, delivered_at, opened_at, deleted_by_sender_at)
  UNIQUE(sender_id, idempotency_key)
exchange_responses(id, exchange_id, user_id, kind [thanks|amen|prayed|reply], message_enc, created_at)
  UNIQUE(exchange_id, user_id, kind) WHERE kind <> 'reply'
```

- The JSON mirrors `ScriptureShare.toJson()` and `ShareAcknowledgement` [FACT], so the Flutter models are reused.
- `translation_id` must be a canonical (non-personalised) version [FACT: the same rule as `_canonical()`].

### 3.5 Prayer Partnership

```
prayer_requests(id, author_id, body_enc, status [open|answered|closed], created_at, updated_at,
                answered_at, answered_note_enc, deleted_at)
prayer_audience(prayer_request_id, user_id, fellowship_id)   -- explicit, ≥1 row required
prayer_responses(id, prayer_request_id, user_id, kind [prayed|encouragement|scripture],
                 message_enc, exchange_id null, created_at)
```

- The audience is fixed when the request is created. Adding people creates new rows only by an explicit author action. Removing someone (or ending the fellowship) revokes their access immediately.

### 3.6 Daily Word Together

```
together_days(fellowship_id, date, schedule_version, candidate_id, created_at)  PK(fellowship_id, date)
together_thoughts(id, fellowship_id, date, author_id, body_enc, created_at, deleted_at)
```

### 3.7 Safety and moderation

```
blocks(blocker_id, blocked_id, created_at)                      -- ends shared fellowships
mutes(user_id, fellowship_id, until)                            -- silences notifications only
reports(id, reporter_id, reported_user_id, object_type, object_id,
        snapshot_enc /* content the reporter chose to submit */, reason, details_enc,
        status [open|reviewing|actioned|dismissed], created_at)
moderation_actions(id, report_id, moderator_id, action [warn|remove_content|suspend|ban|none],
        note, created_at)
audit_log(id, actor_id, actor_role, action, object_type, object_id, at, ip_hash)  -- no content
```

### 3.8 Notifications

```
notifications(id, user_id, category, object_type, object_id, actor_id, created_at, read_at, dedupe_key unique)
```

The push payload is `{type, notificationId}` only [FACT: already required by `MWB_BACKEND_API_CONTRACT.md` §7].

### 3.9 Deletion

```
deletion_requests(user_id, requested_at, scheduled_for, completed_at)
```

- Account deletion:
  - revokes sessions immediately;
  - ends fellowships (`end_reason = deleted`);
  - hard-deletes prayer requests, thoughts, messages and responses authored by the user;
  - removes the user's participation flags.
- Exchanges the user **sent** are deleted for the recipient too [OPEN: or kept as anonymised Scripture-only items in the recipient's history].
- Backups expire on their retention cycle (proposal: 35 days), which is documented to users.

## 4. Mapping to existing Flutter models [FACT → PROPOSAL]

| Existing | Reused for |
|---|---|
| `ScriptureShare`, `SharedVerse`, `ShareDraft` | Exchange |
| `ShareAcknowledgement`, `AcknowledgementKind` | Exchange and prayer responses |
| `CareIntent` | Exchange framing |
| `PrayerRequest` | Prayer (MVP offers only `privateToSelected`) |
| `InAppNotification`, `NotificationCategory` | Fellowship notifications (add categories `fellowship`, `together`) |
| `SafetyReport`, `SafetyRepository` | Reports and blocks (remote implementation) |
| `DailyWordCatalogue.scheduledFor` | Together date and passage |
| `ScriptureReference` | All references |
