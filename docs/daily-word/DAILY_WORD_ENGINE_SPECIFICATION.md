# Daily Spoken Word Engine V1: Specification (as implemented)

Stage D, 11 November 2026. This document describes the code as built.

## 1. What the reader gets

- **Home:** a prominent Daily Word card (`DailyWordHomeCard`, key `home.dailyWord`). It shows the theme, the heading, the Scripture text, the reference and translation, and whether the word came from the schedule or from activity on the device. It replaces Foundation V1's fixed 21-verse "Daily Scripture" rotation. The Daily Promise card is unchanged.
- **Daily Word screen** (`/daily-word?d=yyyy-mm-dd`, `DailyWordScreen`), in this order:
  1. Date, with a *Today* pill when it is today.
  2. Category and heading.
  3. **Scripture**: the passage in the active translation (with an approved MWB rendering when one exists; none are approved today), the reference and translation, and *Open chapter*.
  4. **Actions:** Save / Saved, Favourite / Favourited, Share (native share sheet), Card (Scripture card image).
  5. **Why you're seeing this** (labelled *Selection note*): the stored summary and reasons, plus "Suggested for reflection … not a claim about what God is saying to you personally."
  6. **About this passage** (labelled *Editorial context — not Scripture text*): voice, speaker, author, first audience, literary form and classification, the condition in the text, and the context note. Shown only when a Stage C context exists. Empty historical and literary context fields are omitted.
  7. **Read it in context:** up to three verses either side, with the passage emphasised.
  8. **Related in Scripture intelligence:** promises (with original audience, conditions and reception guidance), identity themes, commands and worship themes that cite the passage. Each opens the reader.
  9. **Related Scripture:** Stage C relationships (with type and explanation), then other passages from the same life situations (up to 8), each with its text. Each opens the reader.
  10. **Previous / next** delivered Daily Word, and the schedule version note.
- **History screen** (`/daily-word/history`): all delivered words newest first, filterable to Favourites.
- **Library:** *Favourite Daily Words* (Scripture tab) and *Daily Word history* (History tab). Saved Daily Words appear in *Saved Scripture* (shared with the reader).
- **Profile → Daily Word & privacy** (`/profile/daily-word`):
  - a status notice saying whether local personalisation is on;
  - an on/off switch for personalisation;
  - the count of recorded searches;
  - **Clear Daily Word signals**;
  - a link to history.

## 2. Components

| Responsibility | Code |
|---|---|
| Models: `DailyWordCandidate`, `ScheduleDay`, `DailyWordCatalogue` (schedule plus pool), `DailyWordHistoryEntry`, `DailyWordSettings`, `RelevanceSignal`, `SelectionReason` | `lib/data/models/daily_word.dart` |
| `DailyWordRepository` / `AssetDailyWordRepository` (bundled schedule, loaded once); `LocalDailyWordPersistence` (history and settings) | `lib/data/repositories/daily_word_repository.dart` |
| `AdaptiveRelevanceScorer`, `CandidateFacts`, `RelevanceProfile` | `lib/features/daily_word/domain/adaptive_relevance_scorer.dart` |
| `DailyWordEngine`, `buildRelevanceProfile` | `lib/features/daily_word/domain/daily_word_engine.dart` |
| Providers: catalogue, engine, settings, history, `dailyWordForDateProvider`, `dailyWordDetailProvider` | `lib/features/daily_word/application/daily_word_providers.dart` |
| Search signals (`relevanceSignalsProvider`) | `lib/features/daily_word/application/relevance_signals.dart` |
| Screens | `lib/features/daily_word/presentation/*` |
| Scripture card renderer (reusable), card sheet, native share | `lib/features/share/*` |
| Schedule builder | `tool/build_daily_schedule.js` |
| Data | `assets/daily/candidates.json`, `assets/daily/schedule.json` |

The engine reads Stage C through `intelligenceCorpusProvider` (`AssetIntelligenceRepository`). Scripture text always comes from `BibleRepository`; no verse text is stored in the Daily Word data.

## 3. Delivery rules

1. `dailyWordForDateProvider(dateKey)` returns the stored entry if that date has one.
2. Otherwise the engine chooses, and the entry is written to history before it is returned. `deliver()` never replaces an existing date.
3. History is keyed by date, so there is at most one entry per date. Opening a word again only sets `openedAt` (once).
4. Each entry stores:
   - date, candidate id, reference;
   - translation at delivery;
   - category and heading;
   - summary and reasons;
   - `adaptive`;
   - **schedule version**;
   - scheduled candidate id;
   - delivery time;
   - favourite flag;
   - opened time.
5. Signals recorded today are read only when a later date is first delivered.
6. A future schedule version cannot change past entries: they are read back as stored.
7. Today's date comes from the app clock. Pull-to-refresh on Home re-reads the date (`todayKeyProvider`).

## 4. Privacy

- Everything is stored in SharedPreferences on the device: `mwb.v1.daily_word_history`, `…_settings`, `…_signals`.
- No network call, analytics or tracking SDK was added.
- Turning personalisation off makes the engine use the annual schedule exactly.
- *Clear Daily Word signals*:
  - deletes recorded searches;
  - stores a `signalsClearedAt` time, so earlier reading, saves, highlights and notes stop counting;
  - does **not** delete the Library or the chosen interests.

## 5. Sharing

- **Text:** `SharePayload.scripture`: optional heading, a blank line, “Scripture”, “— Reference (Translation)”, and "Shared from My Word Bible". Sent through `share_plus` 13.3.1 (`SharePlus.instance.share`), which opens the Android share sheet.
- **Image:** `ScriptureCardRenderer` draws a 1080 × 1350 portrait PNG offscreen. It uses:
  - colours from the active theme;
  - bundled Lora, Cormorant and Inter fonts;
  - a font-size ladder from 60 to 26 so long passages fit;
  - overline, heading, the Scripture in quotation marks, the reference and translation, the My Word Bible brand, and a licence line.

  `share_plus` writes the PNG to a temporary file and opens the share sheet. The card sheet previews the image first.
