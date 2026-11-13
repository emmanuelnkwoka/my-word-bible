# MWB r3 Personalisation: Implementation Report

Date: 13 November 2026 · Editorial source: `2026.11-revised-r3` (immutable, unmodified) · Device: Xiaomi M2101K7BG (Android 11)

## 1. What was implemented

The approved r3 presentation layers are integrated as one deterministic engine used by every screen that shows Scripture:

- **Lookup:** exact `(edition, verse_key)` with `verse_key = BOOK_ID.chapter.verse`. No display names, no fuzzy matching, no inference between title and reception.
- **Publication policy applied per layer:** `editorial_eligible` titles/receptions are shown; `requires_human_ratification` (all name-in-text layers) and `unresolved_withhold` are never shown. Their wording is not even shipped in the app asset.
- **Canonical Scripture is never changed:** titles appear above, receptions below, the verse itself is the installed KJV/WEB text.
- **Name resolution** from the existing profile and name preference (full, first, preferred, none). With no name, the template's leading address is removed ("Joy cometh in the morning"). A template that cannot be resolved safely is omitted.
- **No internal review language** in ordinary builds: review tools now appear only in dedicated reviewer builds (`--dart-define=MWB_REVIEW_MODE=true`), not in every debug build. Edition banner, reader footer and onboarding wording rewritten; the onboarding example no longer shows a name-in-text rendering.

## 2. Data import

`node tool/build_r3_presentation_layers.js` reads the r3 package and writes `assets/mwb/presentation/{kjv,web}-mwb.layers.json` (bundled, offline). Before writing it verifies:

| Check | Result |
|---|---|
| SHA-256 of every consumed file vs `MWB_REVISED_REVIEW_MANIFEST.json` | match |
| r3 canonical text vs app Bible assets | **62,205 / 62,205 identical** (KJV 31,102; WEB 31,103) |
| Layer ids unique and in specified form; identity fields consistent | pass |
| Reception file wording = reception layer wording (50 + 50) | pass |
| `has_personal_title/reception` flags = displayable layers, all verses | pass |
| Withheld titles = `MWB_TITLE_FAITHFULNESS_AUDIT.csv` (15) | pass |
| Non-renderable WEB verses = `MWB_WEB_EMPTY_RECORD_AUDIT.csv` (5) | pass |
| Every eligible template has exactly one leading `{name}, ` / `[Name], ` | pass |

## 3. Coverage

| | KJV-MWB | WEB-MWB |
|---|---:|---:|
| Verses | 31,102 | 31,103 |
| Layers imported | 200 | 195 |
| Personal titles shown | 33 | 30 |
| Personal receptions shown | 50 | 50 |
| Titles withheld (unverifiable) | 6 | 9 |
| Name-in-text withheld (needs human ratification) | 111 | 106 |
| Non-renderable verses (no text, no layer) | 0 | 5 |

## 4. Where it appears

| Area | Behaviour |
|---|---|
| Bible Reader (KJV-MWB / WEB-MWB) | Title above the verse, reception below, both independent; highlights, bookmarks, notes, navigation unchanged. Plain KJV/WEB shows Scripture only (edition choice respected) |
| Daily Word (Home + screen) | Title replaces the "Daily Word – MWB" heading when the verse has one; receptions under the reference |
| Home "Today's promise" | Same layers (MWB edition) |
| Discover (topics, people you follow) | Same layers in Scripture tiles |
| Library (saved verses) | Same layers; saving stores only the reference |
| Search | Verse results and the reference card show layers; search still matches canonical text only |
| Sharing | Quick-share and Card Studio cards carry the title and a labelled "Personal reception" under the reference; share/copy text adds "Personal reception: …"; Scripture on cards stays canonical. Direct in-app sends still send canonical text only |
| Onboarding | Real r3 example (Romans 8:37: title, unchanged verse, reception) |

## 5. Discrepancies between the r3 documents and the r3 data (data followed, nothing guessed)

1. **Romans 15:13 KJV has no title layer.** The specification's worked example says KJV has title + reception, but `MWB_LAYER_MAPPING_KJV.csv` contains only the reception (the KJV "abound in hope" proposal was reclassified to a reception in the decisions file). The app shows KJV: reception only; WEB: title + reception. Editorial confirmation recommended.
2. **Isaiah 41:10 KJV has no name-in-text layer** (the specification says it does and is withheld). Nothing is displayed beyond the reception either way.
3. `validation/validate_r3.py` could not be run: Python is not installed on this machine. Its checks are re-implemented in the importer and the Dart tests.
4. The decisions importer (`tool/import_review_decisions.js`) was not used: per the integration guide, decisions were loaded from the layer files.

## 6. Files

New: `tool/r3_csv.js`, `tool/build_r3_presentation_layers.js`, `assets/mwb/presentation/kjv-mwb.layers.json`, `assets/mwb/presentation/web-mwb.layers.json`, `lib/data/models/mwb_presentation_layer.dart`, `lib/data/repositories/mwb_presentation_repository.dart`, `lib/features/personalisation/domain/presentation_layer_resolver.dart`, `test/mwb/r3_test_support.dart`, `test/mwb/r3_presentation_test.dart`, this report.

Modified: `pubspec.yaml` (asset folder), `lib/features/personalisation/application/{personalisation_providers,mwb_reader_providers,scripture_presentation}.dart`, `lib/features/personalisation/presentation/{presented_scripture,mwb_review_widgets}.dart`, `lib/features/bible/presentation/reader_screen.dart`, `lib/features/bible/widgets/scripture_card.dart`, `lib/features/daily_word/presentation/daily_word_hero.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/onboarding/presentation/onboarding_steps.dart`, `lib/features/social/presentation/people_screens.dart`, `lib/features/share/{scripture_image_composer,scripture_share_sheet}.dart`, `lib/features/share/studio/card_studio_renderer.dart`, `test/helpers/test_app.dart`, `test/mwb/web_and_editions_test.dart` (reviewer tests now declare a reviewer build; the availability test asserts the stricter rule).

## 7. Verification

- `flutter analyze`: no issues.
- `flutter test`: **395 passing** (360 before; 35 new r3 tests covering all 27 requested areas with the actual r3 data, including all 62,205 canonical verses, every layer, all 15 withheld titles, all 5 empty WEB records, all four name preferences, the nine worked cases, reader/Daily Word/Discover/Library/Search/sharing integration, seven themes × light/dark, and absence of review language).
- Debug APK built (`build/app/outputs/flutter-apk/app-debug.apk`, 210 MB).
- **Device:** Romans 8:37 KJV-MWB reader showed "Emmanuel Nkwoka, more than conquerors" above the unchanged verse and the reception below (and verse 38's own reception); Search reference card for Isaiah 41:10 showed the reception beside the unchanged verse; Profile no longer shows "Theological review" or "MWB reviewer preview"; Home Daily Word (Ephesians 3:20, no layer) unchanged. The last build (copy-text tweak only) was built but not installed because the phone was in use.

## 8. Limitations

- Name-in-text personalisation stays off until a human ratification record exists (by design; none is fabricated).
- Reviewer tools still exist for reviewer builds only.
- Whole-chapter shares carry no layers (a chapter is shared as Scripture); verse and passage shares carry them.
