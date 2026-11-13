# Personalisation Proposal Catalogue: Specification (Stage D.1)

## 0. Baseline before this stage (audited 12 Nov 2026)
- **Engine (Stage B):** `MwbRule` with 5 controlled operations; `EditEngine` (anchored edits, exact recovery); `PersonalisationValidator`; `RiskAssessor`; `MwbRenderer` (`approvedOnly` / `reviewPreview`); `ReviewQueueService`; `PersonalNameResolver` (full / first / preferred / none). Statuses: proposed, automatedValidated, underReview, approved, rejected, retired.
- **Rules:** `assets/mwb/rulesets/kjv-mwb.json` (21 rules: 20 proposed, 1 rejected) and `web-mwb.json` (20 proposed). **0 approved.** Almost all were "My son" vocatives in Proverbs.
- **Passage context:** 9 human contexts (`assets/mwb/passage_context.json`) plus 117 curated Stage C contexts (`assets/intel/contexts.json`).
- **Daily Word:** personalised only when the reader had selected an MWB edition; it showed "Chosen from your activity on this device" and a "Why you're seeing this" section.
- **Sharing:** a single 1080×1350 card from the Daily Word only, via a "Scripture card" sheet saying "The Scripture on the card is exactly as written in the KJV". The reader could copy but not share.
- **Tests:** 280 passing.
- **Coverage claim:** none. No catalogue of the whole Bible existed.

## 1. Purpose
Classify **every canonical verse** of each bundled translation and make every proposed personalised rendering visible to supervisors, so they can approve, reject or correct it. Nothing is approved by this catalogue.

## 2. Translations covered
| Edition | Source | Licence | Verses |
|---|---|---|---|
| KJV-MWB | KJV | Public domain | 31,102 |
| WEB-MWB | WEB | Public domain | 31,103 (5 empty in the source) |

NKJV, NIV and NLT are **not** covered: they are not licensed for derivative works and are not bundled.

## 3. Pipeline
1. `node tool/build_personalisation_catalogue.js` writes `assets/mwb/catalogue/{kjv,web}-mwb.catalogue.json`. It is deterministic and has no network access or randomness.
2. The app loads the catalogue through `AssetPersonalisationCatalogueRepository`. `AssetMwbRulesetRepository` merges the generated proposals into each edition's ruleset. **Hand-authored rules take precedence**: a generated proposal is skipped for any verse that has a hand-authored rule.
3. `EXPORT_REVIEW_CATALOGUE=1 flutter test test/mwb/catalogue_export_test.dart` runs the app's own validator over every proposal and writes `exports/personalisation-review/review_records.json`.
4. `node tool/export_review_catalogue.js` writes the workbook, CSVs, printable HTML and PDF.
5. Reviewers return decisions. `node tool/import_review_decisions.js <csv>` appends them to `assets/mwb/reviews/<edition>.decisions.json`, which the app layers onto the matching proposals.

## 4. The seven verse classes
| Code | Class | Meaning |
|---|---|---|
| `nameInText` | Eligible for name insertion | A Mode A proposal exists |
| `nameInTitle` | Eligible for name-in-title | A Mode B proposal exists |
| `otherTransformation` | Another defined transformation | A hand rule using a tracked replacement (currently 0 open) |
| `originalOnly` | Original text only | No addressee or no personal application |
| `contextualReview` | Requires further contextual review | Potentially eligible; a human must decide (counted as "flagged") |
| `excluded` | Excluded, with reason | Personalising would distort audience, speaker or meaning |
| `pendingDecision` | Pending editorial/theological decision | A hand rule with an explicit open question for the supervisor |

Each verse also carries one of 38 **reasons** (label plus explanation), for example `narrativeDialogue`, `addressedToGod`, `firstPersonVoice`, `divineSpeechCollective`, `genderSpecificInstruction` or `existingVocative`. These are listed in the catalogue JSON and the workbook.

## 5. Classification method (transparent rules, not AI)
- **Curated context first:** where a Stage C context exists, its voice, addressee and eligibility decide. For example, `notEligible` → excluded, `god` → addressed to God, `narrative` → narrative dialogue, and divine speech to a collective → contextual review.
- **Book metadata:** 66 books with traditional authorship (recorded as such), genre and first audience.
- **Pronoun person and number** come from the **KJV** text (thou/thee = singular; ye/you = plural; we/us = first-person plural; I/me = speaker). The WEB does not distinguish singular and plural "you", so WEB verses use the KJV pronouns of the same canonical verse. This is recorded on each WEB proposal (`numberSource`).
- **Genre rules:**
  - Narrative and Gospels: words to characters are **excluded**.
  - Torah: covenant address goes to review.
  - Job dialogue: excluded (Job 42:7).
  - Song of Songs: excluded.
  - Psalms: name insertion **only** where God is named in the third person as the one acting for "thee", with no vocative to anyone else in or beside the verse (O Zion, O Israel, the king), no negative wording and no relationship terms. First-person and God-addressed verses are excluded or reviewed.
  - Proverbs: an existing "My son," vocative or the second-person singular (representative learner). Proverbs 2:16–19 and 5–7 (instruction about adultery and marriage to a young man), 30 (Agur's prayer) and 31 go to review.
  - Prophets: divine speech goes to review, never generated.
  - Epistles: letters to named individuals go to review; collective encouragement can get Mode B.
- **Judgement filter:** curse, woe or wrath wording excludes the verse.
- **Mode B filter:** a strong promise or encouragement word, **no** negative word, no rebuke, no question, no conditional ("if ye…", which goes to review), no relationship term, and no first-person speaker (except Jesus' teaching).

## 6. Proposal forms
- **Mode A — name in the Scripture.** Only `insertNameAfterExistingAddress` (after "My son," / "O my son,") or `insertDirectAddress` (", {name}" before the clause-closing punctuation that follows the first second-person word). **No word is removed, replaced or re-cased, and no pronoun changes.** If the punctuation introduces quoted speech, no proposal is made.
- **Mode B — name in the title.** The Scripture is unchanged (`edits: []`). The title template comes from a curated heading with no first-person words, formatted "{name}, heading". If no curated heading exists, the title is **null** and the proposal fails automated validation until an editor supplies one.
- **Hand-authored rules** (Stage B and the Romans 15:13 founder references) are kept as written.

## 7. Proposal record fields
Stable ID (`<edition>.gen.<BOOK>.<ch>.<v>` or the hand ID); proposal and rule version; translation and edition; book, chapter, verse; original text; proposed text (`[Name]` in exports); presentation mode; title and its source; exact operations; name placeholder; author; speaker; audience; literary form; classification and reason; rationale; grammar, meaning-preservation and pronoun/person checks; automated result and warnings; risk; confidence; uncertainty; reviewer question; provenance (generator, catalogue version `2026.11-d1`, generator rule v1); ruleset version; status; review history.

## 8. Statuses
`proposed` → `automatedValidated` (technical only) → `underReview` → `approved`, `corrected`, `rejected` or `retired`. A correction creates **rule version n+1**, with edits derived from the reviewer's wording against the untouched canonical text (`RuleCorrection`). It is publishable only once that version is itself approved. A flag or reopen returns the proposal to `underReview`. An approval is valid only with a named reviewer, a date and the current version.

## 9. What the app shows
- **Normal builds:** only approved proposals render (`PublicationPolicy.approvedOnly`).
- **Reviewer builds** (debug, or `--dart-define=MWB_REVIEW_MODE=true`) with the review preview switched on: proposals may render in Daily Word, Home and sharing. They are **always** labelled "Review preview · not yet approved", and shared images carry "Review preview — not an approved rendering".
- Canonical text is never stored in place of a rendering. Every `RenderedVerse` carries its source verse.
