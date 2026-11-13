# MWB Feature Gap Matrix

Audit date: 11 November 2026. The matrix compares four sources: **Requirement** (recovered historical context plus later refinements), the **HTML demo**, the **Flutter** app, and the resulting **status**.

## Statuses

- **RV**: implemented and runtime-verified. Seen running on `emulator-5554` on 11 Nov 2026, with screenshots.
- **IMP**: implemented but not runtime-verified. Code and tests exist, and `flutter test` passes, but it was not observed on a device in this stage.
- **PART**: partially implemented.
- **MOCK**: demonstration or mock only.
- **NONE**: not implemented.
- **INCOMPAT**: architecturally incompatible with the requirement as built.
- **UNK**: unknown.

A model, class, placeholder or disabled button does not count as a working feature.

Demo verdicts are summarised from `MWB_ORIGINAL_DEMO_AUDIT.md`; Flutter evidence is in `FLUTTER_IMPLEMENTATION_AUDIT.md`.

## A. Scripture foundation

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Canonical spine separate from translations | Structure only, 11 chapters of text | `BibleCanon`, per-translation assets | IMP |
| Complete KJV offline | Partial (11 chapters) | `kjv.json` 31,102 verses | RV (reader) |
| Complete WEB offline | No | `web.json` | RV (WEB-MWB reader, WEB search, switch) |
| NKJV / NIV / NLT | "Future" chips | Catalogue entries disabled (no licence) | NONE (correctly blocked) |
| Translation licensing metadata | Static labels | `VersionLicence`, `PermissionState` | IMP |
| Text history / versioning of translations | No | No | NONE |
| Historical 93,303-record corpus / fingerprint | No | No | NONE (artefacts not in workspace) |

## B. Scripture intelligence

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Speaker / author / audience / classification profiles | Functional (117) | `passage_context.json`: 9 contexts, used for risk and review only | PART (internal only, not shown to readers) |
| "God speaks / Jesus speaks / human voice" labelling | Functional | None | NONE |
| Promise library | Functional (30) | None | NONE |
| Blessings | Functional (12) | None | NONE |
| Commands, identity themes, worship themes | Not shown | None | NONE |
| Life situations | Functional (35) | 19 mock topics with key Scriptures (`mock_topics.dart`) | PART (topics are a lighter, different concept) |
| Guided discovery journeys | Functional (11) | None | NONE |
| Scripture-to-Scripture relationships | Functional (21) | None | NONE |
| Taxonomy | Keywords only | Topic `relatedTopicIds` | PART |

## C. Prayer and declaration engine

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Scripture-grounded prayers | Functional (15) | None | NONE |
| Declarations linked to Scripture | Functional (10, gendered defect) | `dailyPromises`: 10 first-person declarations (`mock_daily.dart` 39–77) | PART |
| Situation → Scripture → prayer → declaration chain | Functional | None | NONE |
| "Pray" destination | Bottom tab | None | NONE |

## D. Personalisation (DSPE / MWB)

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Selectable MWB editions per translation | Toggle only | Catalogue, picker, reader | RV |
| Switch original ↔ MWB at same reference | Per-sheet toggle | `reader-switch-edition` | RV |
| Controlled edit operations with exact recovery | No (string replace) | `EditEngine`, 5 operations | IMP |
| Automated validation (vocabulary, gender, punctuation, recovery, approval integrity) | Named only | `PersonalisationValidator` | IMP |
| Person / number / agreement checks (Eph 2:10 class) | No | **Missing.** Probe cases C and D pass (`FLUTTER_IMPLEMENTATION_AUDIT.md` §5). | PART |
| Context-driven risk | No | `RiskAssessor` | IMP |
| Approved-only publication; fail safe to source | Partial (curation = publication) | `PublicationPolicy.approvedOnly` | IMP |
| Reviewer preview labelled "PROPOSED — NOT APPROVED" | No | `mwb_review_widgets.dart` | RV |
| Review queues (KJV-MWB, WEB-MWB) | No | `docs/mwb/*-review-queue.md` | IMP |
| Approved personalised Scripture visible to readers | Yes (unsupervised) | 0 approved rules | NONE (by design until review) |
| Rule coverage beyond Proverbs "my son" | 78 verses (defective) | 21 / 20 rules | PART |
| Name preference: full / first / preferred / none | Fixed demo user | `NamePreference`, `PersonalNameResolver` | IMP |
| Gender never changes Scripture | **Violated** (D5) | No gender input to rules; gendered-term check | IMP |
| Personal Reception panel (context framing for the reader) | Functional | None | NONE |
| Recording an approval in the app | No | None (by design) | NONE |

## E. Daily Spoken Word

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Deterministic daily selection | Functional (48-day cycle) | `dayIndex()` over 21 refs; 10 promises | PART |
| Candidate corpus separate from schedule, with categories | Functional | Plain list of references | NONE |
| 365-day non-repeating schedule; category diversity | Miniature | No | NONE |
| Leap-day policy (Rev 21:5) | Functional | No | NONE |
| Yesterday / Today / Tomorrow calendar | Functional | No | NONE |
| Adaptive relevance (scoring, freshness, diversity, fallback) | Algorithm functional; **signals simulated** | No | NONE |
| Real user signals captured locally (searches, reading, saves, interests) | Not captured | Captured (recent searches, history, saves, interests) but unused for Daily Word | PART |
| Reflect / Apply / linked prayer | Functional | No | NONE |
| Daily Word rendered in the active MWB edition | Yes | Source text only | NONE |
| Daily reminder notification | No | `DeferredNotificationService.canDeliver = false` | MOCK |

## F. Search

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Results while typing | 110 ms debounce | 300 ms debounce (`search_screen.dart` 63) | IMP |
| Whole installed Bible searchable | No (curated verses only) | Yes, KJV and WEB | RV (WEB) |
| Reference navigation ("John 3:16", "Psalm 23") | Partial (labels) | `ScriptureReference.tryParse` | IMP |
| Book-only queries ("Romans") | Book entries | Not parsed as a reference | NONE |
| Keyword AND-match | Yes (scored) | Substring AND (`bible_repository.dart` 117–139) | IMP |
| Exact-phrase search and ranking | No | No | NONE |
| Relevance ranking | Weighted fuzzy score | **None.** Canonical order, first N. | NONE |
| Spelling / punctuation tolerance | Subsequence fuzzy | No | NONE |
| Surrounding context in results | No | Verse only | NONE |
| Concept search ("fear" → promises, prayers, situations) | Functional (curated) | Topic → mock content only | PART |
| Search intelligence objects (promises, prayers, declarations, blessings, Daily Word) | Functional | Not present | NONE |
| Full-text index (FTS) | No | No (linear scan of in-memory index) | NONE |
| Recent searches | No | Stored locally | IMP |

## G. Sharing and Poster Studio

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Copy text with attribution | Functional | Clipboard (`scripture_card.dart` 19–28; reader 749) | IMP |
| Rendered image card | **Functional** (PNG 2160×2700) | None | NONE |
| Text fitting / typographic ladder | Functional | None | NONE |
| Light/dark card styles | Functional (2) | None | NONE |
| Square / Portrait / Story formats | Portrait only | None | NONE |
| Native share sheet (image) | Web Share API | No `share_plus` | NONE |
| WhatsApp / WhatsApp Status | Generic share only | None | NONE |
| Save to device | Download PNG | None | NONE |
| Card types: Scripture, Daily, Promise, Blessing, Prayer, Declaration | Functional | None | NONE |
| Card types: Personal reflection, Testimony | None | None | NONE |

## H. Experience, navigation and accounts

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Five-tab shell | Home/Bible/Discover/Pray/Saved | Home/Bible/Discover/Library/Profile | RV (home); others IMP |
| Daily Word / Poster / Search / Insights destinations | Drawer | Search route only | PART |
| Seven themes, light and dark | 1 theme, light and dark | `MwbThemeId` × 7 | IMP |
| Onboarding with name, interests, reading | No | `onboarding_steps.dart` | IMP |
| Bookmarks / highlights / notes / collections | Saved list only | `library_controllers.dart` | IMP (bookmark preservation across editions is tested) |
| Local insights (most saved / shared / themes) | Functional | None | NONE |
| Accounts, email verification | No | Stubs | NONE |

## I. Media and community

| Capability | Demo | Flutter evidence | Flutter status |
|---|---|---|---|
| Audio teachings | No | Real player plus a sample tone for every item | MOCK |
| Video | No | Simulated playhead, no media | MOCK |
| Creators | No | 7 fictional creators | MOCK |
| Upload / contributions | No | Local drafts; reports stored locally | MOCK |
| Remote content API | No | `RemoteContentRepository` throws unavailable | NONE |
| Rights, moderation, takedown, rewards | No | Report model only | NONE |
| Media linked to Scripture by stable IDs | No | `ContentItem` has Scripture refs and topic IDs | PART |

## J. Offline

| Capability | Flutter status |
|---|---|
| Read installed translations | IMP (code); RV for reading while online on the emulator. **Airplane mode was not tested.** |
| Search the local corpus | IMP |
| Notes, highlights, saved items | IMP |
| Scheduled Daily Word | IMP (simple rotation) |
| Generate and export cards | NONE |
| Downloaded media | NONE (no download feature; only the bundled sample tone) |

## Architectural incompatibilities

No hard incompatibility was found. The Flutter boundaries (repositories, providers, an asset-based corpus, a pure-Dart engine) can host every missing capability. Two soft mismatches need design work rather than patches:

1. **Topics are not life situations.** The Flutter `Topic` model links to content. GODSAID life situations link to Scripture, promises, prayers and declarations. A canonical intelligence layer is needed; extending mock topics is not enough.
2. **The Bible search structure.** It is a linear in-memory substring scan with no ranking. It can stay for MVP scale, but ranking and phrase search need either an inverted index or SQLite FTS5 (see `MWB_INTELLIGENCE_ARCHITECTURE.md`).
