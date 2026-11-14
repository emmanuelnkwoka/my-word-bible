# MWB Fellowship & Growth Engine: Architecture Proposal (Phase 0)

Labels: **[FACT]** verified in the repository · **[PROPOSAL]** · **[OPEN]** · **[EXTERNAL]** · **[BLOCKER]**. Nothing in this document is built.

## 1. Principles

1. **Extend the app; don't fork it.** Fellowship is a new feature area (`lib/features/fellowship/`) that uses the existing composition root, theme, widgets, Bible and presentation services.
2. **Scripture comes from one source.** Text comes from `BibleRepository`; presentation from `scripturePresentationProvider` / `EditorialLayersAround` [FACT]. Anything sent to another person carries references and a canonical translation id only.
3. **Private by default, shared by act.** Nothing personal leaves the device unless the user performs an explicit share action that names its audience.
4. **Local first.** Layer A works with no account, no network and no server.
5. **Server authoritative for anything two people rely on.** Partnership state, streak days and exchange delivery are decided by the server; the device shows what the server confirmed, or labels it as pending.
6. **Honest states.** Reuse the Phase I vocabulary (`DeliveryStatus`: saved on device, waiting, sent, delivered, not sent) [FACT]. Never claim delivery or completion that was not confirmed.
7. **No engagement economics.** No scores, ranks, badges for volume, grace tokens, loss-aversion copy or public counters.

## 2. Layers

```
┌──────────────────────────── Flutter app ─────────────────────────────┐
│ Layer A (local, no account)            Layer B (requires account)    │
│  Personal Word Rhythm                   Invitations & partnerships   │
│  Private Reflection Journal             Scripture Exchange           │
│  Activity ledger (append-only)          Prayer Partnership           │
│  Local reminders                        Two-person WordStreak        │
│  Downloaded activity packs              Daily Word Together          │
│                                         Safety: block/report/mute    │
│            │                                     │                   │
│            └──► Outbox (only events the user ────┘                   │
│                 chose to share with a partner)                       │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ HTTPS /v1 (existing ApiClient)
                       ┌─────────▼──────────┐
                       │ Fellowship API      │  server authoritative
                       │ (Laravel + Postgres)│  [PROPOSAL, backend doc]
                       └─────────────────────┘
Layer C (later, not built): circles, organisations, facilitator roles, programmes.
```

**The key boundary** is that the local activity ledger records everything for the user's own Rhythm, but only a **minimised participation event** ever reaches the outbox (for example "engaged with Scripture on 2026-11-14"). It never includes the chapter, duration, reflection or journal text unless the user shares a specific item.

## 3. Modules

### 3.1 Personal Word Rhythm (Layer A)

- **Records on device:** reading sessions (chapter opened plus a minimum dwell, or reaching the end of the chapter) [OPEN: definition of "eligible engagement"], Daily Word opened, verses saved, reflections written.
- **Shows:** a private calendar of days with Scripture, gentle weekly summaries, and an optional daily reminder.
- **No numbers are shared, ever.** No "streak at risk" alerts.
- **Data:** a new local ledger. The existing `readingHistoryProvider` remains as it is [FACT: capped at 50 and deduplicated, so unsuitable as evidence].

### 3.2 Private Reflection Journal (Layer A)

- Entries may be linked to a Scripture reference (stored as a reference, not text). Optional prompt from the Daily Word.
- **Stays on the device and is never synchronised in the MVP** [OPEN: optional encrypted backup later].
- **Visibly distinct from Scripture:** a different surface and label ("Your reflection"), never typeset like a verse, never placed inside a Scripture card unless the user explicitly adds it as a clearly labelled personal note. Card Studio already labels personal notes separately [FACT].
- **Excluded from analytics, notifications, search indexing outside the journal, and any AI processing.**

### 3.3 Two-person WordStreak (Layer B)

The rules are taken from the directive. The definitions below are proposals.

**States (pair)**

| State | Meaning |
|---|---|
| `invited` | Invitation sent, not yet answered |
| `active` | Both accepted |
| `paused` | Either partner paused it. Days while paused are `paused`, never `missed` |
| `ended` | A partner left, or blocked the other. Ending is final; a new invitation starts a new pair |

**Day record (server)** for each partnership and fellowship date:

- Per member: `engaged` (eligible Scripture engagement) and `acted` (an intentional action toward the partner).
- Day state:
  - `complete`: both members have both flags;
  - `partial`: someone has done something;
  - `missed`: closed with incomplete participation;
  - `paused`;
  - `open`: the day is not yet closed.

**Evidence**

| Flag | Evidence | Trust level |
|---|---|---|
| `acted` | Server-observed: the Scripture Exchange or exchange response was created on the server, within the day | **Server-verified** |
| `engaged` | Client-attested participation event with a unique `client_event_id`, accepted only if the time and window rules pass | **Server-validated, not proof of reading.** No server can prove someone read; the UI must not imply it |

**Visibility to the partner:** only "✓ took part today" or "not yet". Never what was read, for how long, or any reflection.

**Display of a run of days:** "Days together: 12" counts complete days since the last missed day, excluding paused days. It is visible only to the two partners.

**Missed days:** a calm calendar mark with no wording of failure, for example "No shared day on 12 Nov". There are no notifications about missed days.

**Day boundary [OPEN]:**

- Proposal: each partnership stores one IANA timezone chosen at acceptance (default: the inviter's). Days close at local midnight plus a grace window for offline sync (proposal: 36 h after the day ends).
- Alternative: each member's own local day.

**No grace tokens** (per the directive).

### 3.4 Scripture Exchange (Layer B)

- Built on `ScriptureShare` and `ShareDraft` semantics [FACT].
- In Fellowship the recipient must be an accepted partner (no directory search).
- The server re-resolves canonical text. Optional personal message and `CareIntent`. Responses: thanks, amen, prayed, short reply (`AcknowledgementKind`) [FACT].
- An exchange **counts as the sender's `acted`** for that day. Responding counts as the responder's `acted`.

### 3.5 Prayer Partnership (Layer B)

- A prayer request has an **explicit audience**: one or more accepted partners, chosen every time. There is no default audience, and no followers or public option in the MVP (the existing enum value `followers` is not offered) [FACT: the model exists].
- Partners can mark "prayed" (`AcknowledgementKind.prayed`) and send a short encouragement or a Scripture.
- The author can mark it answered, edit it, close it or delete it. Deletion removes it for the audience too.
- Prayer content is **never** used for advertising, analytics or AI training, and is never shown in push payloads.
- **Safeguarding [BLOCKER]:** prayer text may disclose crisis or self-harm. Before the pilot there must be a written protocol (in-app crisis resources, what moderators may do, and when). Automated scanning of prayer text is **not** proposed (privacy); the protocol relies on reports.

### 3.6 Daily Word Together (Layer B)

- Both partners receive the **scheduled** Daily Word for the shared date: `DailyWordCatalogue.scheduledFor(day)` [FACT]. This is not the adaptive personal choice, which can differ per user (`DailyWordEngine.select`) [FACT].
- The server stores only `(date, scheduleVersion, candidateId)`. Each device renders the text in **its own** translation and edition, with the reader's own personalisation layers.
- Optional "share a thought": a short text explicitly sent to the partner. It is **separate from the private journal** (copying a journal entry into it requires a deliberate action showing exactly what will be sent).
- Opening the Together word can count as `engaged`; sharing a thought or Scripture counts as `acted`.
- [OPEN] Schedule version mismatch between partners on different app versions: the server pins the version, and an older client falls back to "Open in Bible" by reference.

## 4. Flutter structure [PROPOSAL]

```
lib/features/fellowship/
  domain/          rhythm_rules.dart, streak_view.dart (display only; no client authority), event_minimiser.dart
  application/     rhythm_providers.dart, journal_providers.dart, partnership_providers.dart, outbox_service.dart
  presentation/    rhythm_screen.dart, journal_screens.dart, partner_screens.dart, prayer_screens.dart, together_screen.dart
lib/data/models/fellowship.dart                  value types, toJson/fromJson
lib/data/repositories/fellowship_repositories.dart  interfaces + Local* + Remote* implementations
lib/data/local/fellowship_database.dart          (if Drift is approved)
```

Providers are wired in `lib/app/app_providers.dart` in the existing style: `Local*` by default, `Remote*` when `AppConfig` is remote and the user is signed in. A new flag `MWB_FELLOWSHIP` (dart-define, default false) gates all Layer B entry points until the pilot.

## 5. Navigation [PROPOSAL; no change to the five tabs]

- **Entry points, all additive:**
  - a Home card ("Your Word rhythm" / "With your partner");
  - Profile → "Fellowship" (next to the existing "Sharing & fellowship");
  - Library → "Reflections".
- **Root-navigator routes** added to `AppRoutes`:
  - `/rhythm`
  - `/journal`, `/journal/:id`
  - `/fellowship`, `/fellowship/invite`, `/fellowship/p/:partnershipId`
  - `/prayer/:id`
  - `/together/:date`
- **Invitation deep link:** `https://mywordbible.com/i/{token}` plus the app scheme `mywordbible://app/i/{token}`. These need App Link verification [BLOCKER, shared with Phase I].

## 6. Offline and reconciliation [PROPOSAL]

1. Every user action that the server must know about is written first to the local **outbox** with a UUIDv4 `client_event_id`, `occurred_at` (device UTC), `device_local_date` and the timezone offset.
2. The outbox sends in order with exponential backoff. The server upserts by `(user_id, client_event_id)`, so duplicates are no-ops (HTTP 200 with the original result).
3. **The server decides acceptance:**
   - reject `occurred_at` more than 5 min in the future;
   - reject events after the day's grace window has closed (`late_event`);
   - reject events while the pair is paused or ended;
   - Scripture Exchange events are only valid if the exchange exists server-side.
4. The client never sends a streak count, and never computes one for display beyond what the server returned. While offline, it shows "Waiting to sync", not a predicted count.
5. Clock tampering moves `occurred_at` only inside the grace window, and only for the client-attested `engaged` flag. This is accepted as a low-impact risk (risk register R-09).

## 7. Layer C extensibility (not built) [PROPOSAL]

Model a partnership as a **fellowship** with a `kind` (`pair` now; later `circle`, `family`, `organisation_programme`) and a members table with a `role` (`member` now; later `facilitator`). The MVP enforces `kind = pair`, exactly two members, and no roles. Organisations attach later through `organisation_id` on fellowships, without schema rewrites.

## 8. What will not change

- Bible assets and r3 data or engine.
- The Phase I sharing engine and Card Studio. Fellowship calls them; it does not replace them.
- The five-tab shell, themes and settings.
- Demo social features stay demo-labelled. They are not wired to the real backend unless the founder decides so (security plan §4).
