# MWB Offline-First Blueprint

Audit date: 11 November 2026. Part 1 assesses the current Flutter app from its code. Part 2 recommends a target model. **I did not test airplane mode on a device**, so every "works offline" statement below is a code-based conclusion, not runtime evidence.

## Part 1: Current offline capability

| Capability | Local | Needs network | Not implemented | Evidence |
|---|---|---|---|---|
| Read KJV and WEB | ✔ | | | Bundled `assets/bible/*.json`; `AssetBibleRepository` |
| Read KJV-MWB / WEB-MWB | ✔ | | | Bundled rulesets and context; `MwbRenderer` |
| Search the whole installed Bible | ✔ | | | `AssetBibleRepository.search()` |
| Navigate references | ✔ | | | `ScriptureReference.tryParse` |
| Bookmarks, highlights, notes, collections, history | ✔ | | | SharedPreferences (`library_controllers.dart`) |
| Profile, name preference, themes, reading settings | ✔ | | | SharedPreferences; bundled fonts |
| Scheduled Daily Scripture and Daily Promise | ✔ | | | `mock_daily.dart` |
| Topics, content cards, creators | ✔ (mock) | | | `MockContentRepository`; these are samples, not real content |
| Audio playback | Sample tone only | | Real audio | `sample_reflection_tone.wav` |
| Video playback | | | ✔ | Simulated controller; no media |
| Scripture intelligence (promises, prayers, situations…) | | | ✔ | Not in the app |
| Generate and export Scripture cards | | | ✔ | No image pipeline |
| Copy text to share | ✔ | | | Clipboard |
| Native share | | | ✔ | No share plugin |
| Daily reminders | | | ✔ | `DeferredNotificationService.canDeliver = false` |
| Accounts / sync | | | ✔ | Stubs |
| Remote content | | Would need it | ✔ | `RemoteContentRepository` throws "unavailable" |

**Honest answer:** an activated user can study the installed KJV and WEB, and their MWB editions, without internet: read, search, navigate, bookmark, highlight and take notes. They **cannot** yet use any GODSAID intelligence offline (or online), produce shareable cards, or get media beyond a sample tone. The app makes no network calls in its default `mock` mode (`AppConfig.fromEnvironment`, `app_config.dart` 31–36).

One performance note from the previous stage's runtime evidence: cold start took about 60 s on the emulator under memory pressure. The full Bible JSON is parsed on first use (`compute(_parseBible…)`, `bible_repository.dart` 84). This was not profiled on a real device.

## Part 2: Target model

### 2.1 Content classes

| Class | Examples | Delivery | Updates |
|---|---|---|---|
| **Canonical (bundled)** | Public-domain translations, canon, search indexes | In the app bundle | App release |
| **Licensed translations** | NKJV, NIV, NLT (only after permission) | Download after entitlement; encrypted at rest if the licence requires it | Versioned download |
| **Intelligence corpus** | Contexts, promises, situations, prayers, declarations, relationships, journeys, Daily Word candidates and schedule, MWB rulesets and review state | Bundled baseline + versioned content packs | Pack download; the bundled baseline always works |
| **User data** | Library, notes, highlights, signals, Daily Word history, name preference | On the device | Optional backend sync later |
| **Media** | Audio, video, teachings | Streamed; **explicit download** for offline | Per item |
| **Community** | Creator content, comments | Online only | n/a |

### 2.2 Principles

1. **Scripture and its intelligence never need the network.** Bible, search, Daily Word, Discover, Pray and card generation all work in airplane mode.
2. **Versioned packs with integrity checks.** Each pack carries a `corpusVersion` and a checksum. It is applied atomically, so a failed download leaves the previous pack in place.
3. **Approval state ships with rulesets.** A reviewer's approval recorded on the backend reaches devices as a new ruleset version. Devices never render a rule the bundled or downloaded data does not show as validly approved (this is how `PublicationPolicy.approvedOnly` already behaves).
4. **Media is honest.** Downloaded media is marked "available offline". Anything else says it needs a connection. A remote item is never implied to work offline.
5. **Daily Word offline.** The base schedule is bundled. Adaptive selection runs locally on local signals. Notifications are scheduled locally with the day's text pre-rendered, so delivery does not depend on the network.
6. **Cards offline.** Rendering uses bundled fonts and the Flutter canvas (`RepaintBoundary` → PNG, or `PictureRecorder`). Saving uses platform storage. Sharing goes through the OS share sheet, which may itself need a network to *send* — that is expected.
7. **Storage budget.** Measure the APK/AAB (the current debug APK is 216 MB; a release build will be much smaller) and decide per-translation downloads before adding more translations.
8. **Performance.** Pre-build compact binary or JSON indexes in `tool/`. Load lazily per translation. Keep parsing in isolates. Measure cold start on a mid-range physical device.

### 2.3 Offline acceptance tests (to define in a later stage)

- Airplane-mode smoke test on a physical Android device and iOS: open the reader, search "peace", jump to "Ps 23", add a note, view today's Daily Word, generate and save a card.
- Unit tests: the Daily Word schedule resolves for all 366 dates; search returns results for 50 benchmark queries within a time budget; packs roll back on checksum failure.
