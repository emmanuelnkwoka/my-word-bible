# MWB Frontend Product Roadmap (Recommendation)

- **Date:** 11 November 2026
- **Status:** proposal for the founder's decision. No stage here has started, and Stage C is **not** begun by this document.

## 1. Navigation: comparison and recommendation

| Destination | Demo | Flutter now | Assessment |
|---|---|---|---|
| Home | Tab | Tab | Keep. Make the Daily Word its hero. |
| Bible | Tab | Tab | Keep. |
| Daily Word | Drawer + home link | None (home cards only) | **Central experience.** Needs its own page reachable from Home. |
| Discover | Tab (intelligence) | Tab (media/topics) | Keep the tab, but rebuild it around intelligence: situations, promises, journeys, voices. |
| Pray | Tab | None | Core GODSAID differentiator; must be reachable in one tap. |
| Saved | Tab | "Library" tab | Same idea; keep "Library" (it already holds notes, highlights and collections). |
| Poster Studio | Drawer | None | Should be entered from content ("Create card") plus a visible entry point. |
| Search | Drawer | Route from screens | Must be visible on every primary screen. |
| Insights | Drawer | None | Low priority; fold into Profile. |
| Profile | Drawer (Insights) | Tab | Keep, but it can leave the tab bar. |

**Recommended five tabs: Home · Bible · Discover · Pray · Library.**

- **Profile** moves to an avatar button in the Home header. Settings live there.
- **Search** is a persistent search field or icon in the header of Home, Bible, Discover and Pray, opening the unified search.
- **Daily Word** is the hero card on Home, which opens a full Daily Word page (yesterday / today / tomorrow, reflect, pray, share).
- **Poster Studio** opens from every Scripture, Daily Word, promise, prayer and declaration ("Create card"), and is also listed in Library ("My cards").

Rationale: this keeps the demo's proven five-tab spine (Home, Bible, Discover, Pray, Saved), puts the prayer engine one tap away, and avoids a drawer hiding the most important features. It does not mean redesigning existing screens; it is a re-mapping of destinations. Implementation needs the founder's approval.

## 2. Preserve, correct, build, postpone

### Preserve (do not change)

- The canonical/translation separation and bundled offline Bible (KJV, WEB).
- The MWB edition architecture: catalogue, licence gating, approved-only publication, reviewer preview labelling, exact recovery, independent per-translation rulesets, and review queues.
- Name preferences (full, first, preferred, none); never inventing profile data; gender never changing Scripture.
- The library (bookmarks, highlights, notes, collections, history), the seven themes in light and dark, and onboarding.
- The honest disclosures for sample audio and simulated video.

### Correct (small, targeted, each needing authorisation)

1. **Validator gaps** shown by Eph 2:10 (person/number, agreement, residual pronouns, context required to pass) plus permanent regression fixtures (`MWB_INTELLIGENCE_ARCHITECTURE.md` §7).
2. **Onboarding copy** that promises daily Scripture shaped by interests (`onboarding_steps.dart` 152). Either implement it (Stage D) or change the wording.
3. **Search ranking**: canonical-order results are not acceptable for "Google-like" search (Stage E).
4. **MWB in daily and home cards**: show the active edition's approved rendering when one exists.
5. **Demo file hygiene**: the demo HTML contains a third-party analytics beacon (line 3395) and defective renderings. Mark it as a reference artefact only.

### Build next: the smallest sequence with the greatest differentiation

Each stage is independently shippable and testable offline. None needs a backend or AI.

| Stage | Name | Delivers | Why this order |
|---|---|---|---|
| **C** | Scripture Intelligence corpus v1 | `assets/intel/*` (contexts, situations, promises, prayers, declarations, blessings, relationships, journeys), seeded from the demo data, re-reviewed, and with gendered declarations rewritten neutrally; `IntelligenceRepository`; curation tests | Everything else (Daily Word, Search everything, Pray, Discover, cards) depends on it |
| **D** | Daily Spoken Word engine | Candidate corpus + 365-day schedule + leap policy; Daily Word page with yesterday/today/tomorrow; local signals; deterministic adaptive selector with reason tags; Reflect / Pray / Share | The single most "alive" feature; the founder's central experience |
| **E** | Instant search v2 | Inverted index; ranking; phrases; prefix autocomplete; tolerance; book-only references; context lines; intelligence results ("fear" → situation, promises, prayer, journey) | Turns search into the GODSAID differentiator |
| **F** | Poster Studio | Flutter card engine (port the demo's layout ladder and boundary validation), Square/Portrait/Story, light/dark/theme styles, PNG export, save to gallery, native share (incl. WhatsApp), copy text, attribution, and distinct styling for Scripture vs prayer vs declaration vs reflection | Growth loop; depends on C/D content |
| **G** | Pray and Discover rebuild + navigation re-map | Pray tab (situation → Scripture → prayer → declaration → supporting Scripture); Discover by situations, journeys and voices; header search; Profile via avatar | Surfaces C in the primary UI |
| **H** | Personalisation review operations | Reviewer workflow for recording real approvals (identity, date, rule version), ruleset versioning, expanding contexts and rules beyond Proverbs | The only path to approved MWB text; needs Pastor Obi Ogbo's actual review |

Possible reorderings, for the founder to choose:
- **F before E** if sharing-led growth matters more than search depth.
- **H in parallel with C–G**: theological review is people-paced and should not block engineering. The engine already skips, flags and continues.

### Postpone deliberately

- Backend (Laravel), accounts, email verification, sync. These come after the frontend is validated, per the frontend-first plan.
- Real audio/video hosting, creator programme, uploads to a server, moderation, rewards and community.
- Licensed translations (NKJV/NIV/NLT) and their MWB editions, until publisher permission exists.
- AI assistance of any kind.
- Push notifications beyond local daily reminders.
- Desktop/web targets.

## 3. Acceptance principles for every stage

- `flutter analyze` clean, and `flutter test` green with new tests. Existing tests are never weakened.
- Runtime verification on a device, with screenshots, before claiming anything works.
- No pending rule ever shown as approved Scripture; no approval recorded without the real reviewer.
- Scripture, editorial text, prayers, declarations and system-selected Daily Words are always visually distinguishable.
- Offline first: each feature works in airplane mode unless it is explicitly media or community.

## 4. Decisions needed from the founder

1. Approve the navigation re-map (or keep the current tabs).
2. Approve the stage order C → H (or swap E and F).
3. Can the historical GODSAID exports (Phase 3–7 corpus, 393 Daily Word candidates) be provided? If not, Stage C seeds from the demo and re-curates.
4. The signal list and privacy wording for adaptive Daily Word.
5. Whether the "WEB-MWB" short label is acceptable.
6. Which demo renderings, if any, should be re-proposed as reviewable rules. The recommendation is to propose none of the substitution forms.
