# My Word Bible (MWB) — Flutter Foundation V1

A premium, Scripture-centred Christian engagement and discovery app for Android and iOS.
Foundation V1 is the frontend plus its local functional foundation. **There is no backend**:
everything runs offline on the device using bundled Scripture, local sample content and local persistence.

## Run it

```bash
flutter pub get
flutter analyze
flutter test
flutter run                 # Android device/emulator (Windows dev machine)
flutter build apk --debug   # build/app/outputs/flutter-apk/app-debug.apk
```

iOS sources and project configuration are maintained in `ios/`, but building and running iOS
requires macOS with Xcode. iOS has **not** been runtime-verified from the Windows environment.

### Configuration (`lib/core/config/app_config.dart`)

Mock mode is the default. The future API is configured only through build flags — no URLs or secrets in source:

```bash
flutter run --dart-define=MWB_DATA_SOURCE=remote --dart-define=MWB_API_BASE_URL=https://api.example.com/v1
```

Remote repositories are scaffolds that report "not available yet" until the redesigned Laravel API contract exists.

## What is in Foundation V1

| Area | Status |
| --- | --- |
| Theme engine | 7 themes (Classic Gold default) × light/dark, full semantic palettes, system/light/dark, live preview, persisted |
| Typography | Bundled OFL fonts: Cormorant Garamond (editorial), Lora (Scripture), Inter (UI) |
| Onboarding | 4 steps, validation, back/continue/skip, progress, keyboard & safe-area handling, persisted completion |
| Navigation | 5 tabs (Home, Bible, Discover, Library, Profile) with per-tab navigation stacks preserved; fade tab transitions |
| Bible | **Complete KJV** (public domain, 66 books / 31,102 verses) offline: books, chapters, reader, verse selection, highlights (4 tones), bookmarks, notes, saved verses, copy-to-share, text size, reading surfaces, chapter navigation across books, history |
| Discover | Search entry, trending topics, 16 topic categories (+ related topics), type filters, featured, recommended (by interests), recently added, Scripture collections, creators |
| Topic pages | Scripture + audio + video + articles + teachers + related topics (e.g. **Fear**), filterable |
| Search | Unified local search: reference parsing ("John 3:16", "1 cor 13"), KJV word search, topics (incl. keywords), content, creators, saved items, category filters, suggestions, recent searches |
| Library | Saved Scripture, bookmarks, highlights, notes, saved audio/video/messages, collections, reading history, recently viewed, contributions (drafts), downloads placeholder |
| Media | Audio player (play/pause, ±15s, seek, duration, speed, shared mini player) via just_audio; video player interface (play/pause, seek, duration, full screen) |
| Upload | Contribution flow (short video / audio / audio-from-video), validation, topic & Scripture tagging, attribution, rights confirmation, review, saved as local draft |
| Profile & settings | Personal info, theme & appearance, reading, notifications, content preferences, privacy & data (clear/reset with confirmation), account (guest state), about, help |
| Infrastructure | Dio client, auth/401/logging interceptors, timeouts, standard `AppFailure` mapping, secure token storage, repository interfaces, mock/remote boundary |

## Honest limitations (by design for this milestone)

- **Sample content**: creators, messages and articles are fictional samples, labelled "Sample" in the UI.
- **Audio** plays an original generated tone (`tool/generate_sample_tone.js`) in place of message recordings. The player discloses this. No sermon recordings or unlicensed media are bundled.
- **Video** has no bundled media. The player runs a simulated playhead over the listed duration and states this clearly.
  A `video_player`-backed `VideoPlaybackController` can be added once hosted, licensed media exists.
- **Translations**: KJV and WEB are installed (public domain, offline). NKJV, NIV and NLT require publisher licences and stay disabled.
- **MWB editions**: KJV-MWB and WEB-MWB are selectable. No personalisation rule has a recorded theological approval yet, so in normal use both read exactly as their source; proposals are visible only in the reviewer preview.
- **WEB omissions**: the WEB omits Luke 17:36, Acts 8:37, 15:34, 24:7 and Romans 16:25 (it places the Romans doxology at 14:24–26). The reader shows a note for those numbers. Psalm titles are part of verse 1 in the eBible source.
- **Notifications**: reminder preferences and time are saved; delivery is deferred (`DeferredNotificationService`). Permission is never requested on first launch.
- **Accounts**: guest session only (`DeviceOnlyAuthRepository`). The sign-in UI validates locally and explains that accounts are not live.
- **Background audio**: architecture-ready (`AudioPlaybackService` boundary); lock-screen/notification controls need `audio_service` + platform config.
- **Search** is keyword-based on the device; meaning-based search is left to the future backend.
- Creator rewards, payments, media hosting and moderation services are out of scope.

## Scripture integrity rules

- Canonical text is never modified. Personalisation ("For you today, Grace") and declarations are rendered
  **separately** from the verse, which always shows its reference and version.
- Gender preference never changes Scripture wording.
- `test/repository_test.dart` verifies every Scripture reference in sample data exists in the KJV text.

## MWB editions and the personalisation engine (Phase 2, Stages A–B)

MWB is a selectable personalised Bible edition per source translation (KJV → KJV-MWB, NKJV → NKJV-MWB, NIV → NIV-MWB,
NLT → NLT-MWB, WEB → WEB-MWB). Each edition is derived from its own source and keeps that version's vocabulary and style.

- **WEB text**: `assets/bible/web.json`, built from eBible.org's public-domain `engwebp` verse-per-line edition with
  `node tool/build_web_asset.js <engwebp_vpl.txt> assets/bible/web.json` (wording copied exactly; omitted verses recorded).
  "World English Bible" is an eBible.org trademark: personalised text is never called the World English Bible.
- **Reader**: an MWB edition reads its source's canonical text and shows only *approved* renderings (personal words in gold).
  The app-bar version button and the switch button move between an original and its MWB edition at the same chapter.
- **Reviewer preview** (debug and `MWB_REVIEW_MODE` builds only; switch in Reading settings): proposals appear *under* their verses
  labelled "PROPOSED — NOT APPROVED"; tapping one shows the original, proposal, operation, risk, status, context and question.

- **Catalogue** (`lib/data/catalogue/version_catalogue.dart`): originals and MWB editions with source links, availability,
  licence records (holder, offline storage, distribution, **derivative-work permission**, attribution, quotation limits) and
  review policy. A version is selectable only with technical support *and* legal permission. One shared picker
  (`features/bible/widgets/version_picker.dart`) is used by the reader, onboarding and settings.
- **Rules** (`assets/mwb/rulesets/kjv-mwb.json`, `web-mwb.json` — independent, each written against its own source text): version-specific, one verse each, anchored to the exact source text.
  Operations: `insertDirectAddress`, `appendPersonalName`, `insertNameAfterExistingAddress`, `punctuationAdjustment`,
  `approvedMinimalGrammaticalAdjustment`. Statuses: proposed → automatedValidated → underReview → approved / rejected / retired.
- **Context** (`assets/mwb/passage_context.json`): human-authored author, speaker, audience, addressee type, conditional
  promises and relationships. Drives risk (low / medium / high / critical).
- **Validator** (`features/personalisation/domain/personalisation_validator.dart`): version match, exact source text, anchors,
  name-only insertions, punctuation, minimal-change and vocabulary limits, gendered-term preservation, exact recovery,
  approval integrity, risk consistency.
- **Renderer** (`mwb_renderer.dart`): returns source-linked segments; any failed condition returns the untouched source.
  Renderings are never persisted. Production publishes only rules with a recorded human approval for the current rule version.
  Reviewer builds can preview candidates: `flutter run --dart-define=MWB_REVIEW_MODE=true`.
- **Names**: full name (default), first name, preferred name or none. A missing surname falls back to the first name; nothing is invented.
- **Theological review**: [docs/mwb/kjv-mwb-review-queue.md](docs/mwb/kjv-mwb-review-queue.md) and
  [docs/mwb/web-mwb-review-queue.md](docs/mwb/web-mwb-review-queue.md) are generated from the rules for the
  designated supervisor. Regenerate after editing rules: `UPDATE_REVIEW_QUEUE=1 flutter test test/mwb/validation_and_review_test.dart`.
  Decisions are recorded through `ReviewQueueService.recordDecision` (approval requires a named reviewer and passing validation).

## Architecture

```
lib/
  app/            app.dart, app_router.dart (GoRouter + StatefulShellRoute), app_shell.dart, app_providers.dart, routes.dart
  core/
    config/       AppConfig (mock/remote, base URL, timeouts)
    constants/    storage keys
    errors/       AppFailure hierarchy
    network/      ApiClient (Dio), interceptors, error mapping
    services/     NotificationService
    storage/      KeyValueStore (SharedPreferences / in-memory), TokenStorage (secure storage)
    theme/        palettes, 7 theme definitions, typography, tokens, ThemeData builder + MwbTheme extension
    utils/        formatters
    widgets/      buttons, inputs, selection, chips, segmented, sheets/dialogs, state views, nav bar, theme selector, layout
  data/
    models/       Bible canon & references, content (AUDIO/VIDEO/ARTICLE/SCRIPTURE_REFERENCE), creators, topics,
                  library items, moderation, uploads, reports, user preferences
    repositories/ interfaces + local/mock implementations + remote scaffolds
    mock/         topics, creators, content, daily Scripture/promises
  features/       onboarding, home, bible, discovery, content, search, library, profile, settings, audio, video, creator, upload
                  (each with application/ state and presentation/ UI)
```

Key decisions:

- **Riverpod 3** `Notifier`s for state; all dependencies are providers so tests (and future remote implementations) override them.
- **Synchronous local reads, async writes** (`KeyValueStore`): preferences and library are available before the first frame — no theme flash, no onboarding flicker.
- **JSON-in-SharedPreferences** for Foundation V1 library data behind `ListStore<T>`; swap for a database without touching features.
- **Stable book IDs** (USFM-style `JHN`, `1CO`) decouple references from any translation or backend schema.
- **Root-level routes** for the reader, topics, content, creators, search and upload so they open from any tab and return correctly.
- Filled buttons use each theme's deeper `primaryStrong` tone for legible labels; the brighter `primary` is used for detailing.

## Assets & licences

- `assets/bible/kjv.json` — King James Version (public domain), converted by `tool/build_kjv_asset.js`.
- `assets/fonts/` — SIL Open Font License 1.1 (texts in `assets/licenses/`, viewable in-app under About).
- `assets/audio/sample_reflection_tone.wav` — original generated tone.

## Tests

`flutter test` covers theme definitions/contrast/persistence, onboarding validation/persistence/UI flow, five-tab navigation
and state preservation, the reader (canonical text, bookmarks, chapter navigation, history), all 7 themes × light/dark
rendering, small-phone and tablet layouts, bookmarks/notes/highlights/collections persistence, search and filters,
repositories and sample-data integrity, the version catalogue and picker, the MWB renderer/validator/review queue (`test/mwb/`), network error mapping and 401 handling, audio/video controllers and player UI, and upload validation.
