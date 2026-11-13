# MWB r3 — Validation Results
Executed by `validation/validate_r3.py` against verified sources and final r3 files.

```
==== MWB r3 VALIDATION ====
  [PASS] T1 every edition/reference/layer mapping unique
  [PASS] T2 multiple editorial layers can coexist for one verse
  [PASS] T3 a personal title can exist without a reception
  [PASS] T4 a personal reception can exist without a title
  [PASS] T5 both layers can coexist
  [PASS] T6 original Scripture renders without editorial layers
  [PASS] T7 canonical text unchanged vs verified source (62,205)
  [PASS] T8 eligible WEB titles validated against WEB source text
  [PASS] T9 eligible KJV titles validated against KJV source text
  [PASS] T10 no eligible title layer has empty content
  [PASS] T11 every layer source_proposal_id exists in decisions
  [PASS] T12 empty WEB source records cannot render as verses
  [PASS] T13 unresolved/withheld layers never marked eligible
  [PASS] T14 no fabricated human ratification (no 'Obi Ogbo approved')
  [PASS] T15 disposition uses approvedPresentation (internal), not human 'approved'
  [PASS] T16 all 50 receptions retained per edition, independently keyed
  [PASS] SRC KJV fingerprint matches provided
  [PASS] SRC WEB fingerprint matches provided
  [PASS] AUDIT all 19 WEB titles individually checked
  [PASS] AUDIT 5 empty WEB records documented

TOTAL: 20/20 PASS
```
All tests executed (not asserted). Re-run: `python3 validation/validate_r3.py`.
