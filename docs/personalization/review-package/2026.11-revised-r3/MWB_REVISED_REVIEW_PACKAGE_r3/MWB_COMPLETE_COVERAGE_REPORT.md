# MWB — Complete Coverage Report (r3)
Package 2026.11-revised-r3 · 2026-11-13

Every canonical verse carries a final presentation decision; canonical text is unchanged and re-verified by fingerprint.

## Primary presentation type (from the final per-verse index)
| Type | KJV | WEB |
|---|---:|---:|
| directPersonalisation | 111 | 106 |
| personalTitle (eligible) | 33 | 30 |
| personalReception | 35 | 37 |
| originalScriptureOnly | 30923 | 30930 |
| **Total verses** | **31102** | **31103** |

Layers (independent, in `MWB_LAYER_MAPPING_*`): KJV 200, WEB 195. Personal receptions retained: **50 per edition** (7 Psalm receptions that r2 dropped on the Psalm/Psalms key are recovered). Title layers withheld as unverifiable against their verse (shown as original Scripture meanwhile): **15** — see `MWB_TITLE_FAITHFULNESS_AUDIT.csv`.

## WEB title audit
19 individually checked against verified WEB text: 17 corrected, 2 unchanged, 0 unresolved. See `MWB_WEB_CORRECTED_TITLE_AUDIT.csv`.

## Empty WEB records
5 (`valid_non_renderable_source_record`): Luke 17:36, Acts 8:37, Acts 15:34, Acts 24:7, Romans 16:25 — omitted from WEB rendering, no text fabricated. See `MWB_WEB_EMPTY_RECORD_AUDIT.csv`.

## Determinism
All reported counts are computed from the final files. The verse→title→reception mapping is deterministic on `(edition, verse_key)`; see `MWB_LAYER_MAPPING_SPECIFICATION.md`. Validation: TOTAL: 20/20 PASS.
