# MWB — Change Log: r2 → r3
2026-11-13

r2 (`MWB_REVISED_REVIEW_PACKAGE`) is preserved unchanged as the immutable reference. r3 is a **data-integrity repair** — no new theological review; all valid r2 decisions preserved.

## Corrections made (evidence-based)
1. **Source verification (Part 1):** canonical KJV `all_verses_kjv.csv` = `427f72…08b5` and WEB = `38e8e0…ed6ca` — both **match** the provided hashes; `review_records.json` and `proposals.csv` match the r2 manifest. Verified, not assumed.
2. **19 WEB corrected titles (Part 3):** every one re-checked against verified WEB text. **17 corrected** to WEB wording (removed KJV crossover: "cometh"→"comes", "unto"→"to", "stablish"→"establish", "overcometh"→"has overcome", "generation"→"race", "every thing"→"everything"; and a **meaning** fix at 1 John 1:4: "your joy may be full" → "our joy may be fulfilled"). **2 needed no change**; **0 unresolved**. See `MWB_WEB_CORRECTED_TITLE_AUDIT.csv`.
3. **Deterministic layer mapping (Part 2/4):** new `MWB_LAYER_MAPPING_{KJV,WEB}.csv` — a verse may hold independent title + reception + direct layers, each with a stable `layer_id`, keyed on `verse_key = BOOK_ID.chapter.verse`. The 43-vs-26 reception discrepancy is resolved: all **50** receptions per edition are retained and independently addressable (`MWB_RECEPTION_RECONCILIATION.csv`).
4. **Reference drift found & fixed:** proposals used "Psalm" while the canonical index uses "Psalms" (103 refs). r3 keys everything on `verse_key`, and this silently caused **7 Psalm receptions to be dropped in r2**; they are now correctly mapped. No reception was deleted.
5. **5 empty WEB records (Part 6):** Luke 17:36, Acts 8:37, Acts 15:34, Acts 24:7, Romans 16:25 — all `valid_non_renderable_source_record` (absent in the WEB source; present in KJV versification). Handling: omit from WEB rendering, keep diagnostic. No text fabricated. See `MWB_WEB_EMPTY_RECORD_AUDIT.csv`.
6. **Publication policy (Part 5):** `approvedPresentation` (internal acceptance) separated from human ratification (none fabricated) and from per-layer production visibility. Name-in-text now `requires_human_ratification`; titles/receptions are `editorial_eligible`. See `MWB_PUBLICATION_POLICY.md`.
7. **Importer contract (Part 8):** the Flutter repository was **not supplied**, so importer compatibility (including whether `comment` is accepted) is **UNVERIFIED**. The layer mapping is provided as the authoritative implementation contract. Documented as a limitation, not claimed as compatible.

## Preserved from r2
All proposal IDs/versions, all approved decisions, all valid receptions (now 50/edition), all canonical text, all theological conclusions and editorial reasoning.

8. **Title faithfulness gate (new):** every eligible title is validated against its own edition's verse text. **15** pre-existing catalogue titles (e.g. Romans 5:1 'saved by grace through faith' — that wording is Eph 2:8; Lamentations 3:22 using v.23's phrase; 1 Peter 5:7 adding 'burden'/'Lord') could not be substantiated from their verse and are **withheld** (original Scripture shown), not rewritten and not published. See `MWB_TITLE_FAITHFULNESS_AUDIT.csv`.
