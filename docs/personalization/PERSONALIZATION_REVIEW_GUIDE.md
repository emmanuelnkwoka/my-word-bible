# Personalised Scripture Review Guide (for theological supervisors)

You are asked to decide, verse by verse, whether a personalised rendering may be shown to readers. **Nothing appears to readers as personalised Scripture until you, a named reviewer, approve the exact version you have seen.**

## 1. What you are reviewing
- **Mode A — name inside the Scripture.** The reader's name is added as a direct address set off by commas. Example (Proverbs 3:1): "My son, **[Name]**, forget not my law…". No word of the translation is removed or changed.
- **Mode B — name in the title.** The Scripture is shown exactly as written. Only a short editorial title carries the reader's first name. Example: "**[Name]**, abound in hope" over the unchanged Romans 15:13.
- **Mode C — the original.** Every verse without an approved proposal.

`[Name]` stands for the name each reader chooses: full name, first name or preferred name, or none at all. Titles use the first or preferred name. Gender is never used.

## 2. Where to review
You have three equivalent options:

1. **In the app** (reviewer build): Profile → Theological review → Personalisation review. Choose KJV-MWB or WEB-MWB, filter by Pending / Approved / Corrected / Rejected / Flagged, then book → chapter → verse → proposal. Tap "Set your reviewer name" first; every decision carries that name and the date.
2. **Excel:** `exports/personalisation-review/MWB_Personalisation_Review_Catalogue.xlsx`. Sheet 1 explains the columns, sheet 6 is for your decisions, and sheet 8 lists every verse with its classification.
3. **Print:** `exports/personalisation-review/printable/kjv-mwb-review-catalogue.pdf` (and `web-mwb-…`). This has one card per proposal, with approve / reject / correct / flag boxes.

## 3. What to check for each proposal
1. **Speaker:** who is speaking? A name must never put words in God's mouth that He did not address to the reader, or change the speaker of a psalm.
2. **Audience:** to whom was it first written? Is it representative (anyone in the learner's place) or a specific person or people (Israel, Timothy, Gaius)?
3. **Promise:** is a collective or conditional promise being turned into a personal guarantee?
4. **Grammar:** does the sentence read naturally with a name in it? Is the punctuation right?
5. **Context:** does the verse depend on the verse before or after it (for example the condition in Proverbs 23:17)?
6. **Title (Mode B):** is the title faithful, modest, and free of first-person words?

The card shows the automated checks. **"Automated checks passed" is never an approval.** It only means the wording is structurally sound and the original is exactly recoverable.

## 4. Decisions
| Decision | When | Required |
|---|---|---|
| **Approve** | Faithful as shown | Your name and date. Only possible when automated checks pass for this version. |
| **Reject** | Should not be personalised | A reason |
| **Correct** | Right idea, wrong wording | Your name, plus the full corrected verse with `{name}` where the name goes (Mode A) or the corrected title (Mode B). This creates **version n+1**, which must then be approved separately. |
| **Flag** | Unsure; needs discussion | A reason |
| **Comment** | A note for the record | — |
| **Reopen** | Revisit a decided proposal | Your name and a reason |

Approvals apply to **one version**. If a proposal is later corrected, the old approval no longer counts.

## 5. Returning decisions from Excel or CSV
Fill sheet 6 (or `review_decisions_template.csv`). Keep `proposal_id` and `proposal_version` exactly as given. Write one of `approve`, `reject`, `correct`, `comment`, `flag`, `reopen`, plus `reviewer`, `reviewer_role`, `decision_date` (YYYY-MM-DD) and `comments`.

The development team then runs:
```
node tool/import_review_decisions.js returned.csv --dry-run   # shows what would be accepted or refused
node tool/import_review_decisions.js returned.csv
```
Each row is matched to its exact proposal ID **and** version. Rows for an unknown ID, an outdated version, or a missing reviewer, date or reason are **refused and listed**; nothing else changes. Accepted decisions are stored in `assets/mwb/reviews/<edition>.decisions.json` and ship with the next build.

## 6. Questions already waiting for you
- **Romans 15:13 (founder reference wordings).** Both fail automated checks. Mode A turns the plural "you" into one person while "ye" remains. Mode B capitalises "You", which reads as a divine pronoun. A compliant alternative, `kjv-mwb.ROM.15.13.b` (unchanged text, title "[Name], abound in hope"), passes the checks and awaits your decision.
- **Isaiah 41:10:** divine speech to Israel (critical risk).
- **3 John 1:2:** a wish written to Gaius.
- **Proverbs 1:8:** "thy father / thy mother": is this pastorally appropriate for every reader?
- **Proverbs 23:18:** whether the name may appear when verse 17 is not shown.
- **The 350 Mode B proposals without a title:** either supply a title (Correct) or reject.

The designated theological supervisor is **Pastor Obi Ogbo**. Being designated is not an approval: an approval exists only when he, or another named reviewer, records it.
