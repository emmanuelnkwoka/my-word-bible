# Adaptive Relevance Report (as implemented)

## 1. Principle

The annual schedule is the baseline. With personalisation on, another passage from the pool may replace the scheduled passage, but **only when the reader's own local signals point to it and its total score beats the scheduled passage's total**. Everything is deterministic and explained, and nothing leaves the device.

## 2. Signals (`buildRelevanceProfile`)

Signals count only if they are within the last **30 days** and recorded after the last *Clear Daily Word signals*.

| Signal | Source |
|---|---|
| Interests | Interests chosen at onboarding / Content preferences (not affected by clearing) |
| Searches | Each query saved to recent searches is also recorded as a local signal (`relevanceSignalsProvider`, kept 90 days, max 400) |
| Reading | Reading history: chapters and books |
| Engaged Scripture | Saved Scripture, highlights and notes (saved Daily Words excluded) |
| Favoured themes | Categories of Daily Words the reader favourited or saved |
| Recent Daily Words | Delivery history (freshness and diversity) |

**Not used:** prayer and journey engagement, and explored situations. No screen records them yet; they need Stage G.

## 3. Scores (`AdaptiveRelevanceScorer`)

| Dimension | Points | Reason text |
|---|---:|---|
| Schedule anchor (the scheduled passage) | +25 | "Today's passage in the annual schedule" |
| Interest matches the category | +30 | "Fits an interest you chose (Faith), in the theme Hope" |
| Search term matches a keyword, theme or situation name | +8 per term, capped at 24 | "Related to topics you searched for recently" |
| Same chapter read / same book read | +12 / +4 | "From a chapter you read recently" / "From a book you have been reading" |
| Related (Stage C relationship or shared life situation) to Scripture saved, highlighted or noted | +15 | "Connected to Scripture you saved, highlighted or noted" |
| Category of favourited or saved Daily Words | +10 | "A theme of Daily Words you saved or favourited" |
| Same category as yesterday | −25 | "Same theme as yesterday" |
| Each earlier word in that category in the past 7 days | −8 each | "Theme already received this week" |

**Interest → category mapping:**

| Interest | Categories |
|---|---|
| faith | Faith, Hope, Courage |
| prayer | Peace, Faith |
| understanding | Wisdom, Guidance |
| growth | Strength, Identity, Purpose |
| family | Family |
| purpose | Purpose, Guidance |
| wisdom | Wisdom, Guidance |
| living | Gratitude, Rest, Peace |
| development | Purpose, Wisdom, Strength |

## 4. Selection (`DailyWordEngine.select`)

1. **29 February**, or personalisation off: use the schedule.
2. **Freshness:** passages delivered in the last **60 days** are excluded.
3. **Score** every remaining pool passage.
4. **Contenders** are passages with signal points greater than 0, ranked by total. Ties are broken by FNV-1a hash of `date|candidateId`, which is stable on every device.
5. **Choice:**
   - The best contender replaces the schedule only if its total is strictly higher than the scheduled passage's total.
   - With no signals, the schedule is used.
   - If the scheduled passage itself was received recently and no contender exists, the next fresh passage in the schedule is used (reason `freshness` / `schedule.next`).
6. **Effect:** a single weak signal (a search, worth at most 24) can never override the schedule anchor (25). An interest can, unless that category was used yesterday (30 − 25 < 25).

The stored summary for an adaptive choice reads: "Chosen from the Daily Word pool instead of the scheduled X: … This is based only on your activity on this device."

## 5. Safeguards

- **No assumptions about the reader:** reasons describe activity ("topics you searched for") and never a personal condition. A test checks that generated reasons and summaries never contain "God" or phrases such as "you are struggling".
- **No divine claims:** the screen states that the choice is "not a claim about what God is saying to you personally."
- **Stability:** today's word is stored on first delivery and never recomputed, even if new signals arrive the same day.
