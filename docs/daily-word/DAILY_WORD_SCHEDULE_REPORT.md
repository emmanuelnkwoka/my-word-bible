# Daily Word Schedule Report (schedule 2026.1)

## 1. Source of candidates

- **The 393 historical candidates are not available in the workspace and were not reconstructed.**
- The demo HTML has 54 Daily Word entries plus the leap candidate. All 55 are used as seeds, with their demo ids and lines.
  - One demo title was changed: Isaiah 54:13 "Peace for your children" became "Children taught of the LORD", because the verse was spoken to Zion.
- Every other candidate is a passage that already has a curated Stage C context. Each was given a category and a short theme during curation (origin `newlyCurated`, recorded in `provenance.basis`).
- **No passage was invented.**

| Measure | Count |
|---|---:|
| Candidates | **114** (55 demo seed, 59 newly curated) |
| Annual pool | **113** |
| Reserved leap candidate | **1** (Revelation 21:5, "All things new") |
| Passages held back | **3**: Malachi 3:10, Deuteronomy 8:18, Proverbs 10:22 (prosperity-misreading risk; recorded in `candidates.json → excluded`) |
| Categories | 16: Hope, Peace, Strength, Courage, Provision, Comfort, Wisdom, Healing, Rest, Gratitude, Identity, Protection, Guidance, Purpose, Faith, Family |

Pool by category:

| Category | Passages | Category | Passages |
|---|---:|---|---:|
| Faith | 13 | Strength | 7 |
| Peace | 12 | Gratitude | 7 |
| Protection | 12 | Identity | 5 |
| Hope | 9 | Family | 5 |
| Comfort | 9 | Provision | 4 |
| Courage | 8 | Healing | 4 |
| Purpose | 8 | Guidance | 4 |
| | | Wisdom | 3 |
| | | Rest | 3 |

## 2. Construction (`tool/build_daily_schedule.js`, deterministic)

1. **Interleave:** repeatedly take the next passage from the category with the most passages left that is not the previous category. Ties follow the category list order; within a category, corpus order is used. The result is a 113-day cycle.
2. **Seam:** the cycle is rotated so its last and first days differ in category.
3. **Days:** 365 entries, `01-01` … `12-31` (a common year), each mapped to `cycle[(day − 1) mod 113]` with an `occurrence` number.
4. **Leap day:** `02-29` maps to the reserved leap candidate (Revelation 21:5), which is never used on any other date or by adaptive selection.

## 3. Coverage and reuse

| Measure | Result |
|---|---|
| Dates covered | 365 of 365, plus 29 February |
| Distinct passages scheduled | 113 (every pool passage) |
| Uses per passage per year | 3 or 4 |
| Spacing between recurrences | exactly 113 days |
| Same category on consecutive days | never, including 28 Feb → 29 Feb → 1 Mar and 31 Dec → 1 Jan (tested across 2028) |

**Reuse is recorded explicitly:**
- `occurrence` gives the n-th use of a passage in the year.
- `cycleLength` and `note` in `schedule.json` explain the recurrence.

## 4. Date mapping

- **Lookup is by month and day** (`monthDayOf`), so a date maps to the same passage in every year.
- **Leap years** do not shift any date: 28 February and 1 March keep their own passages, and 29 February adds Revelation 21:5.

## 5. Versioning and review

- `scheduleVersion` is `2026.1` in both files and is stored on every delivered history entry. `corpusVersion` (1.0.0) ties the schedule to Stage C.
- All candidates are `pendingEditorialReview`, and Stage C review flags are carried over. **Nothing is labelled editorially or theologically approved.**
- Rebuilding: `node tool/build_daily_schedule.js --force`. A new schedule should get a new `scheduleVersion`; delivered history is never rewritten.

## 6. Limitations

- With 113 passages, each recurs every 113 days. A larger reviewed pool (ideally the historical candidates) would allow 365 distinct days.
- Wisdom, Rest, Provision, Healing and Guidance have only 3–4 passages each, so their passages recur together.
