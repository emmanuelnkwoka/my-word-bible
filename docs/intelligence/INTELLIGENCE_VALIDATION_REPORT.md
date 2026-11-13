# Scripture Intelligence Corpus: Validation Report

Corpus version 1.0.0. Run on 11 November 2026.

## 1. Validator result on the shipped corpus

| Measure | Result |
|---|---|
| Records checked | 283 (taxonomy: 28 terms and 83 links checked separately) |
| Scripture references checked | 467, against KJV (canonical) and WEB |
| **Errors** | **0** |
| **Warnings** | **0** (no reference falls on a verse the WEB omits or numbers differently) |
| Validation time (test VM) | ~93 ms |

`test/intel/intelligence_corpus_test.dart` (*passes the validator with no errors*) enforces this on every test run.

## 2. Rule coverage by automated tests

Each rule has at least one test that breaks the shipped corpus in a specific way. The test then checks that the validator reports that exact rule against that exact record id (`test/intel/intelligence_validator_test.dart`).

| # | Rule | Tests (break → expected report) |
|---|---|---|
| 1 | References resolve | Verse beyond chapter (ISA 26:99); unknown book (XYZ 1:1); whole chapter (NUM 6); reversed range (MAT 6:33-30); WEB-omitted verse (ACT 8:37) is a **warning** only |
| 2 | Referenced ids exist | Situation → missing promise; prayer → missing situation; command → record of the wrong kind; taxonomy link → missing record; rejected seed reappearing |
| 3 | No duplicate ids | Same id twice in one file; one id shared by a blessing and a prayer |
| 4 | No orphans | Record citing no Scripture; unused taxonomy term; one-step journey |
| 5 | Prayers have ≥ 2 references | Prayer reduced to one reference |
| 6 | Declaration safety | Lower-case "him" for the reader; "Her" in the first-person text; reverent "Him/His" for God **allowed**; demo token `⟦F⟧`; `{name}` in a prayer |
| 7 | Relationships explained | Explanation shortened to "Similar." |
| 8 | Journey steps resolve | Step → missing promise; steps out of order; verse step to MAT 11:99 |
| 9 | Context integrity | Empty speaker; empty audience; divine speech with "low" personalisation risk |
| 10 | Conditions kept | Conditional context with empty condition; Ps 91:11 promise with its condition removed |
| 11 | Corporate not individualised | Zion promise recast as "general"; Isa 54:13 declaration without a grounding note; promise on a verse with no context |
| 12/14 | Scripture stays Scripture | Blessing text identical to Num 6:26; a `kjv` field added to a context (rejected by the decoder) |
| 13 | No automatic approval | Marked reviewed with no reviewer; eligibility `"approved"` (rejected by the decoder); seed provenance without a seed id |

Decoder and loading tests (`test/intel/intelligence_repository_test.dart`):
- missing file (with retry);
- invalid JSON;
- unsupported schema;
- a wrongly typed field;
- a non-canonical reference string ("Isaiah 26:3");
- a manifest count mismatch.

## 3. Test results

| Command | Result |
|---|---|
| `flutter test test/intel` | **72 passed** (corpus 18, validator 38, repository and decoder 16) |
| `flutter test` (whole suite) | **234 passed, 0 failed**: 162 existing tests unchanged + 72 new |
| `flutter analyze` | **No issues found** |

No existing test was removed, skipped or weakened. The only existing test file changed is `test/helpers/test_app.dart`, which gains an override so widget tests read the corpus from disk.

## 4. Integrity checks outside the validator

| Check | Result |
|---|---|
| Canonical Bible text unchanged | `git diff` shows no change to `assets/bible/kjv.json`. `web.json` was not modified in this stage. A test confirms the KJV text of Eph 2:10 is identical before and after loading and validating the corpus. |
| MWB rulesets unchanged | No change to `kjv-mwb.json` or `passage_context.json` (git). `web-mwb.json` and the review queues were not modified in this stage. Existing MWB tests still pass. |
| No approvals recorded | All 283 records are `pendingEditorialReview`. No reviewer names. No MWB rule status changed. |
| No verse text in the corpus | The decoder rejects unknown fields. A test scans every corpus file for `"kjv"` / `"verseText"`. |
| Offline | The repository reads only `assets/intel/*` through the asset loader (a test asserts every requested path). The corpus is bundled in the APK (verified by listing the APK). |
| Demo quotations vs bundled KJV | 101 of 117 identical. 16 differ only by a space before punctuation or "Judæa" in the bundled KJV (see the provenance report §7). |

## 5. Runtime verification

| Step | Result |
|---|---|
| `flutter build apk --debug` | Succeeded (327.7 s) |
| APK contents | All 13 `assets/intel/*.json` files present |
| Install on `emulator-5554` | Success |
| Launch | `Displayed com.xpatsoft.my_word_bible/.MainActivity` (+1 min 17 s cold start on this emulator); process running; no Flutter error in the log; home screen rendered (screenshot taken) |

**Limit of this verification:** no screen reads the corpus yet, by design for Stage C. The device run proves the corpus is bundled and the app still launches. It does **not** exercise the corpus on the device. Repository behaviour is verified by the automated tests, which read the same JSON files.
