# Scripture Intelligence Corpus: Data Provenance

Corpus version 1.0.0, built 11 November 2026 (Stage C).

## 1. Sources searched

- **Historical GODSAID exports.** No export, database dump or phase report exists anywhere in this workspace. The historical figures (14 situations, 30 promises, 4 blessings, 8 prayers, 5 declarations, 11 journeys, 63 steps, 22 relationships, 100 taxonomy terms, 77 links, 393 Daily Word candidates) are **recovered historical figures** given by the founder. They were not used as targets, and **no record has origin `historicalExport`**.
- **The demo seed.** `MY_WORD_BIBLE_MWB_DEMO (1).html`, lines 851–1569. The arrays `INTEL_LIST`, `PROMISES`, `BLESSINGS`, `PRAYERS`, `DECLARATIONS`, `SITUATIONS`, `PATHS` and `RELS` were extracted verbatim with a one-time script (kept outside the repository). Each seeded record keeps the demo id (`seedId`) and its source line (`seedLine`).
- **New curation.** Written during Stage C from the wording of verses already in the seed. These records have origin `newlyCurated` and a `basis` sentence.

## 2. The five categories

| Category | In this corpus |
|---|---|
| 1. Historical reported data | Not present (no exports available) |
| 2. Demo seed data | 248 records, origin `demoSeed` (115 contexts and 22 other records have recorded changes) |
| 3. Newly curated data | 35 records: 20 commands, 5 identity themes, 6 worship themes, 4 relationships |
| 4. Rejected data | 9 seed records, listed in `manifest.json → rejected` and in §5 below |
| 5. Pending editorial review | All 283 live records (`review.status = pendingEditorialReview`); 9 carry specific review flags (§6) |

## 3. Per-file origin

| File | Records | Demo seed | Newly curated | Seed records changed |
|---|---:|---:|---:|---:|
| contexts | 117 | 117 | 0 | 115 |
| situations | 35 | 35 | 0 | 1 |
| promises | 23 | 23 | 0 | 4 |
| blessings | 12 | 12 | 0 | 1 |
| prayers | 15 | 15 | 0 | 0 |
| declarations | 10 | 10 | 0 | 10 |
| commands | 20 | 0 | 20 | — |
| identity themes | 8 | 3 (reclassified promises) | 5 | 3 |
| worship themes | 8 | 2 (reclassified promises) | 6 | 2 |
| relationships | 24 | 20 | 4 | 20 (explanations added) |
| journeys | 11 | 11 | 0 | 3 |

## 4. What changed in adopted seed records

**Contexts (117).**
- **Author separated from speaker.** The demo filled `auth` with the speaker (for example, Jesus as "author" of John 3:16). Authors are now set by traditional attribution, labelled as traditional, and psalm authors come from their superscriptions.
- **Ten psalm verses the demo attributed to David** have a different superscription or none: Ps 42:11, 46:1, 46:10, 91:1, 91:11, 119:105, 121:7, 121:8, 127:3, 147:3.
- **Addressee type and conditions added.** Every context was classified by curation. Conditions quote the KJV wording.
- **Personalisation strategies kept as candidates only.** The demo's `pre`/`subs` strategies are recorded as `eligibility: reviewRequired` (78 contexts). **None of the demo's personalised renderings was imported**: they contain the defects described in `docs/product/MWB_ORIGINAL_DEMO_AUDIT.md` §4, including Ephesians 2:10. The 39 verses the demo refused to personalise keep its reason as `notEligible`.
- **Risk computed by rule:** divine speech is critical; words of Jesus, collective or specific audiences, testimony, narrative and conditional passages are high; general statements are medium; representative address is low.
- **Psalm 32:8** is flagged because interpreters differ on the speaker.

**Promises (23 adopted of 31).**
- **Conditions** were added from the contexts.
- **Scope** was set from the addressee.
- **Reception guidance was rewritten for four promises** to stop a corporate or historical promise reading as a personal guarantee:
  - pr-fam-1 (Isa 54:13)
  - pr-prov-1 (Phil 4:19)
  - pr-prot-2 (Ps 91:11)
  - pr-str-2 (Ex 14:14)

**Declarations (10).** All were rewritten.
- The demo used *he/him/his* for every reader and the `⟦F⟧` token.
- Each now has a third-person `{name}` form without gendered pronouns, plus a first-person form.
- Corporate sources stay corporate ("His people").
- Psalm 4:8 was added as support for "lie down in peace" (dc-night).

**Situations.** Malachi 3:10 was removed from *Financial pressure*: it is a covenant charge to post-exilic Judah, and the demo itself warns against reading it as a prosperity formula.

**Journeys.**
- Steps that pointed to reclassified promises were retargeted:
  - pr-cour-2 → id-spirit-of-power
  - pr-ident-2 → id-workmanship
  - pres-always → pr-pres-2
- The typo "ΚJV" (a Greek Kappa in place of K) was corrected.

**Relationships.**
- Explanations were written; the demo had none.
- Isa 41:13 ↔ 41:10 was retyped as *contextual*.
- Isa 53:5 ↔ Ps 103:3 was retyped from *explanation* to *theme*.

## 5. Rejected seed records

| Kind | Seed id | Demo line | Reason | Replacement |
|---|---|---:|---|---|
| promise | pr-hope-1 | 1259 | Lam 3:22-23 is a confession of God's faithfulness, not a promise | ws-faithfulness |
| promise | pr-wis-2 | 1268 | Ps 119:105 is a statement to God about His word, not a promise | ws-word-lamp |
| promise | pr-fam-2 | 1274 | Josh 24:15 is Joshua's resolve and a command to choose | cmd-choose-whom-to-serve |
| promise | pr-faith-1 | 1277 | Heb 11:1 defines faith; it is not a promise | — |
| promise | pr-cour-2 | 1280 | 2 Tim 1:7 states what God has given: identity, not promise | id-spirit-of-power |
| promise | pr-ident-1 | 1285 | Ps 139:14 is David's praise to God: identity, not promise | id-wonderfully-made |
| promise | pr-ident-2 | 1286 | Eph 2:10 is a corporate identity statement ("we"), not a promise | id-workmanship |
| promise | pres-always | 1481 | Duplicate alias of pr-pres-2 (Matt 28:20), created only for a journey | pr-pres-2 |
| relationship | heb13-5 ↔ isa41-10 | 1557 | Marked as a quotation, but Heb 13:5 quotes Deut 31:6-8 / Josh 1:5 | rel-heb13-5-deut31-6 |

**Not imported at all:**
- every demo personalised rendering (`mwb.subs` / `pre` output);
- the demo's Daily Word candidates (Stage D);
- the `SIM_USERS` personas;
- the demo `TRANSLATIONS` list.

## 6. Records flagged for editorial attention

| Record | Flag |
|---|---|
| ctx-PSA-32-8 | Speaker disputed (God or the psalmist) |
| sit-business, sit-success | Deut 8:18 is covenant context for Israel; it must not read as a promise of wealth |
| py-healing, py-sickness, dc-healing | Healing texts (Ex 15:26 covenant; Jer 30:17 to Zion; Isa 53:5); must not promise a guaranteed cure |
| dp-sickness | Same healing concern in journey notes |
| dp-provision | Step note "'I shall not want' is arithmetic under His care" may overstate |
| cmd-train-up-a-child | A proverb is a general principle, not a guarantee about every child |

## 7. Observation about the bundled KJV (not changed)

While comparing the demo's quotations with `assets/bible/kjv.json`, 16 of 117 demo quotations differed from the bundled text. The causes are:
- a space before punctuation in the bundled KJV ("the LORD ," "the LORD ;");
- one spelling variant ("Judæa" vs "Judaea").

Across the whole bundled KJV, **4,306 verses** contain a space before punctuation. This looks like an artefact of how the source text was prepared. It affects display and copy, not this corpus, which stores no verse text. **Canonical text was not changed.** Correcting it needs a separate, authorised decision about the KJV source.
