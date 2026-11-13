# MWB UI Refinement Report (Stage D.1)

Design source: `docs/ui/MWB_REFERENCE_DESIGN_ANALYSIS.md` (all 17 reference images). Evidence: `docs/ui/MWB_VISUAL_ACCEPTANCE_REPORT.md`.

## 1. Design system (one place, every screen)
| Token / component | Change |
|---|---|
| Classic Gold palette | Ivory background #F9F2E7, white cards, champagne `selected` #F5EAD5, gold #B98330 → antique #A3681F, espresso ink #28170D. Dark mode is retuned to match. |
| `brandGradient`, `softShadow`, `nameInk` | New palette getters: the gold gradient, a warm low shadow, and the gold used for the reader's name. |
| Typography | Headings move from Cormorant Garamond to **Lora SemiBold** (display 32, page 26, section 19); Scripture uses Lora 19 at line height 1.6; the interface keeps Inter. |
| `MwbPrimaryButton` | Pill, 56 pt, gradient, gold halo. |
| `MwbSecondaryButton` | Pill on champagne with a gold label and a faint gold border. |
| `MwbCard` | Radius 22 and a soft shadow by default (`elevated: false` for nested cards). |
| `MwbBottomNav` | Floating pill; see §3. |
| Sheets | Open on the root navigator, so they always sit above the navigation. |
| New shared components | `DailyWordHero`, `PresentedScriptureText` (name in gold), `NamedTitle`, `PreviewBadge`, `MwbBrandMark`. |

## 2. Screens refined
| Screen | What changed |
|---|---|
| **Home** | Brand row (medallion, "My Word Bible", search, initial avatar); "Good evening, **Name**." with the name in gold; the **Daily Word hero** is the first card, with the Scripture immediately visible; Continue reading next; secondary content below. The "Chosen from your activity" line is removed. |
| **Daily Word** | Same hero (Mode A/B/C title, category chip and date, centred Scripture, gold rule, italic reference, translation, Share); Save / Favourite / Read; "About this passage", "Read it in context", "Related Scripture", "Go deeper". Removed: "Why you're seeing this", the selection-reason list, "Editorial context — not Scripture text" and the schedule footer. |
| **History** | Titles follow the presentation mode; the "from your activity" suffix is removed. Stored records are not rewritten. |
| **Bible reader** | Centred gold book overline and "Chapter N" heading; personalised verses get a gold left rule, a champagne wash and "✦ Speaks to you by name" (or the Mode B title); the edition switch icon reads "Read the personalised KJV-MWB" / "Read the original KJV"; **Share chapter** in the app bar; bookmark and reading settings move into ⋯ to keep the title readable at 360 dp; the selection bar leads with **Share**. |
| **Share** | New composer and sheet (sharing specification). The "Scripture card" title and the "exactly as written" caption are gone. |
| **Onboarding** | Step 1 shows a live "This is what My Word Bible does" card, with the typed name in gold inside Proverbs 3:1. It is labelled as an example and says names appear only where approved. It makes no promise that every verse is personalised. |
| **Profile** | New "Theological review" group (reviewer builds): Personalisation review, plus the review-preview switch. Privacy controls stay in "Daily Word & privacy". |
| **Review Centre** | New: coverage tiles, edition switch, status filters, 66 books → chapters → verses → proposal detail with decision actions. |
| **Library** | Share action on saved verses. |

## 3. Bottom navigation
- A floating pill inset 14 pt from the edges, white at 98 %, with a hairline border and soft shadow. It is 66 pt tall with five equal items.
- **One icon family:** Material Rounded *filled* (home, menu_book, auto_awesome, bookmarks, person), all at 24 pt.
- **Active state:** a champagne capsule behind icon and label, gold-brown colour, label weight 700, and a scale-in on change. Inactive items are ink-coloured.
- **Destinations unchanged:** Home, Bible, Discover, Library, Profile (existing routes and per-tab state). The reference's sparkle icon is used for Discover. "Declarations" was not added as a tab: no Declarations screen exists (it is Stage G) and the brief says not to start new features.
- **Safe areas:** the bar occupies its own layout slot (Scaffold `bottomNavigationBar`) and adds the system bottom inset below the pill. Content scrolls above it and is never hidden. Verified on the phone with **three-button navigation** (`navigation_mode=0`).

## 4. Light and dark
Both palettes were captured on the phone. Share images follow the active brightness (ivory or espresso), and the preview watermark switches to a lighter red on dark.

## 5. Screen sizes
Widget tests render Home, Bible, Discover, Library and Profile at **320×568** and **820×1180** without overflow. Two overflows found during this stage were fixed: the share-format chips (now wrapping) and the Daily Word date (now flexible).

## 6. Not refined in this stage
- **Discover, Library and Settings layouts** inherit the new tokens (cards, buttons, nav, type) but were not recomposed.
- **Declarations, Pray and Explain** were not added (no AI explanations; Stage G for declarations).
- **Splash screen and the 5-step feature tour modal** from the references were not built. The existing 4-step onboarding was refined instead.
