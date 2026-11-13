# Daily Word Validation Report

11 November 2026. Final APK built at 20:3x, 216,615,059 bytes (debug).

## 1. Automated checks

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **280 passed, 0 failed** (234 before Stage D + 46 new) |

New tests (`test/daily_word/`):

| File | Tests | Covers |
|---|---:|---|
| `schedule_test.dart` | 13 | 365-day coverage; Feb 29 → Rev 21:5 (never used elsewhere or adaptively); 28 Feb / 1 Mar unchanged in leap years; month-day mapping; no consecutive categories across a leap year (including 31 Dec → 1 Jan); explicit reuse and 113-day spacing; versioning; candidate fields and pending review; every reference resolves in KJV and WEB with a Stage C context; no verse text stored; held-back passages; offline loading once; missing or malformed schedule |
| `engine_test.dart` | 18 | Personalisation off → schedule; no signals → schedule; leap day fixed; determinism; interest adaptation with reasons; weak signal cannot override; diversity penalty; freshness window and the next-scheduled fallback; neutral reasons with no divine claims; each scorer dimension; search cap; penalties; profile window, clearing and saved-Daily-Word handling; stable hash |
| `daily_word_flow_test.dart` | 15 | One stored word per date, stable after new signals and a restart; no duplicate history; newest-first history; earlier entries never overwritten; favourite and save persist and match the Library; personalisation off; interests adapt future words; clearing signals; detail with context, promises, related Scripture and surrounding verses; missing context shows nothing invented; WEB offline; share payload text; card PNG 1080×1350 with the ladder shrinking long text; widget flows (Home → Daily Word → save, favourite, native share), previous/next and history, card sheet preview |

**Existing tests changed:**
- Three assertions in `navigation_test.dart` and `onboarding_test.dart` looked for the label "DAILY SCRIPTURE" as proof that Home rendered. That label belonged to the card the Daily Word replaced. They now assert the Daily Word card (`home.dailyWord`) and its "DAILY WORD ·" label, which is the same check.
- `test_app.dart` gained the Daily Word repository override and an optional `extra` overrides parameter.

No test was removed or weakened.

## 2. Emulator run (`emulator-5554`, Android, 1080×2400)

| Step | Result | Screenshot |
|---|---|---|
| Home shows the Daily Word card | ✔ "Not cut off", Proverbs 23:18 (adaptive) | `01_home` |
| Open Daily Word | ✔ Date, Today pill, heading, KJV Scripture, actions | `02_daily_word` |
| Why / context / related | ✔ Reasons; editorial context; promise with condition; related Scripture with explanations | `06_context`, `07_related`, `08_related_scripture` |
| Open a related Scripture | ✔ Reader opened at Romans 15 | `09_related_opened` |
| Save and favourite | ✔ Changed to Saved / Favourited | — |
| Scripture card | ✔ 1080 × 1350 PNG preview | `03_card_sheet` |
| Share image | ✔ Android "Sharing image" sheet with the PNG | `04_share_image_sheet` |
| Share text | ✔ "Sharing text" with Scripture, reference (KJV) and app line | `05_share_text` |
| History | ✔ Entry with favourite star | `10_history` |
| Force-stop + **airplane mode** + relaunch | ✔ Same word, Saved and Favourited kept, card generated offline | `11_offline_home`, `12_offline_card` |

## 3. Physical phone (`JFUKI7WC4HHYSWJV`, Xiaomi M2101K7BG, MIUI, 1080×2400)

**Access:** the phone was locked at first. The founder unlocked it and enabled "USB debugging (Security settings)" so simulated input would work. Before that setting was on, two simulated taps landed in MIUI Settings and opened *App compatibility changes* for this app. The screenshot shows no switch was changed.

| Step | Result | Screenshot |
|---|---|---|
| Install final APK | ✔ `Success` | — |
| Launch; Profile shows "Daily Word & privacy — Local personalisation on" | ✔ | `p00_profile` |
| Home Daily Word card | ✔ "Grace for today", Matthew 6:34, Rest, "Chosen from your activity on this device" (Royal Navy theme) | `p01_home` |
| Daily Word screen, context, read in context | ✔ Speaker Jesus; author Matthew (traditional attribution); audience the disciples and crowd; verses 31–34 | `p02_daily_word`, `p05_front` |
| Save and favourite | ✔ Saved / Favourited; confirmed in the app's storage (`run-as`) | `p06_top`, `p12_share_text` |
| Scripture card + share image | ✔ Preview; MIUI share sheet with `my-word-bible-2026-11-11.png` (cancelled, nothing sent) | `p07_card`, `p08_share_image` |
| Share text | ✔ MIUI share sheet titled "Matthew 6:34 (KJV)" (cancelled) | `p12_share_text` |
| Force-stop + **airplane mode** + relaunch | ✔ Same word, favourite star on Home; card generated offline | `p09_offline_home`, `p10_offline_card` |
| History | ✔ One entry, favourite | `p13_history` |
| Stored entry | ✔ `date 2026-11-11`, `cid dwc-MAT-6-34`, `sv 2026.1`, `sch dwc-ISA-53-5`, `ad true`, `fav true`, `open` time | — |

Afterwards, airplane mode was switched back off and the "stay awake while charging" setting restored.

## 4. Defects found and fixed during device testing

1. The interest reason named the category ("Hope") instead of the interest the reader chose. It now reads "Fits an interest you chose (Faith), in the theme Hope". Words already delivered keep their stored wording, by design.
2. "Form" repeated identical labels ("Wisdom literature · Wisdom literature"). It is now shown once.
3. Loading states were not centred on the Daily Word screen and in the card sheet. Fixed.
4. On MIUI with three-button navigation, the card sheet's "Share image" button sat under the navigation bar. The preview is now capped at 48% of screen height and the bottom inset is respected. Re-verified on the phone (`p11_card_fixed`).

## 5. Not verified

- Sharing into a specific app such as WhatsApp. The share sheets were opened and cancelled; nothing was sent.
- A day change while the app stays open overnight. Today is re-read on Home refresh and on app start.
- Personalisation off and signal clearing were tested automatically, not on a device.
