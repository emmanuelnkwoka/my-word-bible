# Original MWB HTML Demonstration: Forensic Audit

- **File:** `C:\xpatsoft\my-word-bible\MY_WORD_BIBLE_MWB_DEMO (1).html` (289,285 bytes, 3,395 lines; untracked in git).
- **Structure:**
  - CSS: lines 9–589
  - Markup: lines 591–771
  - Application script: lines 773–3394, one IIFE
  - Line 3395 loads a Cloudflare Insights beacon from `static.cloudflareinsights.com`. This was most likely injected by the web host when the page was saved, not written by the author. It contradicts the demo's own "no tracking" statements (lines 734, 665), so it should be removed from any distributed copy.
- **Method:** I read the full source, including every function listed below. I did not run the page in a browser. Behaviour classifications come from reading the code paths, not from screenshots.

## Classification key

| Label | Meaning |
|---|---|
| **Functional** | Real logic runs on real (if small) data and does what it claims |
| **Partial** | Works but limited, or part of the claim is not implemented |
| **Simulated** | Output depends on hard-coded inputs standing in for real behaviour |
| **Static** | Fixed text or markup |
| **Conceptual** | Described only; no implementation |

---

## 1. Shell, pages and navigation

| Item | Location | Classification |
|---|---|---|
| Sticky header: menu, brand, version chip, light/dark toggle | 596–614, `init()` 3356–3388 | Functional. The chip toggles KJV ↔ KJV-MWB. |
| Bottom nav: Home · Bible · Discover · Pray · Saved | 742–748 | Functional |
| Drawer and desktop side nav: Home, Bible, Daily Word, Discover, Pray, Saved, Poster Studio, Search, Insights | `NAV` 3323–3325, `buildNav()` 3326 | Functional |
| Views: `home`, `bible`, `daily`, `discover`, `pray`, `saved`, `poster`, `search`, `profile` ("Insights") | 623–736, `renderView()` 3349 | Functional |
| Detail bottom-sheet for every object type (verse, promise, prayer, declaration, blessing, situation, journey, daily) | `openSheet()` 2137, `open*()` 2210–2488 | Functional |
| Toast, Escape key, focus management | 843, 3367 | Functional |
| Local storage (`mwb.*` keys) | `K`/`Store` 835–840 | Functional |

**Navigation model:** five bottom tabs, with **Daily Word, Poster Studio, Search and Insights reachable only from the drawer** (or the home "Word calendar" link, line 631). This matters for the navigation recommendation in the roadmap.

## 2. Data structures (the miniature corpus)

| Structure | Line | Contents | Classification |
|---|---|---|---|
| `CANON` | 856 | 66 books × chapter verse counts (31,102 verses) | Functional (structure) |
| `TRANSLATIONS` | 863 | KJV embedded. ASV/WEB "production". NLT/NIV/ESV "future". | Static |
| `FEATURED` | 876 | Full KJV text for 11 chapters: Gen 1, Ps 23, 46, 91, 103, 121, 139, Prov 23, Matt 6, John 14, Phil 4 | Functional (partial corpus) |
| `INTEL` / `V()` | 1120–1255 | 117 context profiles. Fields: `spk` speaker, `auth` author, `aud` original audience, `insp` classification, `grp`, `kw` keywords, `kjv` text, `mwb` strategy, `rev` review reason, `note` | Functional |
| `PROMISES` | 1258 (+alias 1480) | 30 (+1) promises, each anchored to one verse, with a reception note `rec` | Functional |
| `BLESSINGS` | 1292 | 12 blessings with Scripture refs | Functional |
| `PRAYERS` | 1307 | 15 Scripture-grounded prayers, each with ≥2 refs | Functional |
| `DECLARATIONS` | 1326 | 10 declarations with `⟦F⟧` first-name tokens | Functional, with defects (see §4) |
| `SITUATIONS` | 1373 | 35 life situations with refs | Functional |
| `PATHS` | 1412 | 11 guided journeys, 55 ordered steps (situation, verse, promise) | Functional |
| `DAILY_WORDS` + `LEAP_CANDIDATE` | 1484–1554 | 54 candidates in 16 categories (48 scheduled, 6 `pool`-only) + Rev 21:5 leap | Functional |
| `RELS` | 1557 | 21 bidirectional verse relationships, 3 types used | Functional |
| `REFLECT` / `APPLY` | 2174–2192 | Reflection prompt per category; one generic "apply" list | Static |
| `SIM_USERS` | 2776 | 4 hard-coded personas for the adaptive simulator | Simulated |

## 3. Personal Reception and speaker integrity

- **`voiceOf()`** (1619–1623) labels each verse "God speaks", "Jesus speaks" or "A human voice". Functional.
- **The verse sheet** (`openVerse()`, 2210–2280) shows:
  - KJV or KJV-MWB with a per-verse toggle;
  - the personalisation strategy, or a "manual review required" reason;
  - a **context grid** (speaker, human author, original audience, classification);
  - a "note on reading this well";
  - the **Personal Reception panel**;
  - related Scripture from `RELS`;
  - actions: save, "Pray this word", "Declare it", share.

  Functional.
- **`receptionPanel()`** (2193–2207) frames reception honestly: *"Originally spoken by … to … Its truth can be personally received by you today — nothing here claims the passage was written privately to you."* This is the clearest written statement of Personal Reception anywhere in the evidence. Functional.

## 4. DSPE personalisation engine: `mwbPersonalize()` (1589–1618)

**Algorithm.**
- **Gate:** `v.mwb == null` → original KJV, with the reason from `rev`.
- **Strategy `pre`** (41 verses): `t = "⟦N⟧, " + lowercase(first char) + rest` (**line 1600**).
- **Strategy `subs`** (37 verses): apply each curated `[find, replace]` pair. If any `find` is missing, the integrity gate fails and the original KJV is shown with "manual review".
- **Tokens:** `⟦N⟧` → full name and `⟦F⟧` → first name, rendered as `person` segments (`resolveTokens()`, 1576–1584).

**Classification: functional, but the integrity gates are only partly real.**
- **What is real:** the eligibility gate, exact-substring checks for substitutions, and the fallback to the original.
- **What is only named:** the comment at 1571–1575 lists "semantic · contextual · grammatical · relational · versional" gates. No code checks grammar, person, number, gender, capitalisation or audience. Those checks exist only as the author's choice of curated strings.

**Defects found by reading the code and data.** These are all demo defects. None of these renderings exists in the Flutter rulesets (see `FLUTTER_IMPLEMENTATION_AUDIT.md` §5).

| # | Defect | Evidence | Rendering produced |
|---|---|---|---|
| D1 | **Ephesians 2:10 subject substitution.** The collective "we" is replaced by a single person, and "his" becomes ambiguous (God's workmanship, or the named person's?). The second clause turns "we" into "he". | line 1234: `S([["For we are his workmanship","For ⟦N⟧ is his workmanship"],["that we should walk","that he should walk"]])` | "For Emmanuel Nkwoka is his workmanship, … that he should walk in them." **This is exactly the defect the founder observed.** |
| D2 | Lower-casing a verse's first letter breaks capitalised words | line 1600 together with ps32-8 (1155), ps46-1 (1160), john11-25 (1212) | "Emmanuel Nkwoka, i will instruct thee…", "…, god is our refuge…", "…, jesus said unto her…" |
| D3 | A narrative introduction addressed to someone else gets a vocative | john11-25 (1212) is `P()` | The reader is addressed in "Jesus said unto her [Martha]" |
| D4 | Corporate exhortation is prefixed mechanically. The master requirement says this needs passage-specific judgement. | heb4-16 (1244) `P()` | "Emmanuel Nkwoka, let us therefore come boldly…" |
| D5 | Gendered pronouns are inserted for every user | e.g. ps23-1 (1151) "he shall not want", phil4-13 (1239) "strengtheneth him", ps103-3 "his diseases", heb13-5 "forsake him", 1pet5-7 "careth for him", and the declarations (1326–1336) "strengthens him", "keep him", "his house" | Wrong for women. Changes the source wording. |
| D6 | First person turned into third person in psalms and testimony | ps139-14 "⟦N⟧ will praise thee… for he is fearfully", ps23-1 | The speaker's voice changes from David or Paul to a third-person statement about the reader |
| D7 | Words deleted from the source | isa43-1 "I have called thee by thy name" → "I have called ⟦F⟧ by name" (the word "thy" is lost) | Not recoverable from the rendering |
| D8 | Covenant or collective plural narrowed to one person | rom8-37 "we are more than conquerors" → "⟦N⟧ is more than a conqueror"; rom8-1 "them which are" → "⟦N⟧, who is"; 2tim1-7 "us" → "⟦N⟧" | Collective promises become individual statements |

**Overall:** the demo proves the *concept* of eligibility, fail-safe fallback, segment highlighting and context framing. Its *rule content* repeatedly breaks the later integrity rules. It should **not** be used as a source of renderings to port.

## 5. Daily Spoken Word: schedule and adaptive relevance

| Function | Lines | What it actually does | Classification |
|---|---|---|---|
| `DW_SCHEDULED` | 1548–1553 | Round-robin over 16 categories of the 48 non-pool candidates. No category repeats on consecutive days. The cycle is **48 days**, not 365. | Functional (miniature) |
| `baseCandidate(d)` | 1629–1633 | Feb 29 → Rev 21:5; otherwise `(dayOfYear − 1) mod 48` | Functional |
| `adaptivePick(signal, d, recent)` | 1634–1654 | Excludes recent candidates (freshness); +50 category match; +40 life-situation match; −15 if `signal.lastCat` repeats; picks the highest score > 0; otherwise base fallback | Functional |
| Tie-break | 1646 (`if (s > bestScore)`) | Labelled "deterministic tie-break by candidate code". The code actually keeps the **first in array order**. That is deterministic, but it is not a sort by code. | Partial |
| Side effect | 1646 | `best.why = why` mutates the shared candidate object | Minor bug |
| `DailyState` / `todayWord()` | 1655–1671 | Remembers the last 8 codes and one log entry per date (local storage). Reads the signal from `Store.get(K.signal)`. | Partial |
| **Signal source** | `K.signal` is read at 1667 and 2510 | **Nothing ever writes `mwb.signal`.** `K.searches` (836) is declared and never used. Searches, saves and reading are **not** turned into signals. | Simulated |
| Yesterday / Today / Tomorrow calendar | `renderDaily()` 2783–2832 | Yesterday and tomorrow show the base candidate; today shows the adaptive pick | Functional |
| Adaptive simulator | 2776–2831 | Compares the scheduled base with the persona's pick for 4 hard-coded `SIM_USERS`, with reason tags | Simulated (honestly labelled "simulates signals locally", line 665) |
| Daily sheet | `openDailySheet()` 2833–2880 | Date and category; KJV/MWB toggle; context note; reception panel; Reflect prompt; Apply list; linked prayer and declaration; related verses; share, copy, save | Functional |

**Conclusion:** in normal use the home Daily Word is **always the scheduled base word**. Adaptive behaviour appears only in the simulator, because no real signal is ever produced.

## 6. "GODSAID search — Search everything"

| Part | Lines | Behaviour | Classification |
|---|---|---|---|
| Index | `SEARCH_INDEX` 1687–1697 | Built from 117 Scripture profiles, promises, blessings, prayers, declarations, situations, daily words, journeys and 66 books, each with a label, subtitle, keyword list and "haystack" | Functional |
| Scoring | `fuzzyScore()` 1674–1685, `subScore()` 1686, `searchAll()` 1699–1715 | Per term: exact label 100; prefix 88; infix 70 minus a position penalty; subsequence "fuzzy" 20–55; haystack substring 45/60 × 0.65; keyword match × 1.1. Every term must score ≥ 12; average > 20; top 40. | Functional |
| Live input | 3385 | 110 ms debounce on `input` | Functional |
| Type filters and suggestion chips | 3131–3145 | 9 types | Functional |
| Grouped results with highlighting | 3146–3179 | Grouped by type, `<mark>` highlight | Functional |
| Reference parsing ("Psalm 91", "John 3:16") | — | **None.** "Psalm 91" works only because "Psalm 91" appears in profile labels and the Psalms book label matches. Arbitrary chapter:verse is not parsed. | Partial |
| Full-Bible search | — | **None.** Only the ~117 intelligence verses are indexed, not the 11 featured chapters or the canon. | Partial |
| Concept search ("afraid" → fear) | `kw` arrays | Works where curated keywords exist | Functional (curated) |

## 7. Discover, Pray and Saved

- **Discover** (2882–2991): tabs for Promises, Blessings, Declarations, Life situations, Journeys, God's direct words, Words of Jesus, and Inspired messages. Each card opens its sheet. **Functional.**
- **Journey stepper** (`openPath()` 2458–2488): ordered steps linking situation, verse and promise. **Functional.**
- **Pray** (2993–3031): choose a situation → chain of *life situation → relevant Scripture (KJV) → prayer → declaration → supporting Scripture*. The declaration is chosen by shared refs or falls back to `dc-faith`. **Functional.**
- **Declarations** substitute `⟦F⟧` with fixed male pronouns (defect D5). **Functional, with defects.**
- **Saved** (3033–3079): typed filters and local storage. **Functional.**
- **Recent items** (`pushRecent()` 2490): stored, but not used for relevance. **Functional (stored only).**

## 8. Poster Studio and share engine (1727–2120, 3080–3128)

**Rendering pipeline.**
1. `makePayload()` builds a content struct (verse, daily, promise, blessing, prayer or declaration).
2. `computeCardLayout()` measures text on a canvas. It works down a font-size ladder (`ART_SIZES` 60→22, per-type start and floor in `ARTWORK_TYPES`) across three spacing passes, wraps rich runs (name segments in bold upper case), and wraps the reference and note.
3. `validateCardLayout()` checks five boundary rules.
4. `renderMWBArtwork()` recomputes with a compact ladder if any rule is violated.
5. `drawArtwork()` paints a gradient, a radial glow, a frame, a cross mark, brand, subtitle and version chip, Scripture, the reference with dashes, the note, and a protected footer.

**Capabilities.**

| Capability | Evidence | Status |
|---|---|---|
| A real image file is produced | `canvas.toBlob(..., "image/png")` 2069; `toDataURL` download 2079–2085 | **Functional**: PNG, **2160×2700** (logical 1080×1350 at scale 2) |
| Native share with the image | Web Share API with files, 2071–2073; falls back to download | Functional where the browser supports it |
| Copy accompanying text | `payloadPlain()` 2053–2057, `copyText()` | Functional |
| Text fitting | Ladder, passes, terminal layout, validation | Functional |
| Light/dark card themes | `CARD.light/dark` 1738–1741; follows the page theme | Functional (2 themes) |
| Formats | Only **1080×1350 portrait (4:5)** | Square and Story: **not implemented** |
| WhatsApp / Status | Generic Web Share only | Not specifically implemented |
| Attribution | Reference plus version chip ("KJV" / "KJV-MWB" / "MWB Declaration"), "Personalized rendering of KJV" note | Functional |
| Card types | Verse, Daily Word, Promise, Blessing, Prayer, Declaration (`POSTER_TYPES` 3081) | Functional. **Personal reflection and testimony cards: not implemented.** |
| Distinguishing content kinds | Brand line ("Prayer · …", "Declaration · …") and note ("A prayer assembled from Scripture") | Functional |
| Attribution defect | Prayer and blessing cards carry the version chip "KJV"/"KJV-MWB" even though the text is not KJV Scripture (2047–2048) | Minor defect |

## 9. Insights and profile (3193–3320)

- **Settings:** default rendering, font size, clear demo data. **Functional.**
- **Local stats:** most saved, most shared and Daily Word themes from `Stats` (1718–1726). Stored only on the device. **Functional.**
- **Translation chips, architecture flow and the "Room for tomorrow's AI" note.** **Static.**
- **Identity:** the demo user is always "Emmanuel Nkwoka" (line 851). There is no profile entry. **Simulated.**

## 10. Summary

| Area | Demo verdict |
|---|---|
| Canon structure, translation separation | Functional (structure); text for 11 chapters only |
| Context intelligence and speaker integrity | Functional, and among the demo's strongest ideas |
| DSPE personalisation | Functional mechanism; **rule content defective** (D1–D8) |
| Daily Word schedule | Functional (48-day miniature cycle) |
| Adaptive relevance | Algorithm functional; **live signals simulated** (never written) |
| Search everything | Functional over the curated corpus; no full-Bible search; no general reference parser |
| Discover / journeys / Pray / declarations | Functional on curated data |
| Poster Studio | **Functional image generation and export**, portrait only |
| Insights | Functional local counters |
| AI | Conceptual only, by design |
