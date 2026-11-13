# MWB — Implementation Instructions (r3)
2026-11-13

## 1. Authoritative contract = the layer mapping
Implement against `MWB_LAYER_MAPPING_SPECIFICATION.md` and `MWB_PUBLICATION_POLICY.md`. The deterministic key is `verse_key = BOOK_ID.chapter.verse` with `(edition, verse_key)`. Title and reception are independent layers; never infer one from the other.

## 2. Schema
Presentation types: `directPersonalisation | personalTitle | personalReception | personalReflection | prayerReception | originalScriptureOnly`. Disposition `approvedPresentation` (internal acceptance) is distinct from human `approved`. Per-layer `publication_disposition` governs visibility (see policy).

## 3. Load
- Canonical verses: unchanged KJV/WEB assets (fingerprints in the manifest).
- Layers: load `MWB_LAYER_MAPPING_{KJV,WEB}.csv` into an index keyed by `(edition, verse_key)`; receptions content from `MWB_COMPLETE_PERSONAL_RECEPTIONS_{KJV,WEB}.csv`.
- Decisions: `MWB_REVISED_FINAL_DECISIONS_{KJV,WEB}.csv` remain in the existing 16-column importer schema **but importer compatibility is UNVERIFIED (repo not supplied)** — confirm the importer accepts the `comment` value before relying on it; otherwise ingest via the layer files directly.

## 4. Empty WEB verses
Luke 17:36, Acts 8:37, Acts 15:34, Acts 24:7, Romans 16:25 have no WEB text — render nothing for them in WEB (fail safe), keep diagnostics.

## 5. Visibility
Base canonical verse: always. Title/reception: show when `editorial_eligible`. Name-in-text: withhold (`requires_human_ratification`) and show the original + a safe editorial layer instead.
