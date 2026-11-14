# MWB Fellowship & Growth Engine: Backend Assessment (Phase 0)

Labels: **[FACT]** verified in the repository · **[PROPOSAL]** · **[OPEN]** · **[EXTERNAL]** · **[BLOCKER]**. No backend was installed or configured.

## 1. What the backend must do

These requirements come from the directive and the audit:

| # | Requirement | Why it is needed |
|---|---|---|
| R1 | Accounts, sign-in and recovery | Layer B is impossible without identity. The repository has none [FACT] |
| R2 | An adult-only pilot, with age attestation recorded | No age is collected today [FACT]; the directive restricts the pilot to consenting adult pairs |
| R3 | Relational data with per-pair access control | Partnerships, invitations, exchanges, prayer audiences, blocks. Every read must be scoped to members |
| R4 | **Server-authoritative streak computation** | The directive says client counts are untrusted; reconciliation, pause and missed-day history are domain logic, best done in transactions |
| R5 | Idempotent offline sync | Client-generated UUIDs, safe replay (`idempotencyKey` is already modelled [FACT]) |
| R6 | Push notifications (Android, then iOS) | No push exists [FACT]; payloads must carry no private text (already required by `MWB_BACKEND_API_CONTRACT.md` §7) |
| R7 | Moderation | Reports, a review queue, actions, audit trail. Phase I reports go nowhere [FACT] |
| R8 | Protection of sensitive data | Prayer and religious content is likely special-category data [EXTERNAL legal confirmation] |
| R9 | Backup, restore, deletion, export | User deletion must reach backups within a defined retention period |
| R10 | Low operating cost and a small team | Pilot of consenting adult pairs |
| R11 | No lock-in that would block Layer C | Circles, church accounts, roles, subscriptions later |
| R12 | Real-time | **Not required for MVP.** Pair activity is low-frequency; push plus refresh on open is enough |

## 2. Options compared

Scores: ●●● strong · ●● adequate · ● weak.

| Criterion | A. Laravel + PostgreSQL (modular monolith) | B. Supabase (Postgres + Auth + RLS + Edge Functions) | C. Firebase (Auth + Firestore + Functions) | D. Dart server (Serverpod / Dart Frog) + PostgreSQL |
|---|---|---|---|---|
| Fit with existing client | ●●● `ApiClient` and `mapStatusCode` already follow Laravel conventions; `RemoteAuthRepository` uses bearer tokens [FACT] | ●● The client SDK replaces much of `ApiClient`; the 422 mapping is unused | ● Firestore SDK; the REST client is unused | ●● REST; error mapping needs adapting |
| Documented founder intent | ●●● Laravel named in `app_config.dart`, the roadmap and the vision doc [FACT] | ● | ● | ● |
| Auth and recovery | ●● Sanctum or Passport. Email verification and password reset are built in. Refresh-token rotation needs Passport or custom code [OPEN] | ●●● Hosted auth, magic links, OTP | ●●● Hosted auth | ● Build more yourself |
| Relational data and access control | ●●● Policies and Gates in application code, with tests | ●● Row-level security policies: powerful, but complex pair rules spread across SQL policies | ● Document model; security rules struggle with many-to-many pair rules and joins | ●●● |
| Server-authoritative streak logic | ●●● Transactions, queued jobs, scheduled day close-out | ●● Postgres functions or Deno edge functions; logic split across SQL and TypeScript | ● Cloud Functions plus eventually consistent documents; transactional pair-day logic is awkward | ●●● |
| Real-time (later) | ●● Laravel Reverb / websockets | ●●● Built in | ●●● Built in | ●● |
| Push | ●● FCM HTTP v1 from a queued job (APNs through FCM) [EXTERNAL Firebase project for FCM only] | ●● Same FCM | ●●● Native | ●● Same FCM |
| Offline | Client-owned (outbox) in every option. Firestore's offline cache does not solve server-authoritative streaks | | | |
| Sensitive-data protection | ●●● Encrypted casts for prayer and message columns; full control of logs | ●● Postgres; column encryption is your own code; vendor-hosted | ●● Google-hosted; limited control of field-level encryption | ●●● |
| Backup and deletion | ●● Managed Postgres point-in-time recovery; deletion jobs are yours | ●●● PITR on paid tiers | ●● Export-based | ●● |
| Moderation tooling | ●●● Admin panel ecosystem (e.g. Filament); queue, roles, audit | ●● Build an admin app | ● Build an admin app | ● Build |
| Operating cost (pilot) | ●● One small VM or PaaS, plus managed Postgres | ●●● Free/low tier to start; rises with usage | ●●● Free/low tier | ●● Same as A |
| Vendor lock-in | ●●● Open source; any host | ●● Postgres is portable; auth, RLS and functions are coupled | ● High (Firestore data model, rules) | ●●● |
| Long-term maintainability | ●●● Large hiring pool; mature; conventional | ●● | ●● | ● Smaller ecosystem |
| Layer C (circles, orgs, roles) | ●●● Relational multi-tenant is natural | ●● | ● | ●●● |

## 3. Recommendation [PROPOSAL]

**Option A: Laravel (current LTS-supported major) + PostgreSQL, as one modular monolith exposing a versioned REST API (`/v1`), with FCM used only for push delivery.**

Reasons, in order of weight:

1. **The domain is relational and rule-heavy.** Pairs, invitations, explicit prayer audiences, blocks and server-computed streak days all need transactional, testable application logic. Postgres with application-level policies expresses this most clearly.
2. **It matches what already exists.** The Flutter client's `ApiClient`, bearer-token `TokenStorage`, 401 handling and Laravel-style 422 mapping are already built [FACT]. A Laravel API plugs into `RemoteAuthRepository` and new `Remote*Repository` classes through the existing provider overrides, without a second SDK.
3. **It matches the founder's documented plan** (Laravel, frontend-first) [FACT].
4. **Low lock-in and Layer C ready.** Standard Postgres schema; any host; organisations and roles fit naturally later.
5. **Moderation and admin** are mature in this ecosystem. A pilot without a working report queue would breach the directive.

What it costs, honestly:

- **Hosted auth is easier.** Laravel requires building and securing email verification, password reset, rate limiting and token refresh. This is well-trodden but must be done carefully [OPEN: token model, §5].
- **Someone must operate a server.** Patching, backups, monitoring, on-call. A managed PaaS reduces but does not remove this [EXTERNAL]. **If the founder has no PHP capacity, Option B (Supabase) is the credible fallback**: keep streak computation in Postgres functions called through a thin API, and accept moderate coupling.

**Not recommended:**

- **Firebase as the primary database:** document-model access rules for pair-scoped, server-authoritative data, and high lock-in.
- **A Dart server:** smaller ecosystem and no matching founder intent.

### 3.1 Proposed deployment shape [PROPOSAL]

```
Flutter app ──HTTPS (TLS 1.2+)──► Laravel API (/v1)  ──► PostgreSQL (managed, encrypted at rest, PITR)
                                    │  queue worker ──► FCM HTTP v1 (push: ids only, no text)
                                    │  scheduler    ──► day close-out, retention purge, invite expiry
                                    └  admin panel (moderators, MFA, separate role)
Object storage: not needed for MVP (no user uploads in Fellowship)
Separate repository: `my-word-bible-api` (not in this Flutter repo) [OPEN]
Environments: local · staging (pilot testers) · production
```

### 3.2 Indicative pilot cost [EXTERNAL, unverified]

These are typical public price bands, not quotes, and must be confirmed with providers:

- Small app server or PaaS instance plus a small managed Postgres with backups: a low tens of US dollars per month.
- FCM: no per-message fee.
- Transactional email for verification: free or low tier at pilot volume.

The main cost is people: operations and moderation time.

## 4. Real-time and synchronisation [PROPOSAL]

- **MVP:** push carries `{type, id}` only. The app fetches on open, on push and on pull-to-refresh. The local outbox (see the data model §3) retries with exponential backoff.
- **Later (Layer C groups):** websockets (Reverb) can be added behind the same API without changing data ownership.

## 5. Authentication and recovery [OPEN, with proposal]

- **Proposal:**
  - Email and password **plus** email verification.
  - Password reset by emailed, single-use, 30-minute link.
  - Optional email one-time code sign-in.
  - Short-lived access token (≈15 min) with a rotating refresh token, stored in `SecureTokenStorage` [FACT: it already stores both].
- **Decisions needed:**
  - Phone/SMS sign-in? Cost and SIM-swap risk: not recommended for MVP.
  - Social sign-in (Google, Apple)? Apple sign-in becomes mandatory on iOS if any third-party sign-in is offered [EXTERNAL App Store rule].
  - Sanctum versus Passport for refresh rotation.
- **Account recovery** must never reveal whether an email exists (uniform responses).

## 6. Local storage for Layer A [OPEN, with proposal]

`KeyValueStore` (SharedPreferences JSON) [FACT] is fine for settings and small lists. It is **not** suitable for:

- a growing private journal (whole-list rewrite on every save; no query; no encryption at rest);
- an append-only activity ledger and outbox needing atomic writes.

**Proposal:**

- Add one embedded SQLite layer: **Drift** (typed queries, migrations, testable in memory), behind repository interfaces, as the doc comment in `key_value_store.dart` already anticipates.
- Encrypt journal text at rest with a per-install key held in `flutter_secure_storage`: either SQLCipher (`sqlcipher_flutter_libs`) or field-level AES-GCM (`cryptography`).
- **Each new package needs founder approval** (the directive forbids unnecessary packages); none was added.
- **Alternative without new packages:** a journal in SharedPreferences relying on Android app-sandbox file encryption only. It is weaker, and does not scale past a few hundred entries.

## 7. Push and local notifications [OPEN, with proposal]

- **Local reminders** (Personal Word Rhythm): `flutter_local_notifications` with an Android 13+ runtime permission requested in context [FACT: `NotificationService` already says "only requested contextually"]. Exact-alarm permission is not needed for a daily reminder (use inexact scheduling).
- **Remote push:** `firebase_messaging`, which requires a Firebase project used **only** for FCM [EXTERNAL], `google-services.json` (not committed; injected in CI) and an APNs key for iOS.
- **Payload:** ids only; text is fetched after unlock.

## 8. Release blockers from this assessment [BLOCKER]

1. Choose and approve the backend option, and who operates it.
2. Release signing key (currently debug-signed) [FACT].
3. Legal review of special-category data handling, the privacy notice and terms for the adult pilot.
4. A staffed moderation process: who reviews reports, and how fast.
5. Firebase project and APNs credentials for push, held outside the repository.
