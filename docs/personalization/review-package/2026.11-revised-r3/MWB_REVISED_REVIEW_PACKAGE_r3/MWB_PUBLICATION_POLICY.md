# MWB — Publication Policy (authoritative)
Package 2026.11-revised-r3 · 2026-11-13

## 1. Three distinct concepts (never conflated)
- **Internal product acceptance** — `approvedPresentation`. Means the layer passed this internal review. It is **not** canonical alteration and **not** a human supervisor's approval.
- **Human theological ratification** — a real approval recorded by the designated supervisor (Pastor Obi Ogbo). **No such record exists in this package and none is fabricated.** No approval dates, signatures, or supervisor decision records were created.
- **Production visibility** — a per-layer decision (`publication_disposition`) about whether a layer may appear in a normal build.

## 2. Per-layer publication_disposition
| Value | Applies to | May appear in production? |
|---|---|---|
| `always_canonical` | the base canonical verse (`originalScriptureOnly`) | Yes — always. |
| `editorial_eligible` | `personalTitle`, `personalReception` (Scripture unchanged; editorial layer) | Yes — internally accepted, no canonical alteration. |
| `requires_human_ratification` | `directPersonalisation` (name **inside** the verse = an altered canonical rendering) | **No** — withhold the altered verse; render the original canonical verse plus any `editorial_eligible` title/reception as the safe alternative, until a human ratifies. |
| `unresolved_withhold` | any layer whose evidence was insufficient | **No.** |

Rationale: a personal **title** or **reception** leaves the canonical text exactly as written (an editorial layer beside it), so internal acceptance is sufficient to show it. A name **inserted into the verse** is an altered canonical rendering; per the founder's §5.3 that requires human ratification, so it is withheld while the original + a safe editorial layer are shown.

## 3. Rules
- Do **not** auto-publish a record merely because a CSV says `approvedPresentation`; honour its `publication_disposition`.
- Do **not** hide an `editorial_eligible` reception because another layer on the same verse is withheld — each layer publishes independently.
- Unresolved or invalid layers never appear.
- Human ratification, when it happens, is recorded separately; it is never implied by this package.
