# Personalisation review exports

Generated 12 Nov 2026 from catalogue `2026.11-d1`. **Nothing here is approved.**

| File | Contents |
|---|---|
| `MWB_Personalisation_Review_Catalogue.xlsx` | 8 sheets: Review instructions · Proposal catalogue · Original vs personalised · Excluded passages · Flagged passages · Review decisions · Coverage statistics · All verses |
| `review_decisions_template.csv` | One row per proposal (stable ID + version) for returning decisions |
| `csv/proposals.csv` | Every proposal with all fields |
| `csv/original_vs_personalised.csv` | Side-by-side text |
| `csv/excluded_passages.csv`, `csv/flagged_passages.csv` | Every excluded or flagged verse with its reason |
| `csv/all_verses_kjv.csv`, `csv/all_verses_web.csv` | Every canonical verse with its classification |
| `csv/coverage_statistics.csv` | Exact counts |
| `printable/*-review-catalogue.html` / `.pdf` | Printable catalogue: one card per proposal, plus per-book summaries |
| `review_records.json` | Source data for all of the above (written by the Dart export test) |

Regenerate:
```
node tool/build_personalisation_catalogue.js
EXPORT_REVIEW_CATALOGUE=1 flutter test test/mwb/catalogue_export_test.dart
node tool/export_review_catalogue.js
```
Import returned decisions: `node tool/import_review_decisions.js <file.csv> [--dry-run]` (see `docs/personalization/PERSONALIZATION_REVIEW_GUIDE.md`).
