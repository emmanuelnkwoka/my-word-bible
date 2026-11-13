# Personalisation Validation Report (Stage D.1)

## 1. Automated checks (`PersonalisationValidator`)
Existing (Stage B): version integrity; exact source text; edit shape; `{name}` only; insertion adds only the name and punctuation; minimal adjustment changes at most 2 words; foreign vocabulary; gendered terms preserved; punctuation defects; exact recovery; approval integrity (named reviewer, current version); risk.

**Added in D.1:**
| Code | Severity | Catches |
|---|---|---|
| `pronounReplaced` | error | A replacement removes a pronoun that carries person or number (we, you, ye, thee, I, he…). |
| `residualPronoun` | error | After such a replacement, pronouns of the same person remain ("fill [Name] … that **ye** may abound"). |
| `verbAgreement` | error | A name followed by a plural or second-person verb ("[Name] **are**"). |
| `capitalisationChanged` | error | Same word, different case ("you" → "You"; "Jesus" → "jesus"). |
| `sourceWordDeleted` | warning | Source words removed and not restored. It is a warning because your 11 Nov decision allows small reviewed grammar changes; more than two changed words is still an error (`excessiveChange`). |
| `titleMissing` | error | A Mode B proposal with no title, or with the name not exactly once. |
| `titleFirstPerson` | error | A Mode B title with I/me/my (which would put a speaker's words into a title addressed to the reader). |
| `titleModeEditsScripture` | error | A Mode B proposal that changes the Scripture text. |

The validator stays separate from approval: `ReviewQueueService` refuses an approval without a named reviewer or for a failing version, and the renderer re-validates every rule each time it renders.

## 2. Regression tests for known defects (`test/mwb/personalisation_catalogue_test.dart`)
| Case | Result |
|---|---|
| **Ephesians 2:10**: the demo rendering ("For [Name] is his workmanship… that he should walk") and the subject-only variant ("For [Name] are…") | Both fail: `pronounReplaced`, `genderedTermChanged`; variant D also `residualPronoun` and `verbAgreement`. The catalogue makes no name-insertion proposal for this verse. |
| **Isaiah 43:1**: the demo "I have called [Name] by name" | Fails: `pronounReplaced`, `residualPronoun`. Classified as divine speech to Israel → contextual review, with no proposal. |
| **John 11:25**: the demo prefix that lower-cases "Jesus" | Fails: `capitalisationChanged`. Classified as narrative dialogue → excluded. |
| **Collective promises** (Romans 8:37, 15:13; Philippians 4:19; 2 Corinthians 5:17) | Never name-in-text. "[Name] is more than a conqueror" fails `pronounReplaced`. |
| **Romans 15:13 founder references** | Mode A fails (`pronounReplaced`, `residualPronoun`); Mode B fails (`titleModeEditsScripture`, `capitalisationChanged`). The compliant alternative passes. |
| **First-person Psalms** (23:1, 23:4, 139:14, 119:105) | Never name-in-text; "[Name] will praise thee" fails `pronounReplaced` and `residualPronoun`. |
| **Psalms addressed to God, the king or Zion** (5:4, 8:4, 45:2, 87:3, 137:9, 147:12–13) | Not proposed. |
| **Historical narrative** (Genesis 22:2, 1:1) | Excluded (narrative dialogue) / original only. |
| **Pronoun and verb agreement** | "[Name] are" → `verbAgreement`. |
| **Proper-name capitalisation** | "emmanuel nkwoka" → "Emmanuel Nkwoka"; "McDonald" and "de la Cruz" are kept exactly as typed. |
| **Quoted speech** | No generated insertion sits next to quoted speech. |

## 3. Whole-catalogue properties (tested)
- Every canonical verse of both translations is classified (31,102 and 31,103), matching the Bible assets chapter by chapter.
- Every generated proposal is written against the exact canonical text.
- Every Mode A proposal only inserts the name, passes validation, and rebuilds the source exactly.
- Every Mode B proposal leaves Scripture untouched and never has a first-person title.
- No generated insertion contains a gendered word.
- Nothing in the catalogue is approved or carries a review record.
- Generated proposals reach the review queue, and hand-authored rules take precedence on their verses.
- A correction creates version n+1, which is not publishable until approved. Reopening needs a reason. A flag needs a reason. Unrelated proposals are untouched.
- An approved Mode B proposal renders the original text with "Emmanuel, abound in hope".

## 4. Test results
`flutter test`: **306 passed, 0 failed** (baseline before this stage: 280). `flutter analyze`: no issues.

New test files: `test/mwb/personalisation_catalogue_test.dart` (20), `test/share_composer_test.dart` (5), and `test/mwb/catalogue_export_test.dart` (1; it writes the exports only when `EXPORT_REVIEW_CATALOGUE=1`). Updated: the Daily Word flow tests (new share flow, Mode C title, no algorithm text), navigation, onboarding, theme tokens, and the KJV-MWB review-queue expectations.

## 5. What automated validation cannot do
It cannot judge theology, pastoral appropriateness, or whether the addressee is truly representative. The classification is rule-based (genre, pronouns, curated contexts) and will contain mistakes in both directions. Every proposal therefore needs a human decision. Validation narrows the field; it never replaces review.

## 6. Import tool check
A dry run of `tool/import_review_decisions.js` against a sample file accepted 1 valid flag and refused 4 rows: an outdated version, an unknown ID, an approval of a proposal that fails checks, and an approval with no reviewer name. Nothing was written.
