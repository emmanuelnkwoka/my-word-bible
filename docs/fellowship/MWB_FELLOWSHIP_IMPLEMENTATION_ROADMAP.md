# MWB Fellowship & Growth Engine: Implementation Roadmap (Phase 0)

Labels: **[FACT]** · **[PROPOSAL]** · **[OPEN]** · **[EXTERNAL]** · **[BLOCKER]**. No phase starts until this foundation is approved.

Complexity is relative, with a rough effort for one experienced developer. These are estimates, not commitments.

- **S:** under 1 week.
- **M:** 1–3 weeks.
- **L:** 3–6 weeks.
- **XL:** more than 6 weeks.

## 1. Phases

| Phase | Scope | Depends on | Complexity |
|---|---|---|---|
| **F0** (this) | Audit and plans | — | done |
| **F1** Local foundation (Layer A) | Personal Word Rhythm, Private Reflection Journal, local activity ledger, Rhythm calendar; **no network** | D1, D2, D3 decisions | M–L |
| **F1b** Local reminders | Daily Rhythm reminder (replaces `DeferredNotificationService` behind the same interface) | D4 (package) | S |
| **F2** Backend foundation | Separate API repository: accounts, verification, recovery, age attestation, devices, `/me` deletion and export, admin with MFA, staging; complete `RemoteAuthRepository` | D5 (backend), D6 (auth), legal L1 | L |
| **F3** Fellowship core and safety | Invitations (link and code), fellowships, pause, resume, leave, block, report, mute; moderation queue; invitation App Link | F2, App Link domain and signing (B1) | L |
| **F4** Scripture Exchange and push | Exchanges and responses on fellowships; FCM push with id-only payloads; notifications screen reuse | F3, Firebase project (E2) | M |
| **F5** Prayer Partnership | Requests with explicit audience, prayed, encouragement, answered, delete | F3, F4, safeguarding protocol (L2) | M |
| **F6** Two-person WordStreak | Participation events, outbox sync, server day close-out, calendar, days together | F1 ledger, F3, F4 (`acted`), D7 (day boundary), D8 (eligible engagement) | L |
| **F7** Daily Word Together | Schedule-pinned shared word, shared thoughts | F3, F6 | M |
| **F8** Closed adult pilot | Release signing, privacy notice, terms, moderation staffing, store listing (internal test track), monitoring | All of the above, plus L1, L2 and B1–B3 | M |

Layer C (circles, organisations, facilitators, family programmes) is **out of scope**. The data model keeps `fellowships.kind`, `members.role` and `organisation_id` open for it.

## 2. Recommended first coding phase: **F1 Local foundation** [PROPOSAL]

### Why F1 first

- It needs no backend, account, legal sign-off or third-party credential.
- It carries no social or safeguarding risk.
- It produces the activity ledger that WordStreak (F6) later depends on.

### Exact scope

1. **Models:** `lib/data/models/fellowship.dart`, with `ActivityEntry`, `ActivityKind`, `JournalEntry`, `RhythmSettings` and `RhythmDay` (derived).
2. **Repositories:** `ActivityLedgerRepository` and `JournalRepository` (interfaces) in `lib/data/repositories/fellowship_repositories.dart`, plus local implementations:
   - over Drift if D1 is approved;
   - otherwise over `KeyValueStore`, with a documented entry cap and a migration path.
3. **Recording hooks (additive only):**
   - the reader records `chapter_read` when D8's rule is met (for example, a minimum dwell or reaching the last verse), alongside the existing `_recordHistory()` [FACT: `reader_screen.dart`];
   - Daily Word records `daily_word_opened` where `openedAt` is set today [FACT];
   - saving a verse records `verse_saved`.

   The existing behaviour of these screens is unchanged.
4. **Rhythm screen** (`/rhythm`): a private month calendar and a gentle weekly summary, with no streak numbers and no comparisons. Entry from a Home card and from Profile.
5. **Journal** (`/journal`, `/journal/:id`):
   - create, edit and delete; link to a Scripture reference, opened through the existing reader;
   - optional Daily Word prompt;
   - "Delete all reflections";
   - encrypted at rest per D2.
6. **Library:** a "Reflections" section. **Settings → Privacy:** the "Stored on this device" list gains Rhythm and Reflections.
7. **Feature flag:** Rhythm and Journal visible by default or behind `MWB_FELLOWSHIP` (D9).
8. **Tests:**
   - unit: ledger append and query, day derivation across timezones and DST, journal encryption round trip;
   - widget: screens in 7 themes × light/dark; journal never rendered with Scripture styles;
   - grep test: journal and ledger keys absent from share, notification and network code;
   - regression: existing 395 tests unchanged.

Not in F1: accounts, partners, outbox network sending, push.

## 3. Decisions needed before F1

| ID | Decision | Recommendation |
|---|---|---|
| D1 | Local database package | Drift (SQLite) |
| D2 | Journal encryption | AES-GCM fields with the key in `flutter_secure_storage` (needs `cryptography`), **or** SQLCipher |
| D3 | Journal versus existing verse notes | Keep separate; notes stay as they are |
| D8 | What counts as "eligible Scripture engagement" | Chapter open plus 60 s of foreground time, or reaching the chapter end; or opening the Daily Word |
| D9 | Show Rhythm and Journal to everyone or behind a flag | Behind a flag until founder review on the device |

## 4. Testing strategy for future modules [PROPOSAL]

- **Isolation:** all Fellowship providers are overridable through `testOverrides` / `testContainer` [FACT: `test/helpers/test_app.dart`]. Add `fellowshipTestOverrides` with in-memory ledger, journal and fake remote repositories, and a controllable clock [FACT: `clockProvider`, `socialClockProvider`].
- **Layout:** new folder `test/fellowship/`. Existing suites are not edited, except to add new overrides to the shared helper when strictly needed.
- **Server:** the API repository has its own test suite: authorisation matrix tests (every endpoint × member / non-member / blocked / paused / ended), idempotency replay tests, and day close-out tests across timezones.
- **Contract:** shared JSON fixtures produced by the server tests and consumed by Flutter `fromJson` tests, so the two cannot drift.
- **Gates for every phase:** `flutter analyze` clean, the full suite green (baseline 395), a device check on the Xiaomi test phone (no posting to real contacts), and a privacy checklist from the security plan §1.

## 5. External dependencies

| ID | Dependency | Needed by |
|---|---|---|
| E1 | Hosting and managed Postgres account | F2 |
| E2 | Firebase project (FCM only) and APNs key | F4 |
| E3 | Transactional email provider | F2 |
| E4 | `mywordbible.com` DNS/hosting for `/.well-known/assetlinks.json`, `apple-app-site-association` and the invitation landing page | F3 |
| B1 | Release signing keystore (currently debug-signed [FACT]) | F3 (App Links), F8 |
| B2 | Apple developer account and an iOS build host (none on this Windows machine [FACT]) | iOS pilot |
| B3 | Play Console internal testing track | F8 |
| L1 | Legal: privacy notice, terms, special-category data basis, data residency | F2 / F8 |
| L2 | Safeguarding protocol and crisis resources | F5 / F8 |
