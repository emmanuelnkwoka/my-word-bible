# MWB Fellowship & Growth Engine: Risk Register (Phase 0)

Likelihood and impact are rated L (low), M (medium) or H (high). **Blocker** means it must be closed before a real-user pilot.

| ID | Risk | L | I | Mitigation | Owner | Blocker |
|---|---|---|---|---|---|---|
| R-01 | Special-category (religious) data handled without a lawful basis or a residency decision | M | H | Legal review (L1); minimisation; encryption; privacy notice | Founder + counsel | **Yes** |
| R-02 | Crisis or self-harm disclosure in a prayer request with no response path | M | H | Safeguarding protocol (L2), crisis resources, moderator guidance | Founder | **Yes** |
| R-03 | A minor joins the adult pilot | M | H | Adult attestation at registration and acceptance; invitation-only; reportable; legal review of attestation sufficiency | Founder + counsel | **Yes** |
| R-04 | Phase I public discovery (search, public profiles, follows) is connected to the real backend, contradicting "no public discovery" | M | H | Keep Phase I directory demo-only (security plan §4); code review gate | Engineering | **Yes** |
| R-05 | Release builds signed with the debug key [FACT] | H | H | Create and secure a release keystore outside git | Founder | **Yes** |
| R-06 | Cross-pair data exposure (insecure direct object reference) | M | H | Membership-scoped policies; authorisation matrix tests | Engineering | **Yes** |
| R-07 | Reports reach no one (Phase I reports are local [FACT]) | H | H | Server report queue and a staffed moderator before pilot | Founder | **Yes** |
| R-08 | Engagement design drifts toward guilt or gamification | M | M | Copy guidelines; no missed-day push type; founder review of every string | Product | No |
| R-09 | Client clock manipulation inflates self-reported `engaged` | M | L | Time windows; `acted` server-observed; UI says "took part", not "read" | Engineering | No |
| R-10 | Partners in different timezones disagree about "today" | H | M | One fellowship timezone plus a grace window (D7); clear UI | Product | No |
| R-11 | Partners see different Daily Words (adaptive selection [FACT]) | H | M | Together uses the schedule baseline pinned by the server | Engineering | No |
| R-12 | Schedule version skew between app versions | M | L | Server pins `schedule_version`; fallback to opening by reference | Engineering | No |
| R-13 | Journal text leaks through logs, crash reports, analytics or share sheets | L | H | No analytics today [FACT]; allow-list policy; tests; journal never passed to share APIs without explicit user action | Engineering | No |
| R-14 | Local storage limits (SharedPreferences JSON) degrade with journal and outbox growth | H | M | Drift (D1); caps if not approved | Engineering | No |
| R-15 | Unapproved package additions | M | L | Each package requested through D1, D2 and D4 | Founder | No |
| R-16 | Error-shape mismatch between the client (Laravel `message`) and the sharing contract (`error.code`) [FACT] | H | L | Unified shape (API contracts §1.1) | Engineering | No |
| R-17 | Backend operations burden (patching, backups, on-call) on a small team | M | H | Managed hosting; documented runbooks; Supabase fallback if no PHP capacity | Founder | No |
| R-18 | Push credentials or a service account committed to git | L | H | Secrets in CI or the host only; `.gitignore` entries before integration | Engineering | No |
| R-19 | App Links unverified (no `assetlinks.json`) [FACT], so invitation links open in the browser | H | M | Domain files (E4) with the release key (R-05) | Founder | Pilot-quality blocker |
| R-20 | iOS untested (Windows host) [FACT] | H | M | Android-only pilot, or obtain an iOS build host (B2) | Founder | Only if iOS is in the pilot |
| R-21 | Deleting an account removes Scripture the user sent from the partner's history unexpectedly | M | L | Decide the policy (data model §3.9) and explain it in the UI | Product | No |
| R-22 | Abuse by a partner (pressure to keep a streak, monitoring) | M | M | Minimal visibility (one boolean), pause or leave without explanation, block | Product | No |
| R-23 | WhatsApp images in `docs/temp-images/` tracked publicly on GitHub [FACT]; content unknown | ? | ? | Founder to confirm they contain no private data, or remove them from history | Founder | No |
| R-24 | Regressions in the existing app (r3, sharing, reader) from Fellowship hooks | M | H | Additive hooks only; full suite (baseline 395) in every phase; device check | Engineering | No |
| R-25 | Scope creep into Layer C before the pilot learns anything | M | M | Roadmap gate; schema extensible only | Founder | No |
