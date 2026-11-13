# Flutter Implementation Audit

- **Project:** `C:\xpatsoft\my-word-bible`
- **Audit date:** 11 November 2026
- **Last commit:** `921e638` (merge on `main`); 26 working-tree entries are uncommitted, including the KJV/WEB activation work and the untracked demo HTML.
- **Size:** 114 Dart files under `lib/` (17,813 lines); 13 test files (2,726 lines).

## Evidence gathered on 11 Nov 2026

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** (83.8 s) |
| `flutter test` | **162 passed, 0 failed** |
| Debug APK | `build/app/outputs/flutter-apk/app-debug.apk`, built 11 Nov 2026 12:35 (216,420,228 bytes) |
| Runtime on Android | Done in the previous stage (same day) on `emulator-5554`, with screenshots: home, version picker, WEB search, WEB-MWB reader (Prov 23), reviewer preview cards, switch to WEB at the same chapter. **No other screens were runtime-verified in this audit.** |
| Ephesians 2:10 validator probe | A throwaway test was run from the scratchpad (not added to the project). Results are in §5. |

## 1. Architecture and stack

| Layer | Evidence |
|---|---|
| **Flutter and Dart** | Flutter 3.47 / Dart 3.13 (`pubspec.yaml`, `sdk: ^3.13.0`) |
| **Dependencies** | `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `shared_preferences`, `intl`, `just_audio`. **Absent:** `share_plus`, `path_provider`, any SQLite/FTS package, `video_player`, a local-notifications plugin, any image-export or `screenshot` package. |
| **Composition** | `lib/app/app_providers.dart`: repositories exposed as providers. `AppConfig.fromEnvironment()` (`lib/core/config/app_config.dart` 31–36) defaults to `MWB_DATA_SOURCE=mock`; remote mode needs `MWB_API_BASE_URL`. |
| **Persistence** | `SharedPreferencesStore` (`lib/core/storage/key_value_store.dart` 53–59). Typed list stores live in `LibraryRepository`. Tokens are stored via `flutter_secure_storage` (`token_storage.dart`). |
| **Routing** | `lib/app/app_router.dart`: `StatefulShellRoute` with 5 branches; full-screen root routes for `/read/:bookId/:chapter`, `/topic`, `/content`, `/creator`, `/search`, `/upload` |
| **Theme** | 7 named themes (`MwbThemeId` in `lib/core/theme/mwb_themes.dart` 6–13), each with light and dark variants; system/light/dark mode (`appearance_controller.dart`); bundled OFL fonts (Cormorant Garamond, Lora, Inter) |

## 2. Navigation (as built)

`shellDestinations` (`lib/app/app_shell.dart`) has five tabs: **Home, Bible, Discover, Library, Profile**.

There is **no** Daily Word page, Pray tab, Poster Studio, Insights page or drawer. Search is a root route opened from the screens.

## 3. Bible text, reader and versions

| Feature | Files / symbols | Behaviour | Tests |
|---|---|---|---|
| **KJV offline** | `assets/bible/kjv.json`; `AssetBibleRepository` (`lib/data/repositories/bible_repository.dart` 63–140), parsed in an isolate (`compute`, line 84) | 66 books / 1,189 chapters / 31,102 verses, checked by script 11 Nov 2026 | `repository_test.dart` |
| **WEB offline** | `assets/bible/web.json` (eBible.org engwebp); `tool/build_web_asset.js` | 66 books / 1,189 chapters; 5 omitted verses recorded (`Verse.isOmitted`) | `web_and_editions_test.dart` |
| **Version catalogue** | `lib/data/catalogue/version_catalogue.dart`; `VersionCatalogue.isSelectable` | KJV, KJV-MWB, WEB and WEB-MWB are selectable. NKJV, NIV, NLT and their MWB editions are listed but disabled (licence `notGranted`). | `version_catalogue_test.dart` |
| **Reader** | `lib/features/bible/presentation/reader_screen.dart` (818 lines), `reader_sheets.dart` | Chapter view; verse selection; bookmarks, highlights and notes; font and surface preferences; previous/next chapter; version button (`reader-version`, line 237); switch to the paired edition; omitted-verse note; copy with attribution (lines 749–750) | `web_and_editions_test.dart`, `library_test.dart` |
| **Reading position and history** | `readingHistoryProvider` (`library_controllers.dart` 177) | "Continue reading" and "Recently read" on Home (`home_screen.dart` 233, 328) | `library_test.dart` |

## 4. Search

| Aspect | Evidence | Actual behaviour |
|---|---|---|
| **Entry** | `lib/features/search/presentation/search_screen.dart` | A text field with a **300 ms debounce** (line 63), so results update while typing |
| **Orchestration** | `LocalSearchRepository.search()` (`lib/data/repositories/search_repository.dart`) | If the query parses as a reference, opens that passage. Otherwise runs a Bible keyword search, plus topic, content and creator search over mock data. Topic hits pull in tagged content. |
| **Bible matching** | `AssetBibleRepository.search()` lines 117–139 | Lower-cases the query; drops 1-letter words; returns the **first N verses in canonical order** where **every word is a substring** of the verse. A lazy lower-case index is used (line 41). |
| **Ranking** | — | **None.** Results come in canonical order. There is no exact-phrase priority, stemming, spelling tolerance or relevance score. |
| **Phrase search** | — | Not implemented. Quotes are not parsed; words are matched independently. |
| **Reference parsing** | `ScriptureReference.tryParse()` (`lib/data/models/scripture_reference.dart` 65–66) | Book name or abbreviation + chapter (+ verse, + range); `:` or `.` separators. A book name **without** a chapter (for example "Romans") is not a reference. |
| **Categories** | `SearchCategory` (`lib/data/models/search.dart` 10–18) | All, Scripture, Topics, Audio, Video, Articles, Creators, Saved |
| **Intelligence objects** | — | **Not searchable.** There are no promises, prayers, declarations, blessings, life situations or Daily Words to search. |
| **Recent searches** | `recentSearchesProvider` (`library_controllers.dart` 255) | Stored locally |
| **Tests** | `search_test.dart` (12 tests) | |

## 5. MWB personalisation engine

| Component | File | Role |
|---|---|---|
| **Rule model** | `lib/data/models/mwb_rule.dart` | `PersonalisationOperation` (5 controlled ops), `EditPosition {before, after, replace}`, `RuleStatus`, `RiskLevel`, `ReviewRecord`, `VersionStyleProfile` (303) |
| **Edit engine** | `domain/edit_engine.dart` | Locates exact anchors and applies edits as segments with `original`, so the source can be recovered exactly |
| **Validator** | `domain/personalisation_validator.dart` | Version integrity; exact source text; edit shape; `{name}` only; insertion adds only name and punctuation; minimal adjustment ≤2 words changed; foreign vocabulary; gendered-term preservation; punctuation defects; recovery; approval integrity; risk |
| **Risk** | `domain/risk_assessor.dart` | Divine speech → critical; collective, specific person, addressed to God, conditional, or specific relationship → high; missing context → medium |
| **Renderer** | `domain/mwb_renderer.dart` 14–35 | `approvedOnly` publishes only rules with a valid recorded approval; `reviewPreview` shows open rules; failures fall back to the source |
| **Processor and review queue** | `ruleset_processor.dart`, `review_queue.dart` | Skip, flag and continue; markdown exports in `docs/mwb/` |
| **Name resolution** | `domain/personal_name.dart` | Full, first, preferred or none; rejects unsafe characters; never invents a name |
| **Reader integration** | `application/mwb_reader_providers.dart`, `presentation/mwb_review_widgets.dart` | Edition banner; gold personal segments; reviewer cards labelled "PROPOSED — NOT APPROVED" |
| **Rulesets** | `assets/mwb/rulesets/kjv-mwb.json` (21 rules: 20 proposed, 1 rejected), `web-mwb.json` (20 proposed) | **0 approved.** Almost all are the "My son" vocative in Proverbs, plus Prov 23:18, Isa 41:10 and 3 John 1:2. |
| **Passage context** | `assets/mwb/passage_context.json` | **9 contexts only:** PRO 1:8, 1:8-9, 2:1-5, 6:20-23, 22:17, 23:17-18, 25:1, ISA 41:8-16, 3JN 1:1-4 |
| **Tests** | `renderer_test.dart` (23), `validation_and_review_test.dart` (20), `version_catalogue_test.dart` (14), `web_and_editions_test.dart` (21 + generated) | |

**User-facing effect today:** because nothing is approved, **KJV-MWB and WEB-MWB read exactly like KJV and WEB** in normal mode. Personalised wording appears only in the reviewer preview (debug builds or `MWB_REVIEW_MODE`).

### Ephesians 2:10: where the defect lives and what the validator does

- **Origin.** The rendering "For Emmanuel Nkwoka is his workmanship…" is the **demo's** curated substitution (`MY_WORD_BIBLE_MWB_DEMO (1).html` line 1234).
- **Flutter has no Eph 2:10 rule.** Searching `workmanship` / `EPH 2:10` finds only the Bible assets and two mock topic/content references (`mock_topics.dart` 113, `mock_content.dart` 465–468). The founder's screenshot therefore shows the HTML demo, not the Flutter app. I have not seen that screenshot, so this conclusion rests on the code evidence alone.
- **Why the demo allowed it.** Its `subs` strategy applies any curated string pair and checks only that the find-string exists (lines 1603–1608). It has no grammar, person, number or gender checks.
- **Would the Flutter validator catch it?** I ran a probe (a scratch test, not committed) against the shipped validator and the real KJV text:

| Case | Expressed as | Result |
|---|---|---|
| A. Demo rendering (`we are`→`{name} is`; `that we should walk`→`that he should walk`) | 2 × `approvedMinimalGrammaticalAdjustment` | **Fails:** `foreignVocabulary` ("is", "he"), `genderedTermChanged` |
| B. Subject only (`we are`→`{name} is`) | 1 × adjustment | **Fails:** `foreignVocabulary` ("is") |
| C. As B, but the style list allows "is" | 1 × adjustment | **Passes** (warnings only: `contextMissing`, `riskUnderstated`) |
| D. `For we are`→`For {name} are` | 1 × adjustment | **Passes.** Produces "For Sample Name are his workmanship… that we should walk in them": a subject–verb agreement error **and** a person inconsistency, both undetected. |

**Gaps this exposes** (validator lines 168–190, risk assessor):
1. The validator does not detect a **pronoun that carries person or number** ("we", "us", "our", "ye", "you", "I", "me") being replaced by a name.
2. It does not check **subject–verb agreement** after a replacement.
3. It does not check **consistency with pronouns left elsewhere in the verse** ("that we should walk").
4. Missing passage context is only a **warning** (line 231), so a rule with no context can pass automated validation at medium risk.
5. "Passed" is still not "published". `approvedOnly` requires a recorded human approval, so none of these renderings could appear in normal mode. The gaps matter for review quality and queue triage, not for current publication.

The Eph 2:10 rendering should become a permanent regression case. Cases A, C and D must all be rejected or flagged for mandatory review (see `MWB_INTELLIGENCE_ARCHITECTURE.md` §7). This audit approves, repairs or adds no rule.

## 6. Home and Daily Word

| Item | Evidence | Behaviour |
|---|---|---|
| **Daily Scripture** | `dailyScriptureRefs` (`lib/data/mock/mock_daily.dart` 5–25, **21 refs**); `dayIndex()` (line 80) = `(year*7 + dayOfYear) mod n`; `dailyScriptureProvider` (`bible_providers.dart` 47–51) | One verse per day, cycling every 21 days; text from the active source translation |
| **Daily Promise** | `dailyPromises` (10, `mock_daily.dart` 39–77); `_DailyPromiseCard` (`home_screen.dart` 180) | One verse plus a first-person declaration; cycles every 10 days |
| **Yesterday / tomorrow** | — | Not implemented |
| **Adaptive relevance** | — | **Not implemented.** Signals exist (recent searches, history, saves, interests) but nothing feeds daily selection. |
| **Leap day / candidate corpus / categories** | — | Not implemented |
| **Reflection, prayer, related verses** | — | Not implemented |
| **MWB in daily cards** | `textVersionProvider` | Source text only, even in an MWB edition (known limitation) |
| **Onboarding copy** | `onboarding_steps.dart` 152 | Says *"We'll shape your daily Scripture and recommendations around them."* Recommendations are shaped by interests (`recommendedProvider`), but **daily Scripture is not**. The copy over-promises. |

## 7. Discover, topics and content

| Item | Evidence | Status |
|---|---|---|
| **Topics** | `mock_topics.dart`: **19** topics with summary, key Scriptures and related topics; `topic_screen.dart` | Mock curated data, works locally |
| **Content** | `mock_content.dart`: **36** items (15 audio, 12 video, 7 articles, 2 Scripture), described in the file as "Illustrative sample content… placeholder copy" (lines 122–123) | Mock |
| **Creators** | `mock_creators.dart`: **7** "fictional sample creators" (lines 3–4) | Mock |
| **Audio** | `just_audio`; every item plays `assets/audio/sample_reflection_tone.wav` (`mock_content.dart` 6–8, `isSampleStandIn: true`); the panel discloses this (`audio_player_panel.dart` 133–138) | Real player, sample media |
| **Video** | `SimulatedVideoPlaybackController` (`video_playback_controller.dart`); shows "PREVIEW · NO VIDEO MEDIA" (`video_player_view.dart` 56) | Simulated |
| **Remote content** | `RemoteContentRepository` (`content_repository.dart` 182–223) | Every call throws `FeatureUnavailableFailure` |
| **Upload** | `upload_screen.dart`, `upload_validation.dart` | Local drafts only |
| **Promises, blessings, prayers, declarations, life situations, journeys, relationships, speaker context** | — | **Not implemented** |

## 8. Library, profile, settings and account

| Item | Evidence | Status |
|---|---|---|
| **Library** | Bookmarks, highlights, notes, saved Scripture, saved content, collections, history, recently viewed, drafts, reports (`library_controllers.dart`) | Implemented locally |
| **Profile** | `UserProfile` with `NamePreference` full/first/preferred/none (`user_profile.dart` 17–27); onboarding (personal, interests, reading steps) | Implemented locally |
| **Notifications** | `DeferredNotificationService` (`notification_service.dart`): `canDeliver = false`; preferences saved, nothing delivered | Preference only |
| **Auth** | `DeviceOnlyAuthRepository` is guest only; `RemoteAuthRepository` is a stub (`auth_repository.dart` 32–80) | Not implemented |
| **Insights / analytics** | — | Not implemented |

## 9. Sharing

| Item | Evidence | Status |
|---|---|---|
| **Scripture copy** | `scriptureShareText()` / `copyPassage` (`scripture_card.dart` 19–28); reader selection copy (`reader_screen.dart` 749–750) | **Clipboard text only**, with reference and version attribution; personalised renderings are labelled |
| **Content share** | `shareContent()` (`content_actions.dart` 22–24): "Copy to share" | Clipboard text only |
| **Image card / Poster Studio** | — | **Not implemented.** No image is rendered, exported, saved or shared natively. |

## 10. Offline behaviour (from code)

| Capability | Local? | Evidence |
|---|---|---|
| Bible text (KJV and WEB) | Yes | Bundled assets |
| Bible search and reference navigation | Yes | `AssetBibleRepository.search`, `tryParse` |
| Topics, content metadata, creators | Yes (mock) | `MockContentRepository` |
| Library data, profile, preferences | Yes | SharedPreferences |
| Daily Scripture and Daily Promise | Yes | `mock_daily.dart` |
| MWB rendering and review queue | Yes | Bundled rulesets and context |
| Fonts | Yes | Bundled |
| Audio | Sample tone only | Asset |
| Video | No media at all | Simulated |
| Remote content, accounts | Not implemented | Stubs |
| Notifications | Not delivered | Deferred service |

I did **not** test airplane mode on a device. These conclusions come from the code.

## 11. Test inventory

| File | Tests (static count) | Focus |
|---|---|---|
| `infrastructure_test.dart` | 11 | Config, storage, network |
| `library_test.dart` | 13 | Bookmarks, notes, highlights, history |
| `navigation_test.dart` | 6 | Shell and routes |
| `onboarding_test.dart` | 8 | Onboarding flow |
| `repository_test.dart` | 13 | Bible and content repositories |
| `search_test.dart` | 12 | Search |
| `theme_test.dart` | 6 | Themes |
| `mwb/renderer_test.dart` | 23 | Rendering and name resolution |
| `mwb/validation_and_review_test.dart` | 20 | Validator and queues (golden docs) |
| `mwb/version_catalogue_test.dart` | 14 | Catalogue and licences |
| `mwb/web_and_editions_test.dart` | 21 | WEB, editions, reader |

The static count is 147; the runner reports **162** because some tests are generated in loops.

**No test** covers person or number substitution, subject–verb agreement, or the Eph 2:10 case.
