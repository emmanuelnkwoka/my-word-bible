# F1 Implementation Report: Personal Word Rhythm & Private Reflection Journal

Date: 14 November 2026 · Base: `main` at `06895be` · Flutter 3.47.0 / Dart 3.13.0 · Device: Xiaomi M2101K7BG (Android 11)

**Scope:** F1 only, as approved. There is no backend, account, social feature, synchronisation or reminder delivery.

**Unchanged:** the five tabs, the KJV and WEB data, the r3 engine and Phase I sharing.

**Not committed or pushed**, pending review.

## 1. Modules created

| Module | What it does |
|---|---|
| **Encrypted personal store** | One SQLCipher database for all F1 data. The key is generated on the device and held in secure storage. Migrations are versioned. The status is reported honestly: ready, key lost, unavailable, or written by a newer version |
| **Personal Word Rhythm** | Reading sessions the user starts, and an explicit **Complete reading**. Records are append-only activity records with stable ids. Also: a weekly summary (Monday–Sunday), a month calendar with a day detail, and a history of completed readings |
| **Private Reflection Journal** | Create from the Reader (verse selection), the Daily Word, Saved Scripture or on its own. Edit and delete. Link, change or remove a canonical reference. Search, with filters (On Scripture, origin, book). Export as `.txt` or `.json` |
| **Privacy controls** | Profile → Journal privacy covers status, how the data is protected, export, delete all reflections, and delete reading activity |

**Rules enforced in code:**

- Opening or scrolling a chapter records nothing.
- A chapter can be completed once per local day.
- There are no streaks, scores, rankings or missed-day wording.
- Reflections are never set in Scripture style.
- Reflections never store verse text.
- Nothing is sent to a network.

## 2. Files

**New (lib):**

- `lib/data/local/personal_database.dart`: SQLCipher database, migrations, key store, opener.
- `lib/data/models/personal_rhythm.dart`: models, UUID v4, week helpers, reference route codec.
- `lib/data/repositories/personal_repositories.dart`: `RhythmRepository`, `JournalRepository` and their SQL implementations.
- `lib/features/fellowship/application/personal_providers.dart`: providers and `PersonalActions`.
- `lib/features/fellowship/application/journal_export.dart`: exporter and the export share service.
- `lib/features/fellowship/presentation/`:
  - `personal_widgets.dart`: Home card, week strip, store notice, reflection label;
  - `chapter_completion_panel.dart`;
  - `rhythm_screen.dart`;
  - `journal_screen.dart`;
  - `reflection_editor_screen.dart`;
  - `journal_privacy_screen.dart`;
  - `personal_library_cards.dart`.

**New (other):**

- `android/app/src/main/res/xml/mwb_backup_rules.xml` and `mwb_data_extraction_rules.xml`.
- `test/fellowship/` (5 files).
- `docs/fellowship/F1_IMPLEMENTATION_REPORT.md` and `F1B_REMINDERS_NOTE.md`.

**Modified (additive only):**

| File | Change |
|---|---|
| `pubspec.yaml` / `pubspec.lock` | `sqlite3: 3.8.0` (pinned), `path_provider` (already transitive, now direct), `hooks.user_defines.sqlite3.source: sqlcipher`. The lock also moved `meta` 1.18.3 → 1.19.0 and `record_use` 0.6.0 → 1.1.1, and added `native_toolchain_c` (build-hook tooling) |
| `AndroidManifest.xml` | `fullBackupContent` and `dataExtractionRules` (exclusions only; Auto Backup stays on for everything else) |
| `lib/app/routes.dart`, `lib/app/app_router.dart` | Root routes `/rhythm`, `/journal`, `/journal/new`, `/journal/e/:id`; profile route `/profile/journal` |
| `lib/core/constants/storage_keys.dart` | `securePersonalDbKey` (a secure-storage key name) |
| `reader_screen.dart` | Completion panel after the chapter footer; "Start reading session" in the ⋯ menu; **Reflect** in the selection bar; `_openedAt` (used only as the start time of a reading the user completes) |
| `daily_word_screen.dart` | **Reflect** action chip |
| `home_screen.dart` | `RhythmHomeCard` below Today's promise |
| `library_screen.dart`, `library_sections.dart` | Reflections section (Scripture tab), Completed readings (History tab), **Reflect** under each saved verse |
| `profile_screen.dart` | "Word rhythm & reflections" group: Word rhythm, Reflections, Journal privacy |
| `settings_screens.dart` | Privacy & data lists the encrypted reflections store |
| `test/helpers/test_app.dart` | In-memory personal store override; optional `personalStore` parameter |

## 3. Existing data structures (recorded before implementation)

All existing user data is in SharedPreferences under versioned keys (`lib/core/constants/storage_keys.dart`), as JSON:

| Data | Key(s) |
|---|---|
| Onboarding, profile, interests | `mwb.v1.onboarding_complete`, `mwb.v1.user_profile` (first/last/preferred name, gender, name preference), `mwb.v1.interests` |
| Preferences | `mwb.v1.reading_preferences` (version, text size, goal, surface, verse numbers), `mwb.v1.daily_experience`, `mwb.v1.notification_preferences`, `mwb.v1.theme_id`, `mwb.v1.theme_mode` |
| Library | `mwb.v1.bookmarks`, `mwb.v1.highlights`, `mwb.v1.notes`, `mwb.v1.saved_scripture`, `mwb.v1.saved_content`, `mwb.v1.collections`, `mwb.v1.recently_viewed`, `mwb.v1.recent_searches`, `mwb.v1.upload_drafts`, `mwb.v1.content_reports` |
| Reading history | `mwb.v1.reading_history`: chapter opens, deduplicated, at most 50 |
| Daily Word | `mwb.v1.daily_word_history`, `_settings`, `_signals` |
| Personalisation | `mwb.v1.mwb_reviewer_mode`. The r3 layers are bundled assets, not user data |
| Sharing (Phase I) | `mwb.v1.social_*`, `mwb.v1.pending_share_link`, `mwb.v1.card_studio_last` |
| Secure storage | `mwb.secure.access_token`, `mwb.secure.refresh_token` |

**F1 reads none of these, except the existing reading history and today's Daily Word, which it reads only to suggest a chapter. It writes to none of them.** The old reading history is **not** imported as completed readings, because those entries record chapter opens and the founder ruled that opening is not completion.

## 4. Database design

File: `<app support dir>/mwb_personal/personal.db`. On Android this is the app's private `files` directory.

**Schema v1** (`PRAGMA user_version = 1`):

```sql
reading_sessions(id TEXT PK, book_id, chapter CHECK > 0, version_id, origin,
                 status CHECK IN ('active','completed','ended'), started_at, finished_at)
activity_records(id TEXT PK, kind, occurred_at, local_date, tz_offset_min,
                 book_id, chapter, verse_start, verse_end, version_id, session_id, journal_id,
                 dedupe_key TEXT NOT NULL UNIQUE)         -- index on local_date
journal_entries(id TEXT PK, created_at, updated_at, title, body,
                book_id, chapter, verse_start, verse_end, version_id, source, daily_word_date,
                CHECK ((book_id IS NULL) = (chapter IS NULL)))   -- index on created_at
```

| Rule | How it is enforced |
|---|---|
| Stable ids | UUID v4 from `Random.secure`, never reused, kept across edits. Ready to be idempotency keys for a later sync |
| Timestamps | UTC ISO-8601, plus the device `local_date` and timezone offset at the time |
| One completion per chapter per local day | `dedupe_key = readingCompleted:<BOOK>.<ch>:<yyyy-mm-dd>` is `UNIQUE` (enforced by the database, not only the UI) |
| Canonical references only | Checked against the canon (book, chapter range, verse order) and, for reflections, against the installed translation's verses. Personalised editions are stored as their source (KJV-MWB → KJV). **No verse text is stored** |
| Deleting a reflection | Removes its activity record in the same transaction |
| Transactions | Multi-row changes use `BEGIN IMMEDIATE … COMMIT`, with rollback on error |

## 5. Encryption implementation

### 5.1 SQLCipher evaluation

- **Library:** `package:sqlite3` 3.x bundles prebuilt, sha256-verified **SQLCipher 4.x community edition** binaries, selected with `hooks.user_defines.sqlite3.source: sqlcipher`.
- **Compatibility:** the app had no database before (only `KeyValueStore` over SharedPreferences). SQLCipher therefore sits beside the existing storage, behind new repository interfaces, without replacing anything.
- **Verified:**
  - on the Windows test host: `cipher_version` reports `4.19.0 community`;
  - on the Android device: see §8.
- **Result: suitable, so it was adopted.** No other package was selected.

### 5.2 How it works

1. On first use, `PersonalStoreOpener`:
   - generates 32 bytes with `Random.secure()`;
   - writes them to `flutter_secure_storage` (Android Keystore-backed) under `mwb.secure.personal_db_key`;
   - **reads the key back** and proceeds only if it persisted.
2. The database opens with `PRAGMA key = "x'<64 hex>'"` (a raw 256-bit key; SQLCipher's AES-256 page encryption with HMAC).
3. **It refuses to run without encryption:** if `PRAGMA cipher_version` is empty, the store reports `encryptionUnavailable` rather than writing plain text.
4. `PRAGMA secure_delete = ON`. Deleted rows are zeroed, and "Delete all" also runs `VACUUM`.
5. `PRAGMA cipher_log_level = NONE`. SQLCipher would otherwise log decryption failures; it never logs content.

**Key rules:**

- The key never goes to SharedPreferences, logs, the database, exports or any server. A test checks the imports and every SharedPreferences value.
- A new key is generated **only when no database file exists**.
- If secure storage cannot be read, nothing is created, replaced or deleted (`keyStoreUnavailable`).

### 5.3 Backup and deletion behaviour

| Situation | Behaviour |
|---|---|
| Android Auto Backup / device transfer | `mwb_personal/` and the three `flutter_secure_storage` preference files (`FlutterSecureStorage.xml`, `FlutterSecureKeyStorage.xml`, `FlutterSecureStorageConfiguration:FlutterSecureStorage.xml`) are **excluded**: the Keystore key cannot be backed up, so a restored copy would be unreadable. Other app data keeps its existing backup behaviour |
| Keeping a copy | **Export** (`.txt` or `.json`) through the system share sheet. The user is warned first that the file is not encrypted |
| Delete one reflection | Row and its activity record are removed (secure delete) |
| Delete all reflections / reading activity | Separate controls in Profile → Journal privacy. Each deletes in a transaction and then runs `VACUUM` |
| "Clear library" (existing) | Unchanged. It does not touch reflections |
| Uninstall / clear app data | The database and the key are both removed |

### 5.4 If the key is lost

This can happen when app data is restored to a new phone or secure storage is reset.

- The file still exists, but the key is missing or wrong. The store reports `keyLost` or `wrongKey`.
- The encrypted file is **left untouched**.
- The journal and the Rhythm screen explain that **no one, including My Word Bible, can recover these reflections**. They offer **Start a new private journal**, which deletes the unreadable file and its key only after confirmation.
- The rest of the app (Bible, Library, Daily Word, sharing) keeps working, and the Rhythm card is hidden.

## 6. Migration strategy

- **Existing data:** nothing is migrated or rewritten. The F1 store is new and separate; the test "existing user data is untouched by F1" seeds history, saved verses, notes, theme and reviewer settings, runs F1 actions, and compares every SharedPreferences value byte for byte.
- **Schema evolution:** `personalMigrations` is append-only. Each step runs in its own transaction and sets `user_version`.
- **Rollback:**
  - a failing step is rolled back completely, and the version stays unchanged (tested);
  - a database written by a **newer** app version is not opened or modified (`newerSchema`, tested), so a downgrade cannot corrupt it;
  - removing F1 (uninstalling the feature, or deleting the store) leaves all existing data intact, because nothing outside the store depends on it.

## 7. Tests and results

### 7.1 New tests

**65 new tests** in `test/fellowship/`:

| File | Covers |
|---|---|
| `personal_store_test.dart` | Real SQLCipher files (header, no plaintext even in the schema, wrong key, no key, secure delete, key length) · key generation, reuse, randomness, secure-storage failure, lost key (file untouched), wrong key, start again · migration (fresh, reopen, future v2 upgrade keeps data, failing step rolled back, newer schema untouched) · offline persistence across close and reopen |
| `personal_repositories_test.dart` | Completion record (UUID, UTC, local date, offset, canonical version) · sessions (start, complete, end, replace) · Undo · invalid references · duplicate prevention (same day, next day, database-level unique key) · weekly summary and calendar · journal create, edit, delete with stable ids · reflection activity · validation · delete all · search (case, title and body) and filters (origin, linked, book, combined) · reference overlap · reference integrity (no verse text stored; KJV-MWB → KJV; non-existent verses refused) · route codec |
| `journal_export_test.dart` | Text and JSON exports: complete, labelled "not Scripture / not encrypted", no verse text, lossless JSON, file names and types |
| `f1_flow_test.dart` | Full app: opening records nothing; Complete reading once; Undo · KJV-MWB records KJV · session from Rhythm completed in the reader · reader-menu session · Home summary and Rhythm history (no streak or score wording) · Reflect from the reader selection, Daily Word and Saved Scripture · independent create, link, edit, delete · journal search and filters · export (warning, file, no other share) · Profile privacy deletes · Profile entries and five tabs · store unavailable (key lost / secure storage) with the rest of the app working · existing data untouched · privacy isolation (no share, notification or social records; no reflection text in SharedPreferences; no network, social or analytics imports) · 7 themes × light/dark for all F1 screens |
| `f1_test_support.dart` | Helpers |

### 7.2 Regression fix

The first full run had one failure:

- **Test:** `r3_presentation_test` "Discover topic, Library and Search show the same layers".
- **Cause:** my first version added a Reflect **icon** to each saved-verse row, which narrowed the r3 reception label until it overflowed.
- **Fix:** the saved-verse row was restored exactly as it was. Reflect is now a text action on its own line below the row.

### 7.3 Results

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** (final run, 97.6 s) |
| `flutter test` (complete suite) | **460 passed, 0 failed** (395 existing + 65 new; about 2 min 44 s). Earlier run before the regression fix: 394 of 395 existing passed (one failure, fixed — §7.2) |

## 8. Android device verification

**Phone:** Xiaomi M2101K7BG, Android 11.

**Install:** `adb install -r` over the previous build, keeping existing app data. The phone was unlocked by its owner for the check.

| Check | Result |
|---|---|
| Upgrade keeps existing data | ✔ The name, Daily Word with personal reception, Recently read, saved verses with r3 receptions, highlights, and Shared Scriptures (1 received · 1 sent) were all present after the upgrade |
| Encrypted store created | ✔ `files/mwb_personal/personal.db`, mode `-rw-------`. The first 16 bytes are random (no `SQLite format 3` header) |
| Home | ✔ "Your Word rhythm · Private" card below Today's promise; empty week strip with today outlined |
| Opening John 3 (KJV-MWB) records nothing | ✔ The panel "Finished John 3? · Complete reading" appears at the chapter end |
| Complete reading | ✔ It changes to "Reading completed today · 11:26 · Undo", with a "Reading completed · Reflect" snackbar |
| Reader selection → Reflect | ✔ The selection bar fits 7 actions on the phone. The editor shows **John 3:36 (KJV)** in canonical text, labelled SCRIPTURE, separate from YOUR REFLECTION |
| Save reflection | ✔ "Reflection saved privately" |
| Reflection text is not readable on disk | ✔ A test marker word was searched for in `personal.db`, `FlutterSharedPreferences.xml`, `FlutterSecureStorage.xml` and `FlutterSecureKeyStorage.xml`: 0 matches in each. The key entry exists only in `FlutterSecureStorage.xml`, never in plain prefs |
| Library | ✔ "Reflect" under each saved verse, with the r3 reception rows unchanged. A Reflections section shows "1 · private, encrypted on this device" and the entry |
| Daily Word → Reflect | ✔ The editor is linked to **Isaiah 41:13 (KJV)** |
| Profile | ✔ "Word rhythm & reflections" group (Word rhythm, Reflections, Journal privacy). Still five tabs |
| Word rhythm screen | ✔ "1 reading completed · 1 reflection". Calendar dot on 14 Nov. Day detail: "Reflected on John 3:36 · 11:27", "Completed John 3 · 11:26". History: "John 3 · 14 November 2026 · 11:26 · KJV". No streak or score wording |
| Offline persistence across restart | ✔ After force-stopping and relaunching, Journal privacy shows "Encrypted on this device · 1 reflection · 1 completed reading" (the real SQLCipher store, reported as encrypted) |
| Delete controls | ✔ "Delete all reflections" and "Delete reading activity", each confirmed, leave 0 · 0 |

**Clean-up:** the test reflection and test reading were deleted on the phone with these controls. Opening John 3 also moved it to the top of the existing Recently read list; that is existing behaviour, and it was already in the list.

**Fixes made after the device check:**

1. The reader's "Reading completed" snackbar stayed visible over the editor. It is now dismissed when Reflect opens the editor.
2. `flutter_secure_storage` also keeps `FlutterSecureKeyStorage.xml` and a configuration file. These are now excluded from backup and device transfer too.

**Not checked on the device:**

- An actual cloud-backup restore (that needs a second phone or a factory reset). The key-lost path is covered by tests.
- Export through the share sheet (covered by tests, so as not to send anything from the user's phone).

**APK size:** 261 MB (previously 210 MB). It includes `libsqlcipher.so` for three ABIs (4–6 MB each). The rest of the difference was not investigated; a release build with `--split-per-abi` will be much smaller.

## 9. Known limitations

1. **Reminders (F1b) are not implemented.** See `F1B_REMINDERS_NOTE.md`.
2. **Reflections cannot be backed up automatically,** by design: the key cannot leave the device. Export is the user's copy. Losing the key means losing the reflections, and the app says so.
3. **Export is unencrypted.** The user is warned, and chooses the destination.
4. **Search** is a case-insensitive substring match. It is ASCII-case-insensitive only, because SQLite's `lower()` does not fold non-Latin case. There is no full-text ranking. This is adequate for personal volumes.
5. **"Reading completed" is the user's own statement.** The app does not and cannot verify reading. Only the user ever sees it.
6. **Selecting verses that are not next to each other** (for example 3 and 7) and choosing Reflect links the span 3–7. This is the same behaviour as the existing Note action.
7. **iOS was not built or tested** (Windows host). SQLCipher on iOS uses the same `package:sqlite3` bundle, but this is unverified.
8. **Debug APK size** grows by the SQLCipher native library (see §8).
9. **The old reading history** (chapter opens) is shown where it always was. It is not counted as completed readings.

## 10. Building and installing the APK

Requirements: Flutter 3.47+, Android SDK, and internet on the **first** build (the build hook downloads the SQLCipher binaries and verifies their sha256).

```sh
cd C:\xpatsoft\my-word-bible
flutter pub get
flutter build apk --debug                 # build/app/outputs/flutter-apk/app-debug.apk
adb devices                               # phone listed as "device" (USB debugging on)
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`-r` keeps the existing app data. Existing users keep their library, preferences and history; the encrypted store is created on first use.

A release build still needs a release signing key: the release build type is debug-signed today (audit, R-05).
