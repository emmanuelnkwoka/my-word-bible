# MWB — Deterministic Layer Mapping Specification
Package 2026.11-revised-r3 · 2026-11-13

**Purpose:** give Flutter a deterministic lookup from a canonical verse to its personal title and personal reception, so the client makes **no editorial or theological decision at runtime** and never infers a title from reception text or fuzzy-matches references.

## 1. The stable key
Every record is keyed on the **canonical verse identity**, not the display string:
```
verse_key = <BOOK_ID>.<CHAPTER>.<VERSE>      e.g. PSA.30.5, ROM.15.13, 3JN.1.2
join_key  = (edition, verse_key)             edition ∈ {KJV-MWB, WEB-MWB}
```
This avoids the display drift found in the source exports (proposals say "Psalm 30:5"; the canonical index says "Psalms 30:5"). `verse_key` is identical in both, so the mapping is exact. The canonical display `reference` is carried for presentation only and is taken from the verified `all_verses_*` source.

## 2. The files
- `MWB_COMPLETE_PRESENTATIONS_{KJV,WEB}.csv` — one row per canonical verse: `verse_key`, canonical `original_text`, `primary_presentation_type`, and the boolean flags `has_personal_title`, `has_personal_reception`.
- `MWB_LAYER_MAPPING_{KJV,WEB}.csv` — **zero or more layers per verse**, each an independent row:
  `layer_id, edition, verse_key, reference, book_id, chapter, verse, layer_type, content, source_proposal_id, source_proposal_version, decision_status, publication_disposition`.
  `layer_id` is stable and unique: `<edition>:<verse_key>:<title|reception|direct>`.
- `MWB_COMPLETE_PERSONAL_RECEPTIONS_{KJV,WEB}.csv` — the reception content, also keyed by `verse_key`/`layer_id`.

## 3. Layer types (a verse may have several, independently)
`directPersonalisation` (name in the verse) · `personalTitle` (name title above the unchanged verse) · `personalReception` (editorial reception beside the unchanged verse). The unchanged canonical verse is **always** available as the base (`originalScriptureOnly`).

## 4. The exact Flutter lookup (no inference, no fuzzy match)
```
given (edition, bookId, chapter, verse):
  verse_key = bookId + "." + chapter + "." + verse
  base      = presentations[(edition, verse_key)].original_text      # always render this canonical text
  titleLayer    = layers.where(edition, verse_key, layer_type=personalTitle).singleOrNull
  receptionLayer= layers.where(edition, verse_key, layer_type=personalReception).singleOrNull
  directLayer   = layers.where(edition, verse_key, layer_type=directPersonalisation).singleOrNull
  render each present layer ONLY if its publication_disposition permits (see Publication Policy)
```
The title and the reception are retrieved **independently by layer_id**; neither is derived from the other. A missing layer is simply absent — the base canonical verse still renders.

## 5. Worked real examples (from this package)
- **PSA.30.5 (WEB):** base = "…joy comes in the morning." · title layer `WEB-MWB:PSA.30.5:title` content "{name}, joy comes in the morning" (WEB-corrected from the former KJV "cometh"). No reception layer → reception absent.
- **ROM.15.13 (KJV):** title layer "{name}, abound in hope" **and** reception layer "{name}, may the God of hope fill you…" coexist — both render independently above/below the unchanged verse.
- **ISA.41.10 (KJV):** reception layer present (`editorial_eligible`); the `directPersonalisation` name-in-text is `requires_human_ratification` and does **not** auto-render.
- **GEN.1.1:** no layers → base canonical verse only.

## 6. Guarantees (validated — see validation results)
Every `layer_id` is unique; title and reception can each exist without the other; both can coexist; the base verse always renders; WEB layers are validated against WEB source text and KJV against KJV; no layer references a missing proposal; empty WEB source verses carry no renderable layer.
