# MWB Reference Design Analysis (Stage D.1)

Source: the 17 founder screenshots in `docs/temp-images/` (WhatsApp images 17.05.22 and 17.05.23, all inspected). They come from an iOS app called "Personal Bible" and show: welcome, a 1/4 onboarding step (three variants with different name forms), a share preview, five feature-tour modals, Home, Settings, the Bible reader with a verse menu, and five Declarations screens.

They are the visual benchmark. Brand names, logos and copy are **not** reproduced: MY WORD BIBLE keeps its own name and mark.

## 1. Overall visual identity
Warm, quiet and devotional. Ivory paper, champagne and antique-gold accents, near-black espresso ink, and white cards that float on soft shadows. The Scripture text is always the largest and most central element, and the decoration is minimal.

## 2. Colour palette and relationships
| Role | Reference (sampled) | MWB token (Classic Gold, light) |
|---|---|---|
| Page background | warm ivory ≈ #F9F2E6 | `background` #F9F2E7 |
| Card | pure white | `surfaceElevated` #FFFFFF |
| Tinted card / quote panel | champagne ≈ #F4EBDA | `selected` #F5EAD5 |
| Primary gold (gradient start) | ≈ #C8952F | `accent`/`primary` blend |
| Primary gold (gradient end) | ≈ #A5651D | `primaryStrong` #A3681F |
| Ink | espresso ≈ #2A170D | `textPrimary` #28170D |
| Secondary text | warm grey ≈ #7D6F63 | `textSecondary` #7E7065 |
| Name in Scripture | gold, semibold | `nameInk` (derived) |

Gold is the only accent. It is used for actions, the name, references and the active navigation item; everything else stays neutral.

## 3. Typography
- **Headings** ("Personal Bible", "Good evening, Emmanul.", "Chapter 3"): a sturdy transitional serif, semibold, tight tracking. **MWB:** Lora SemiBold (bundled, OFL), with display at 32 sp and −0.6 tracking. Cormorant Garamond was too fine for this role and is no longer used for headings.
- **Scripture:** a book serif, regular weight, generous leading (≈1.55). **MWB:** Lora Regular, 19–22 sp, line height 1.55–1.6.
- **Interface text:** a neutral grotesque (SF Pro in the references). **MWB:** Inter.
- **Overlines:** small caps with wide letter-spacing, in gold ("COLOSSIANS", "IDENTITY").
- **Reference line:** "— Isaiah 43:1" in italic serif gold, with the translation below in small spaced capitals.

## 4. Scripture presentation and the name
The name sits inside the sentence in **gold, semibold**, never in a separate pill. Verse cards centre the text with curly quotation marks. In the reader, a personalised verse has a gold left rule, a faint champagne wash, a small marker and the caption "✦ speaks to you by name".

## 5. Cards, borders and radii
White cards with radius ≈ 22–26 pt, a hairline warm border and a very soft, warm, low shadow (≈ 24 blur, 8 offset, 6–8 % opacity). Quote panels are champagne with a faint gold border. **MWB:** `MwbCard` now defaults to radius 22 with `softShadow`; the Daily Word hero uses radius 26 with a 4 pt gold gradient strip along the top edge, matching the Home reference.

## 6. Spacing and layout
16–24 pt page gutters, 20–24 pt inner card padding and large vertical rhythm. On Home the greeting sits directly above the verse card. MWB uses its existing 4-pt scale, with a 20 pt gutter.

## 7. Buttons
- **Primary:** a full-width pill, ≈ 56 pt tall, with a horizontal gold gradient, white semibold label and arrow or share icon, plus a soft gold halo. **MWB:** `MwbPrimaryButton` is now a stadium shape with `brandGradient` and a tinted gold shadow.
- **Secondary:** a pill on a champagne fill with a faint gold border and gold label ("Share this"). **MWB:** `MwbSecondaryButton` has been restyled to match.
- **Tertiary:** icon above a label (Save · Explain · New verse).

## 8. Gold accent treatment
The gradient runs left to right from champagne gold to antique bronze. It appears only on primary actions, brand medallions and accent strips. There is no gold text on gold.

## 9. Icons
Solid, rounded glyphs (SF Symbols filled) with even optical weight, around 24 pt in the navigation. **MWB:** the Material Rounded *filled* family is used throughout the navigation (home, menu_book, auto_awesome, bookmarks, person). Within the nav, outlined and filled styles are no longer mixed.

## 10. Bottom navigation
A floating pill, inset ≈ 14 pt from the screen edges, white at ~98 %, with a hairline border and a soft shadow. It holds five equal items with icons above labels. The active item sits on a champagne capsule with gold-brown icon and label; inactive items are ink-coloured. **MWB:** this is implemented exactly, but the bar sits in its own layout slot so it never covers content (see the refinement report). Destinations are kept as the existing app's five (Home, Bible, Discover, Library, Profile). The reference's "Explore" icon (sparkle) is used for Discover.

## 11. Onboarding and progress
A round back button, "1 / 4" with a thin gold progress bar and percentage, a centred serif headline, then a champagne quote card showing the reader's own name in Scripture, with Continue (primary) and Share this (secondary). The feature tour uses white modals with a gold icon disc, a serif title and pager dots. **MWB:** the existing four-step onboarding keeps its progress bar. Step 1 now shows a live "This is what My Word Bible does" card that places the typed name in Proverbs 3:1. It is labelled as an example and explains that names appear only in approved passages.

**Deliberate difference:** the reference uses Isaiah 43:1 with a substituted name. That is divine speech to Israel and a known regression case, so MWB does not show it as personalised Scripture.

## 12. Home
Brand row (mark and name, avatar circle on the right), then "Good evening, **Name**." in large serif with the name in gold, then the verse card. The card has a category chip and date, centred Scripture with the name in gold, a gold rule, the italic reference, the translation, a full-width "Share this verse" pill and three quiet actions. Secondary cards come below. **MWB:** reproduced (see `DailyWordHero`). A promotional banner ("7 days of Pro") is not applicable and was not added.

## 13. Bible reader
Back-to-book link, a centred brand mark, a tinted version pill ("KJV ⌄"), text-size and settings icons. Then the centred chapter heading (gold small-caps book name above "Chapter 3"), a collapsible "Chapter Summary" card, and verses with small gold numbers. The personalised verse is highlighted as in §4. Long-press opens a menu (Explain with AI, Save to Library, Share, Copy Verse). **MWB:** centred heading, gold verse numbers, personalised highlight with the "Speaks to you by name" caption, and a selection bar with **Share first**. "Explain with AI" is intentionally **not** added (no AI-generated Scripture or commentary).

## 14. Daily Word presentation
This is the Home verse card, reused full-screen. **MWB:** the same `DailyWordHero` component is used on Home and in the Daily Word screen, so the two can never drift apart.

## 15. Personalised declarations
Each declaration is a white card with a category emoji and gold small-caps label, a speaker button, and a large serif sentence with the name in gold. Several reference declarations (Psalm 91:7 "near him", 2 Corinthians 5:17, Ephesians 2:10) change person, number or gender, which are exactly the defects MWB forbids. MWB has no Declarations screen yet (Stage G); this stage does not add one.

## 16. Scripture sharing
A full-bleed ivory card with the brand mark, the verse in large serif with the name in gold, the italic gold reference and a small brand line. **MWB:** this is the visual basis of `ScriptureImageComposer` (§ sharing specification). The reference truncates the verse ("I have called…"); **MWB never truncates**, and paginates instead.

## 17. Modals and bottom sheets
White, radius ≈ 24, with generous padding, centred content and pill buttons. MWB sheets keep their drag handle and radius 22, and use the pill buttons above.

## 18. Light and dark
The references are light only. The MWB dark palette (espresso #13100C, warm gold #D6AA5C, ivory ink) keeps the same relationships; the share images follow the active brightness.

## 19. Status bar, system navigation and safe areas
The references use a transparent status bar over ivory and a floating bar above the home indicator. MWB keeps a transparent status bar with dark icons on light, and the navigation bar adds the system bottom inset (gesture bar or three-button bar) below the pill.

## 20. Interaction and motion
Soft scale and fade on selection and quick, quiet transitions. MWB uses 150–360 ms ease-out-cubic, a scale-in on the active nav icon, and haptic selection clicks.
