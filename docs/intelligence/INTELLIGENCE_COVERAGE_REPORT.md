# Scripture Intelligence Corpus: Coverage Report

Corpus version 1.0.0, 11 November 2026.

**These are record counts in this corpus. They are not GODSAID historical quantities**, which are listed separately below for reference only. No record was invented to match a historical figure.

## 1. Record counts

| Measure | Count |
|---|---:|
| Contexts | **117** |
| Life situations | **35** |
| Promises | **23** |
| Blessings | **12** |
| Prayers | **15** |
| Declarations | **10** |
| Commands | **20** |
| Identity themes | **8** |
| Worship and thanksgiving themes | **8** |
| Scripture relationships | **24** |
| Guided journeys | **11** |
| Journey steps | **55** |
| Taxonomy terms / links | **28 / 83** |
| Distinct canonical Scripture references | **128** (verses or ranges; 467 reference uses in total) |
| Records awaiting editorial review | **283** (all live records; 9 with specific flags) |
| Records rejected | **9** (8 promise seeds, 1 relationship seed) |

## 2. Context profile

| Dimension | Breakdown |
|---|---|
| Voice | God's direct words 22 · Words of Jesus 23 · Inspired human messages 72 |
| Addressee | Collective 72 · General 12 · Specific individual 10 · Representative 10 · Testimony 6 · Addressed to God 5 · Narrative 2 |
| Conditional passages | 33 (each with a stated condition) |
| Personalisation eligibility | Review required 78 · Not eligible 39 · Unassessed 0 · **Approved: none (no such value)** |
| Historical context / literary context text | **Not yet written** for any context (fields exist, empty). `literaryForm` is set for all 117. |

## 3. Promise profile

| Measure | Count |
|---|---:|
| Corporate scope | 14 |
| General | 5 |
| Given to a specific person | 4 |
| Promises with conditions | 9 |

## 4. Relationship profile

| Type | Count |
|---|---:|
| Theme | 19 |
| Quotation | 1 (Heb 13:5 → Deut 31:6, corrected) |
| Promise and condition | 2 |
| Supporting | 1 |
| Contextual | 1 |
| Explanation | 0 (the only demo "explanation" link was retyped) |

## 5. Situation links

| Link type | Situations with a link | Situations without |
|---|---:|---:|
| Promise | 20 | 15 |
| Prayer | 14 | 21 |
| Journey | 11 | 24 |

Every situation cites Scripture (2–7 references).

## 6. Comparison with recovered historical figures (reference only)

| Category | Historical (recovered, unverified) | This corpus | Note |
|---|---:|---:|---|
| Life situations | 14 | 35 | Demo seed is larger; nothing was dropped to match |
| Promises | 30 | 23 | 8 demo promises were rejected or reclassified |
| Blessings | 4 | 12 | |
| Prayers | 8 | 15 | |
| Declarations | 5 | 10 | |
| Commands | 9 | 20 | Newly curated from seed verses; not the historical set |
| Identity themes | 10 | 8 | |
| Worship themes | 7 | 8 | |
| Journeys / steps | 11 / 63 | 11 / 55 | |
| Relationships | 22 | 24 | |
| Taxonomy terms / links | 100 / 77 | 28 / 83 | Different design: a theme vocabulary, not the historical taxonomy |
| Context profiles | 54 | 117 | |
| Daily Word candidates | 393 | — | Stage D |

## 7. Gaps for later stages

- **Context depth:** `historicalContext` and `literaryContext` text, and audience notes beyond one line.
- **Coverage:** 117 passages is a curated starting set, not the whole Bible. No context exists for most of the Proverbs passages covered by the MWB rulesets. Those still rely on `assets/mwb/passage_context.json`, which this stage kept separate and unchanged.
- **Daily Word candidates** (Stage D) and **Search V2 indexing** (Stage E) will consume `searchEntries` and the taxonomy.
- **Reader-facing display:** no screen shows the corpus yet. This waits for Stage G (Pray / Discover) and for a Personal Reception view whose design is not yet approved.
- **Editorial review:** every record is pending, and the 9 flagged records need attention first.
