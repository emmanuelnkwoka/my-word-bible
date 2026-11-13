# Claude Code Integration Guide — MWB r3
Target repo: `C:\xpatsoft\my-word-bible` · 2026-11-13

> **[VERIFY]** marks anything to confirm against the real repo. The repo was **not supplied to this review**, so importer and model details below are **unverified** and must be checked before use. The deterministic layer mapping is self-contained and does not require guessing repo internals.

## 1. Order
1. Verify source fingerprints in `MWB_REVISED_REVIEW_MANIFEST.json` against your working copy (canonical KJV/WEB must match `427f72…08b5` / `38e8e0…ed6ca`).
2. Implement `MWB_LAYER_MAPPING_SPECIFICATION.md` lookup and `MWB_PUBLICATION_POLICY.md` visibility.
3. Load layer + reception CSVs keyed by `(edition, verse_key)`.
4. **[VERIFY]** whether `tool/import_review_decisions.js` accepts the `comment` decision; if not, load decisions from the layer files instead. Do not assume compatibility.
5. Build & run the validation tests shipped here (`validation/`), then the app's own suite.

## 2. Canonical safety
No canonical asset changes. Empty WEB verses never render. Name-in-text layers stay withheld until a human ratifies. Receptions/titles render as labelled editorial layers beside the unchanged verse, never as Scripture.

## 3. Rollback
Layers and receptions are additive, keyed by `layer_id`; remove them and the canonical verses remain intact.
