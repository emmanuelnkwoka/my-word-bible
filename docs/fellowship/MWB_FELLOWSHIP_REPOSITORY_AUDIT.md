# MWB Fellowship & Growth Engine: Repository Audit (Phase 0)

Audit date: 14 November 2026 · Branch: `main` at `06895be` (clean, equal to `origin/main`) · Flutter 3.47.0 / Dart 3.13.0 · Inspected on Windows 11.

No production code, Bible data, r3 data or navigation was changed for this audit. The only files added are the eight documents in `docs/fellowship/`.

Labels used throughout:

- **[FACT]**: verified in the repository (path given).
- **[PROPOSAL]**: recommended architecture, not built.
- **[OPEN]**: unresolved question.
- **[EXTERNAL]**: depends on a service, vendor, legal or human outside the repository.
- **[BLOCKER]**: must be resolved before a real-user release.

---

## 1. Application architecture

### 1.1 Structure [FACT]

```
lib/
  main.dart                 loads SharedPreferences, ProviderScope
  app/                      app.dart, app_providers.dart (composition root), app_router.dart, app_shell.dart, routes.dart
  core/                     config, constants (storage_keys), errors, network, services, storage, theme, utils, widgets
  data/                     catalogue, mock, models, repositories
  features/<feature>/       application / domain / presentation (some features also widgets/, export/, studio/)
```

Features: audio, bible, content, creator, daily_word, discovery, home, intelligence, library, onboarding, personalisation, profile, search, settings, share, social, upload, video. About 140 Dart files under `lib/`.

### 1.2 State management and dependency injection [FACT]

- Riverpod 3 (`flutter_riverpod: ^3.5.0`), using `Provider`, `NotifierProvider`, `FutureProvider.family`.
- `lib/app/app_providers.dart` is the composition root: every repository and service is a provider ("so tests and future remote implementations can override it without touching features").
- The pattern for swapping local and remote is already in use: `contentRepositoryProvider` and `authRepositoryProvider` choose a mock or remote implementation from `AppConfig.isMock`.
- `keyValueStoreProvider` throws unless it is overridden. It is overridden in `lib/main.dart` with `SharedPreferencesStore`.

### 1.3 Routing and navigation [FACT]

- `go_router: ^18.1.4`. `lib/app/app_router.dart` uses a `StatefulShellRoute` with five branches; `lib/app/app_shell.dart` defines `shellDestinations`: **Home, Bible, Discover, Library, Profile**.
- Full-screen routes use `parentNavigatorKey: rootNavigatorKey`: the reader `/read/...`, `/daily-word`, `/inbox`, `/s/:id`, `/people`, `/sharing/*`, `/review/*`, `/topic`, `/content`, `/search`, `/upload`.
- All paths are centralised in `lib/app/routes.dart`.
- The redirect sends users to `/onboarding` until onboarding is complete.
- **Fellowship routes can be added as root-navigator routes without touching the five-tab shell** ([PROPOSAL]; see the architecture proposal §5).

### 1.4 Configuration [FACT]

`lib/core/config/app_config.dart`. Everything comes from `--dart-define`:

| Define | Effect |
|---|---|
| `MWB_DATA_SOURCE` | `mock` (default) or `remote` |
| `MWB_API_BASE_URL` | Empty by default. `remote` is only honoured when this is set |
| `MWB_NETWORK_LOGGING` | Debug-only path logging |
| `MWB_REVIEW_MODE` | Reviewer tools |

The doc comment says the remote mode is the "Future MWB (Laravel) API". No secrets or URLs are hard-coded. No `.env`, `google-services.json`, `GoogleService-Info.plist`, keystore or `key.properties` is tracked (checked with `git ls-files`).

### 1.5 Network layer [FACT]

- `lib/core/network/api_client.dart` is a Dio wrapper. **It refuses every request in mock mode or when the base URL is empty** (`FeatureUnavailableFailure`).
- `lib/core/network/interceptors.dart` contains `AuthHeaderInterceptor` (bearer token from secure storage, plus `X-Client: mwb-flutter`), `UnauthorizedInterceptor` (on 401 it clears tokens and signals `unauthorizedEventsProvider`) and `SafeLogInterceptor` (never logs headers).
- `mapStatusCode` follows **Laravel conventions**: top-level `message`, and `errors` as `{field: [msg]}` on 422.
- **Inconsistency [FACT]:** `docs/sharing/MWB_BACKEND_API_CONTRACT.md` specifies `{ "error": { "code", "message" } }`, which `mapStatusCode` does not read. This must be reconciled before any backend is built (see API contracts §1).

### 1.6 Errors and logging [FACT]

- `lib/core/errors/app_failure.dart` defines a sealed `AppFailure` with these subtypes: `NetworkFailure`, `TimeoutFailure`, `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`, `ValidationFailure`, `ServerFailure`, `FeatureUnavailableFailure`, `UnknownFailure`. Messages are user-safe.
- Social code adds `SocialFailure(code, message)` in `lib/data/repositories/social_repositories.dart`.
- **There is no crash reporting, remote logging or analytics SDK** (grep for analytics, crashlytics, sentry, firebase and telemetry: none). `PrivacyScreen` (`lib/features/settings/presentation/settings_screens.dart` ~531) tells users "there is no account, no analytics and no advertising tracking". That statement must stay true, or be changed honestly, when Fellowship ships.

### 1.7 Persistence [FACT]

- `lib/core/storage/key_value_store.dart` defines `KeyValueStore`. Reads are synchronous from the in-memory cache; values are JSON in SharedPreferences. Its doc says "a database-backed store (e.g. SQLite/Drift) [can] replace it later". `InMemoryKeyValueStore` is used in tests.
- `lib/core/storage/token_storage.dart` provides `SecureTokenStorage`, which keeps the access and refresh tokens in Keychain/Keystore through `flutter_secure_storage`. Tokens never go to SharedPreferences.
- All keys are versioned in `lib/core/constants/storage_keys.dart` (`mwb.v1.*`).
- `LocalLibraryRepository` (`lib/data/repositories/library_repository.dart`) stores bookmarks, highlights, **notes**, saved Scripture, reading history and so on as JSON lists in SharedPreferences, **unencrypted** beyond Android's app sandbox.
- **There is no SQL database package** in `pubspec.yaml`.

Implications for Fellowship:

- A private journal and an offline event outbox will outgrow a single JSON string per key. There is no transactional store and no encryption at rest for long-form personal text. [OPEN] [see the backend assessment §6]

### 1.8 Design system [FACT]

- Theme files in `lib/core/theme/`: `mwb_themes.dart` (7 themes × light/dark), `mwb_palette.dart`, `mwb_tokens.dart` (spacing, motion), `mwb_typography.dart` (Cormorant Garamond, Lora, Inter, bundled).
- Reusable widgets in `lib/core/widgets/`: buttons, inputs, layout, notices, section headings, segmented controls, selection, sheets, state views, theme selector, bottom nav.
- Fellowship screens should use `context.mwb.*` tokens and these widgets.

### 1.9 Dependencies [FACT]

From `pubspec.yaml`:

- **Dependencies:** `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `shared_preferences`, `intl`, `just_audio`, `share_plus`, `image`, `cupertino_icons`.
- **Dev dependencies:** `flutter_lints`.
- **Not present:** push messaging, local notifications, SQL database, crypto, background work or connectivity package.

### 1.10 Platform [FACT]

- **Android:** `applicationId com.xpatsoft.my_word_bible`. **The release build type signs with the debug key** (`android/app/build.gradle.kts`, `signingConfig = signingConfigs.getByName("debug")`) [BLOCKER for any store release and for verified App Links].
- **Manifest:** `INTERNET`, `WRITE_EXTERNAL_STORAGE` (maxSdk 28), App Link filter for `https://mywordbible.com/s/` (not verified), `mywordbible://app/s/` scheme, and a FileProvider for cards.
- **iOS:** the project exists (`ios/Runner`). It has never been built or tested from this Windows host.

---

## 2. Existing sharing and social system (Phase I)

### 2.1 Inventory [FACT]

| Part | File |
|---|---|
| Models | `lib/data/models/social.dart`: `PublicProfile`, `PublicScriptureActivity`, `SocialIdentity`, `SocialPrivacySettings`, `CareIntent`, **`PrayerRequest`** (model only, no UI), `ScriptureShare`, `SharedVerse`, `ShareDraft`, `ShareAcknowledgement` (`thanks`, `amen`, `prayed`, `reply`), `DeliveryStatus`, `SharePrivacy`, `OpenedShareLink`, `InAppNotification` (categories: Scripture, Followers, Encouragement, Prayer, Replies), `SafetyReport` |
| Repositories (interface → local) | `lib/data/repositories/social_repositories.dart`: `SocialSettingsRepository`, `SafetyRepository` (block, report), `FollowRepository`, `UserDirectoryRepository` (`DemoUserDirectory`), `NotificationRepository`, `ScriptureShareRepository`. Also `SharePolicy`, `SocialIds` and `SocialFailure` |
| Providers | `lib/features/social/application/social_providers.dart`; wiring in `lib/app/app_providers.dart` |
| Domain | `lib/features/social/domain/share_links.dart`: `ShareLinkCodec`, `ShareLinkResolver`, `PendingShareLinkStore` |
| Screens | `lib/features/social/presentation/`: inbox, people, send Scripture, shared Scripture `/s/:id`, share history, sharing privacy, social widgets |
| Cards | `lib/features/share/`: `scripture_image_composer.dart`, `scripture_share_sheet.dart`, `share_service.dart`, `studio/` (Card Studio), `export/` (save and app hand-off) |
| Docs | `docs/sharing/` (8 documents, including `MWB_BACKEND_API_CONTRACT.md`) |
| Tests | `test/sharing/` (4 files) |

### 2.2 Production-ready versus demonstration [FACT]

| Capability | Status |
|---|---|
| Quick share, Card Studio, PNG/JPG export, save to Photos/folder, WhatsApp, Telegram, Instagram and Facebook hand-off (Android) | **Production-quality, on the device** (device-tested in Phase I) |
| Share as text, native share sheet | Production-quality |
| Direct send to an MWB user, inbox, acknowledgements, follows, public profiles, notifications | **Local demonstration.** `DemoUserDirectory` contains 7 invented people (`mwb_demo_*`, `isDemo: true`); delivery status `simulated`; `isLive => false` |
| Block and report | Stored locally only. **Reports reach no one** |
| Push notifications | **Not implemented.** `DeferredNotificationService.canDeliver == false` (`lib/core/services/notification_service.dart`) |
| Deep links | App scheme works on the device. https App Links are unverified (no `assetlinks.json`, debug signing) |
| Prayer requests | Model only (`PrayerRequest`, `PrayerRequestVisibility { privateToSelected, circle, followers }`) |

### 2.3 Reusable for Fellowship [FACT → PROPOSAL]

- `ScriptureShare` already snapshots **canonical** text from `BibleRepository` and refuses personalised editions as the translation (`LocalScriptureShareRepository._canonical`). Scripture Exchange can reuse this unchanged.
- `ShareAcknowledgement.prayed`, `CareIntent` (gentle, non-diagnostic framing), `SharePolicy`, `SafetyRepository`, and the honest `DeliveryStatus` vocabulary.
- **Idempotency is already modelled:** `ScriptureShare.idempotencyKey`, and `NotificationRepository.add` dedupes on `dedupeKey`.
- Card Studio and quick share stay the outward sharing path.

### 2.4 Conflicts with the Fellowship rules [FACT]

1. **Public discovery.** Phase I has username and name search (`UserDirectoryRepository.search`), public profiles (`ProfileVisibility.everyone` is the default), followers and following, and "From people you follow" activity in Discover. The Fellowship directive says **no public people discovery in MVP**. The real backend must not ship directory search or public activity for the pilot. [OPEN: founder decision on the future of the follow system; see the security plan §4]
2. **Prayer visibility.** `PrayerRequestVisibility.followers` exists in the model. In the pilot, prayer audiences must be explicit selected partners only.
3. **Reading-goal nudges.** `NotificationPreferences.readingGoalNudges` exists (off by default; the onboarding copy says "A quiet nudge to spend time in the Word"). There is no delivery. Any Fellowship reminder copy must follow the no-guilt rule.

---

## 3. Scripture Personalisation (r3)

### 3.1 Verified [FACT]

- **Importer:** `tool/build_r3_presentation_layers.js` verifies the SHA-256 of every consumed r3 file against `MWB_REVISED_REVIEW_MANIFEST.json` (`output_fingerprints`). It checks that the 62,205 canonical verses equal the app Bible assets, and writes `assets/mwb/presentation/{kjv,web}-mwb.layers.json`.
- **Engine:**
  - `lib/data/models/mwb_presentation_layer.dart`
  - `lib/data/repositories/mwb_presentation_repository.dart`
  - `lib/features/personalisation/domain/presentation_layer_resolver.dart`
  - Providers in `lib/features/personalisation/application/personalisation_providers.dart`: `mwbPresentationCatalogueProvider`, `editorialNameProvider`, `activeEditorialLayersProvider`.
- **KJV and WEB are separate:** separate assets, and the repository returns an empty catalogue when the edition and source do not match.
- **Presentation model:** `ScripturePresentation` / `scripturePresentationProvider(PresentationRequest)` in `lib/features/personalisation/application/scripture_presentation.dart`. Widgets: `EditorialReception` and `EditorialLayersAround` in `lib/features/personalisation/presentation/presented_scripture.dart`.
- **Integration points:**
  - Reader: `lib/features/bible/presentation/reader_screen.dart`.
  - Daily Word: `daily_word_hero.dart`.
  - Home: `home_screen.dart`.
  - Discover: `people_screens.dart`, via `ScriptureSnippetTile`.
  - Library and Search: `lib/features/bible/widgets/scripture_card.dart`.
  - Sharing: `scripture_share_sheet.dart`, `scripture_image_composer.dart`, `card_studio_renderer.dart`.
- **Report:** `docs/personalization/MWB_R3_IMPLEMENTATION_REPORT.md`.

### 3.2 Rules for Fellowship [PROPOSAL]

- Fellowship screens display Scripture **only** through `BibleRepository` (text) and `EditorialLayersAround` / `scripturePresentationProvider` (presentation). They create no Bible database.
- **Anything sent to another person carries canonical text and a translation id only.** Personal titles and receptions are resolved with the **reader's own** name on their own device, never the sender's. This already holds for direct shares (`ScriptureShare` stores canonical `SharedVerse`s).
- The server stores **references** (`BOOK.chapter.verse`) and a canonical translation id. It may hold its own licensed canonical text to validate references (contract §3 already says so). It never stores personalised renderings.

---

## 4. Backend and infrastructure

| Item | Status [FACT] |
|---|---|
| Authentication | `AuthRepository` interface (`lib/data/repositories/auth_repository.dart`). `DeviceOnlyAuthRepository` is the default (`accountsAvailable = false`). `RemoteAuthRepository` is an empty scaffold. `SignInSheet` exists (`lib/features/profile/presentation/sign_in_sheet.dart`) |
| User profile | On the device: `UserProfile` (first, last and preferred name, gender preference, name preference). **No date of birth, age or email** |
| API client | Built (see §1.5) but disabled by default |
| Server code | **None in this repository.** No other backend repository is referenced |
| Database connections | None |
| Push | None (no FCM/APNs plugin, no `google-services.json`) |
| Local notifications | None (`DeferredNotificationService`) |
| Environment configuration | `--dart-define` only |
| Documented intent | `docs/product/MWB_FRONTEND_PRODUCT_ROADMAP.md`:67 and `ORIGINAL_GODSAID_VISION.md`:98 plan a **Laravel** backend "after the Flutter experience is validated" |

---

## 5. Personal activity data available today [FACT]

| Data | Where | Fit for Fellowship |
|---|---|---|
| Reading history | `ReadingHistoryController` (`lib/features/library/application/library_controllers.dart` ~178). Records a **chapter open** (post-frame in `reader_screen.dart` `_recordHistory`), deduplicated and capped at **50 entries** | **Not sufficient** as "eligible Scripture engagement": opening a chapter is not reading it, and history is overwritten. A separate append-only activity ledger is needed [PROPOSAL] |
| Daily Word history | `DailyWordHistoryController`, keyed by date, with `openedAt`, favourite and stored decision | Good signal for "opened today's Word" |
| Daily Word selection | `DailyWordEngine.select` (`lib/features/daily_word/domain/daily_word_engine.dart`). The annual schedule is the baseline, and **adaptive per-user replacement** applies when personalisation is on | **Daily Word Together must use the schedule baseline (`catalogue.scheduledFor(day)`), not the adaptive choice**, or partners may see different passages |
| Notes | `VerseNote` in SharedPreferences | Reflections must not be mixed with verse notes unless the founder chooses to [OPEN] |
| Clock | `clockProvider` (`lib/features/bible/application/bible_providers.dart`:45) and `socialClockProvider` | Overridable in tests; reuse for rhythm and streak days |

---

## 6. Test infrastructure [FACT]

- Harness: `test/helpers/test_app.dart`. `testOverrides(store)` overrides storage, Bible (disk loader), content, audio, clock (`fixedNow = 2026-11-10 08:30`), rulesets, intelligence, Daily Word and presentation. Also `testContainer` and `pumpMwbApp`.
- Suites: `test/` root (navigation, onboarding, library, search, theme, repository, infrastructure, share composer), `test/daily_word/`, `test/intel/`, `test/mwb/`, `test/sharing/`.
- How Fellowship will be tested: [PROPOSAL; see the roadmap §4]

### 6.1 Baseline (recorded before any Fellowship work)

See §8 below; the commands were run on this commit.

---

## 7. Other observations

- `docs/temp-images/` holds 17 WhatsApp images that are **tracked in git and pushed to GitHub** [FACT]. Their content was not opened for this audit. [OPEN] Confirm they contain no private conversations or personal data.
- `docs/product/MWB_OFFLINE_FIRST_BLUEPRINT.md` Part 1 predates the card, sharing and intelligence work and is partly outdated. It is not authoritative for Fellowship.

---

## 8. Test baseline (actual results)

Recorded on `06895be`, 14 November 2026:

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** (79.0 s), exit 0 |
| `flutter test` | **395 passed, 0 failed, 0 skipped** (about 2 min 25 s), exit 0 |
| Build check | Not re-run for this audit. The last debug APK was built from the same code (r3 report §7). A build adds no information for a documentation-only change |
