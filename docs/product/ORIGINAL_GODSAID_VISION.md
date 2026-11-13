# GODSAID → MY WORD BIBLE: Original Vision (Reconstruction)

Audit date: 11 November 2026. Read-only audit; no application code was changed.

## How to read this document

Every statement is tagged with where it comes from:

| Tag | Meaning |
|---|---|
| **[RHC]** | *Recovered historical context.* Supplied by the founder in the audit brief of 11 Nov 2026. I have **not** seen the original ChatGPT conversations, the GODSAID database, or the historical phase reports. These claims are recorded as given, not independently verified. |
| **[DEMO]** | Inspected in `MY_WORD_BIBLE_MWB_DEMO (1).html` (3,395 lines), with line numbers. |
| **[FLUTTER]** | Inspected in the current Flutter project at `C:\xpatsoft\my-word-bible`. |
| **[LATER]** | A later product refinement that changes an earlier assumption (from the brief and from instructions given during this project's Phase 2 work). |
| **[OPEN]** | Not decided by any evidence I have. |

I did not search any historical conversation archive. No archive was available.

---

## 1. Original mission

- **[RHC]** GODSAID was a *Scripture Intelligence Platform*. It was positioned as "The World's First Scripture Intelligence Platform", with the long-term aim of becoming "the world's most trusted" one.
- **[RHC]** The goal was not to display verses. It was to build an **authoritative, structured, interconnected representation of Scripture**. Many experiences could then run on it: reading, search, discovery, relationships, classification, personalisation, prayer, declarations, recommendations, APIs, and AI assistance later.
- **[DEMO]** The demo's own header says the same thing. It calls itself "A miniature of the GODSAID Phase 1–7 architecture" and maps each phase to a data structure or function (lines 776–792). Its "Underneath: GODSAID" panel draws the stack as *Canonical Scripture Identity → Translation → Scripture Intelligence → MWB Personalization Engine → Personal Reception* (lines ~3256–3270).

## 2. The founding architectural principle

**[RHC]** *Canonical Scripture identity and translation-specific text are different things.*

- The canonical spine (Bible → Testament → Book → Chapter → Canonical Verse) is stable, independent of any translation, and immutable.
- Translation text, language, licence and text history attach to canonical verse identity.
- Adding a translation must never require rebuilding the spine.
- No intelligence, personalisation or presentation feature may modify the canonical repository.

**[DEMO]** The demo holds the canon as structure only: `CANON` lists 66 books with per-chapter verse counts (line 856). Translations are kept apart from it in `TRANSLATIONS` (line 863). Only 11 KJV chapters carry full text (`FEATURED`, line 876). Every other chapter shows a "served by the production corpus" notice (lines ~2688–2705).

**[FLUTTER]** The principle survives in the current app:
- `BibleCanon` (`lib/data/models/bible_canon.dart`) is separate from translation text.
- Each translation is a separate asset: `assets/bible/kjv.json` (66 books, 1,189 chapters, 31,102 verses, checked 11 Nov 2026) and `assets/bible/web.json`.
- MWB editions never store altered text; they render on top of the source (`EditEngine`, `MwbRenderer`).

## 3. Historical backend phases ([RHC] unless marked)

These phases describe the **historical GODSAID backend**. They are a different track from the current Flutter frontend phases ("Foundation V1", "Phase 2 Stage A/B", "KJV/WEB activation"), and the two must not be confused.

| Phase | What it established [RHC] | Historical quantities [RHC] | Demo miniature [DEMO] |
|---|---|---|---|
| 1 Canonical repository | Canon, translations, languages, licensing, text versions | 66 books, 1,189 chapters, 31,102 canonical verses, 93,303 translated verse records, fingerprint `31102:700317203083` | `CANON` (856), `TRANSLATIONS` (863), 11 featured chapters (876) |
| 2 Scripture intelligence | Speaker, author, original audience, historical and literary context, inspiration class, personalisation eligibility and strategy, editorial confidence, review status | n/a | `INTEL` profiles with `spk`, `auth`, `aud`, `insp`, `mwb`, `rev` (1120–1255): **117 profiles** |
| 3 Intelligence corpus | Curated promises, commands, blessings, identity, prayers, declarations, taxonomy | 11 divine words, 16 words of Jesus, 30 promises, 14 situations, 10 identity themes, 4 blessings, 9 commands, 7 worship themes, 8 prayers, 5 declarations, 100 taxonomy terms, 77 links, 8 relationships, 54 editorial + 54 context profiles, 151 verses | 30 promises (+1 alias, 1480–1482), 12 blessings (1292), 35 situations (1373) |
| 4 Discovery | Curated journeys and relationships | 11 journeys, 63 steps, 22 relationships | `PATHS`: 11 journeys, **55** steps (1412); `RELS`: **21** pairs (1557) |
| 5 Prayer and declaration engine | Situation → Scripture → prayer → declaration → supporting Scripture | 15 prayers, 10 declarations, 45 + 23 refs | `PRAYERS` 15 (1307), `DECLARATIONS` 10 (1326) |
| 6 DSPE | Context-aware personalisation "like a careful biblical editor" | n/a | `mwbPersonalize()` (1589–1618) |
| 7A Daily Word corpus | Candidate corpus kept separate from the annual schedule | 393 candidates, 365 assignments, leap-day reserve (Rev 21:5) | `DAILY_WORDS`: **54** candidates (48 scheduled + 6 pool) + leap candidate (1487–1554) |
| 7B Adaptive relevance | Signals, scoring, freshness, diversity, deterministic fallback | 20/20 tests, fingerprint preserved | `adaptivePick()` (1634–1654) |
| 8 Presentation/assembly (MWB) | `ScriptureTextRepository`, `MwbAssembler`, `MwbReadingUnit`; card and share payloads | Read-only; no production UI | Not in demo |

Notes on the evidence:
- **The demo is a miniature, not the historical corpus.** Its counts differ from the historical ones. Some are smaller (54 vs 393 Daily Word candidates, 55 vs 63 journey steps, 21 vs 22 relationships). Some are larger (117 context profiles vs 54, 35 life situations vs 14, 12 blessings vs 4). No demo count proves or disproves a historical count.
- **The 7A/7B discrepancy.** **[RHC]** The Phase 7A report calls the adaptive engine future work. Later context records 7B as completed. I could not inspect any 7B artefact, so its exact implementation details are **unverifiable in this workspace**. The demo has a working miniature of the scoring rules (see `MWB_ORIGINAL_DEMO_AUDIT.md` §5). Neither proves the Flutter app implements it, and it does not (see `FLUTTER_IMPLEMENTATION_AUDIT.md` §6).
- **The canonical fingerprint** `31102:700317203083` cannot be reproduced: the hashing method is not in the workspace.

## 4. Why GODSAID became MY WORD BIBLE

- **[RHC]** The product evolved into **MY WORD BIBLE: Personalized Scripture Experience**. Its identity is *receiving God's inspired Word personally while preserving its original meaning*. The original tagline was "God's Word. Personally Received."
- **[DEMO]** The demo is already branded MWB. It describes itself as "a Personalized Scripture Experience built on the GODSAID Scripture Intelligence Platform" (line 648). Its headline idea is "One Scripture. Two faithful renderings. KJV stays untouched — KJV-MWB receives it personally" (line 639).
- **My interpretation (labelled as such):** GODSAID is the *engine* and MWB is the *consumer experience*. The rename shifts the public face from infrastructure ("intelligence platform") to what a believer feels ("my word, personally received"). The GODSAID intelligence stays underneath as the differentiator.

## 5. Permanent decisions (still in force)

1. **Canonical text is never rewritten.** [RHC, DEMO line 648, FLUTTER `EditEngine` exact recovery]
2. **Translation identity is kept separate from canonical identity.** [RHC, DEMO, FLUTTER]
3. **Context belongs to canonical identity, not to a translation.** Speaker, author and original audience stay explicit. God's speech, Jesus' words and human authors are never merged. [RHC; DEMO `voiceOf()` 1619–1623 and the "God's direct words / Words of Jesus / Inspired messages" tabs, line 2882]
4. **Personalisation follows context, not emotional appeal.** It fails safe to the untouched original. [RHC; DEMO 1592–1596; FLUTTER `MwbRenderer` `PublicationPolicy.approvedOnly`]
5. **Editorial curation.** "Craft over quantity": omit unsupported content rather than fabricate it. [RHC]
6. **Prayers and declarations are never presented as Scripture** and are never attributed to God. [RHC; DEMO Pray view text, line 686]
7. **The Daily Word is a deterministic schedule with an always-valid fallback.** Feb 29 uses Rev 21:5. [RHC; DEMO 1629–1633]
8. **AI may come later but must never be the source of biblical truth.** [RHC; DEMO "Room for tomorrow's AI… Nothing in this demo simulates AI", line ~3272]
9. **Sharing artwork must keep Scripture exactly as translated.** [RHC; DEMO line 704]

## 6. Refined decisions ([LATER])

| Earlier assumption | Later refinement | Evidence |
|---|---|---|
| KJV-MWB is a rendering toggle beneath KJV (demo `segControl`, lines 2148–2157) | **MWB is a selectable Bible edition per translation** (KJV/KJV-MWB, NKJV/NKJV-MWB…), each derived from its own source. Never one generic paraphrase. | [LATER, 17 Aug 2026]; FLUTTER `version_catalogue.dart` |
| Demo strategy "recipient substitution": replace pronouns with the name, adding *he/his/him* (e.g. Eph 2:10, Ps 23:1, Phil 4:13; lines 1151, 1234, 1239) | Controlled operations only: `insertDirectAddress`, `appendPersonalName`, `insertNameAfterExistingAddress`, `punctuationAdjustment`, `approvedMinimalGrammaticalAdjustment`. No automatic gendered or relational replacement. No turning collective promises into individual guarantees. | [LATER]; FLUTTER `mwb_rule.dart` |
| Demo user hard-coded as "Emmanuel Nkwoka" with fixed male pronouns (line 851; declarations 1326–1336) | Name preference: full (default), first, preferred, or none. Missing profile data must not be invented. | [LATER]; FLUTTER `NamePreference` in `user_profile.dart` lines 17–27 |
| Demo shows a curated rendering as soon as its strategy is set | Theological supervision by **Pastor Obi Ogbo**. Automated validation ≠ approval. Normal mode shows approved rules only; reviewer preview is clearly labelled. | [LATER]; FLUTTER `PublicationPolicy`, `mwb_review_widgets.dart` |
| Personalisation should be as restrictive as possible | Small grammatical and punctuation adjustments are acceptable when needed for natural, faithful address. Skip, flag and continue. | [LATER] |

## 7. Ideas explicitly deferred ([RHC])

- Production APIs, accounts and email verification, notifications, payments, community, and creator rewards.
- AI-assisted Scripture intelligence: question → intent → retrieval → context → cited answer.
- The Poster Designer as a real user-facing feature. The Phase 8 report delivered only payloads and says Poster Designer must *eventually* become real.
- Media (audio, video, teachings) linked to Scripture and intelligence by stable identifiers, with attribution, rights, moderation and takedown.
- The Laravel backend, to be designed **after** the Flutter experience is validated (frontend-first).

## 8. Ideas superseded

- **The single toggle between "KJV" and "KJV-MWB"** (demo `getVersion()/setVersion()`, lines 2124–2125). Superseded by per-translation selectable editions.
- **Mechanical vocative prepend.** The demo's `pre` strategy puts the name before *any* eligible verse and lower-cases its first letter (line 1600). The founder's master requirements forbid mechanical prefixing, and the later operation list requires passage-specific anchoring.
- **Substitutions that change gender, person or number** (see §6). Superseded by the later rules.
- **The demo's translation line-up** (ASV, WEB, NLT, NIV, ESV; line 863). The Flutter catalogue now lists KJV, WEB, NKJV, NIV, NLT and their MWB pairs. ASV and ESV are not in the current catalogue. **[OPEN]** No evidence says whether ASV and ESV were deliberately dropped.

## 9. Unresolved questions ([OPEN])

1. The exact Phase 7B algorithm and corpus (393 candidates). Can the historical artefacts be exported into this workspace?
2. Whether the historical 93,303-record corpus (three translations) should seed the Flutter app, and in what format.
3. Whether the short label "WEB-MWB" is acceptable under eBible.org's trademark condition. The full name already avoids calling the text "World English Bible".
4. Whether the demo's 37 recipient substitutions should be re-proposed as reviewable rules under the new operations, or retired. Many cannot be expressed without changing person, gender or number.
5. The final primary navigation (see `MWB_FRONTEND_PRODUCT_ROADMAP.md`).
6. Which signals adaptive Daily Word relevance may use, and the privacy and consent model for them.
7. How the Daily Word should behave in an MWB edition when its verse has no approved rule. Today the source text is shown.
