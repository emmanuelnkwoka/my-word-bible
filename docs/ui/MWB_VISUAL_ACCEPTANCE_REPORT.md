# MWB Visual Acceptance Report (Stage D.1)

**Device:** Xiaomi M2101K7BG (`JFUKI7WC4HHYSWJV`), Android/MIUI, 1080×2400, **three-button navigation**. Debug APK built with `--dart-define=MWB_REVIEW_MODE=true`.
**Date:** 12 Nov 2026. **Screenshots:** `docs/ui/screenshots/d1/` (real device captures).

> **Capture note:** every screenshot has a uniform grey veil over the whole screen, **including the system status bar**. No Android accessibility colour filter was active (inversion and daltonizer were off). The veil comes from the phone (a MIUI overlay; an "Accessibility menu" window is present), not from the app. Hues and layout are accurate; brightness is reduced.

## 1. References inspected
All 17 images in `docs/temp-images/` (see the design analysis).

## 2. Screens captured on the phone
| # | File | Screen | Reference compared |
|---|---|---|---|
| 1 | `01_home.png` | Home, dark Royal Plum (your saved theme), before the preview fix (Mode C) | Home 17.05.23 |
| 2 | `04_home_light.png` | Home, Classic Gold light, **Mode B preview** | Home 17.05.23 |
| 3 | `28_home_dark.png` | Home, Classic Gold dark | — |
| 4 | `10_dailyword.png` | Daily Word screen | Home verse card |
| 5 | `11_share_sheet.png`, `25_offline_share.png` | Share sheet, single verse (the second is offline, after the spacing fix) | Share preview 17.05.22 (3) |
| 6 | `12_native_share.png` | Android share sheet, 1 PNG | — |
| 7 | `13_reader.png`, `14_selection.png` | Reader with proposal cards; range selection with Share first | Reader 17.05.23 (4) |
| 8 | `15_share_range.png` | Range share (Romans 15:13–14) | — |
| 9 | `16_share_chapter.png` → `26_chapter_pages.png` | Chapter share before (4 dense pages) and after (7 airy pages) | — |
| 10 | `27_native_share_7.png` | Android share sheet, "7 files", in airplane mode | — |
| 11 | `09_bible.png` | Bible tab with the floating nav | Nav 17.05.23 |
| 12 | `17_profile.png` | Profile with the Theological review group | Settings 17.05.23 (3) |
| 13 | `18_review_centre.png` | Review Centre coverage | — |
| 14 | `20_review_chapter.png`, `21_proposal.png`, `22_proposal_more.png` | 3 John 1 verses; proposal detail | — |
| 15 | `23_approve_requires_name.png` | Approve asks for the reviewer's own name | — |
| 16 | `24_offline_home.png` | Cold start in airplane mode | — |
| 17 | `29_share_dark.png` | Share sheet in dark mode | — |

## 3. Reference-to-implementation comparison
| Aspect | Reference | Implementation | Assessment |
|---|---|---|---|
| Greeting | "Good evening, **Emmanul**." in large serif, name in gold | Same composition with Lora SemiBold and the gold name (`04`) | Matches |
| Verse card | Category chip, date, centred serif text with the name in gold, rule, italic reference, version, gradient Share pill, 3 quiet actions | Same, plus a gold top strip and Mode A/B/C title (`04`, `10`) | Matches; adds the title |
| Name visibility | Gold inside the text | Gold in the Mode B title today (no approved Mode A yet); Mode A sets the name in gold inside the text (`PresentedScriptureText`) | Mode A on the device requires an approved rule — see §5 |
| Floating nav | Pill, 5 solid icons, champagne active capsule | Same (`09`, `04`) | Matches |
| Reader heading | Centred gold book name over "Chapter 3" | Same (centred heading in code; the device capture scrolled to the focus verse) | Matches |
| Personalised verse | Gold left rule, wash, "speaks to you by name" | Implemented for approved verses; unapproved proposals show as "PROPOSED — NOT APPROVED" cards beside the verse (`13`) | Intentional difference: integrity |
| Verse menu | Floating menu (Explain with AI, Save, Share, Copy) | Bottom action bar: Share, Highlight, Bookmark, Note, Save, Copy (`14`) | Different form, same function; no AI |
| Share image | Ivory card, medallion, serif text, italic gold reference; **truncated text** | Same visual language; **never truncated**, paginated with "1 / 7" (`25`, `26`) | Better |
| Buttons | Gradient pill with halo; champagne secondary pill | Same | Matches |
| Onboarding | Name in Isaiah 43:1 quote card | Name in Proverbs 3:1 example card, labelled | Intentional difference: Isaiah 43:1 is a regression case |

## 4. Functional checks on the phone
| Check | Result |
|---|---|
| Fresh build and install | Pass. The first APK lacked the catalogue assets; this was found on the device, fixed in `pubspec.yaml`, rebuilt and reinstalled. |
| Name and preferences | Pass. Greeting and title use the stored name ("Emmanuel Nkwoka" is stored in the first-name field). |
| Daily Word modes | **Mode C** shown when the preview is off or before the fix (`01`). **Mode B preview** shown after the fix (`04`). Mode A was **not** observed on the phone (today's word is Mode B; no Mode A word was due). |
| Original vs personalised | Pass. The reader on KJV-MWB offers "Read the original KJV". Proposals are never shown in place of the verse. |
| Five navigation destinations | Pass (Home, Bible, Profile captured; Discover and Library tapped). |
| Book and chapter navigation | Pass (Bible tab, reader at Romans 15). |
| Verse selection | Pass ("Romans 15:13–14"). |
| Single, range and chapter sharing | Pass (`11`, `15`, `26`). |
| Long-passage pagination | Pass (Romans 15 → 7 images). |
| Native Android share sheet | Pass. ChooserActivity opened (`12`, `27`). Cancelled each time; nothing was sent. |
| Review catalogue | Pass. Counts match the exports; drill-down to the proposal; approve gated by reviewer name (`18`–`23`). Nothing was recorded. |
| Offline | Pass. Cold start, Daily Word, preview and image composition worked in airplane mode; the native share sheet opened with 7 files. Airplane mode was switched back off. |
| Light and dark | Pass (`04`, `28`, `29`). |
| Three-button navigation | Pass. The nav sits above the system bar and content is never hidden. Gesture navigation was **not** tested (I did not change your phone's system navigation setting). |
| Restart and persistence | Pass. Theme, history, the Daily Word for the date and preferences survived several force-stops. |

## 5. Remaining visual defects and gaps
1. **Mode A was not seen on the device.** It needs an approved name-insertion rule, or a Daily Word whose passage has a passing Mode A proposal (preview). Mode A rendering is covered by renderer tests and by the onboarding example.
2. **A pull-to-refresh spinner stuck once on Home** after an unusual synthetic swipe from adb; a normal pull completed correctly. Not reproduced by hand.
3. **The title uses "Emmanuel Nkwoka"** because the full name is stored as the first name. Moving "Nkwoka" to the surname field gives "Emmanuel, abound in hope", as intended.
4. **Discover and Library** use the new tokens but were not recomposed against the references.
5. **The screenshots carry the device's grey overlay** (see the capture note).

## 6. Your theme on the phone
For the captures I temporarily switched the app to Classic Gold light, then dark. It is restored to your saved **Royal Plum, following the system light/dark setting**.
