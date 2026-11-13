# Universal Scripture Sharing: Specification (Stage D.1)

## 1. Where Share appears
| Place | Action | Shares |
|---|---|---|
| Home (Daily Word card) | **Share this verse** | Today's passage in its presentation mode |
| Daily Word screen | **Share this verse** | The same |
| Bible reader, verse selection | **Share** (first action in the bar) | One verse, a range ("Romans 15:13–14"), or several separate verses (numbered) |
| Bible reader, app bar | **Share** icon ("Share Romans 15") | The **whole chapter**, numbered and paginated |
| Library → Saved verses | Share icon on each verse | That verse, in its approved presentation (or the original) |

There is no "Scripture card" step and no template picker. Share composes the images immediately and shows them for a moment, with optional Portrait / Square / Story chips, one **Share** button, and "Share as text".

## 2. What is drawn
- **Text:** exactly what the reader sees, either canonical text or an **approved** rendering with the name set in gold. Review previews are drawn only in reviewer builds, and every page then carries "Review preview — not an approved rendering".
- **Title:** the Mode A heading or the Mode B personal title (with the name in gold). No title for plain verses.
- **Reference and translation** on every page ("— Romans 15:13", "KJV", or "KJV-MWB" when the text itself is personalised).
- **Branding:** a gold medallion and the "MY WORD BIBLE" wordmark, inside an ivory (or espresso, in dark mode) panel with a fine gold frame.
- **Pagination:** "1 / 7" on each page and "continued" on all but the last.

## 3. Layout chosen automatically (`ScriptureImageComposer`)
| Layout | When | Type |
|---|---|---|
| Centred | One passage of 240 characters or fewer | Large, centred, with quotation marks (64→40 px portrait) |
| Editorial | One longer passage | Left-aligned (48→36 px) |
| Passage | Several verses or a chapter | Numbered, left-aligned (52→40 px portrait; 56→42 story) |

Formats: Portrait 1080×1350, Square 1080×1080, Story 1080×1920.

## 4. Completeness rule (never truncate)
1. Try the whole selection on one page, stepping down the font ladder.
2. Otherwise paginate at the smallest comfortable size: whole verses per page, and if a verse is longer than a page, split it at word boundaries. The continuation is unnumbered.
3. Text is never ellipsised and no verse is dropped. Tests check that a full chapter (Psalm 119) keeps every word in order in all three formats, that an over-long verse is split rather than cut, and that the gold name marking survives page splits.

Examples on the phone: Romans 15:13 → 1 image. Romans 15:13–14 → 1 image. Romans 15 (33 verses) → **7 portrait images**.

## 5. Native sharing
`NativeShareService.shareImages` hands all PNGs, plus a text caption, to Android's share sheet (`share_plus`). Images are generated on the device (`dart:ui`), so no network is needed until the receiving app sends them. **Verified on the Xiaomi M2101K7BG**, including in airplane mode: the Android ChooserActivity opened with "my-word-bible-romans-15-13.png", and again with "7 files" for Romans 15, offering WhatsApp Business, Telegram, Nearby Share and others. The app does not claim the share succeeded; it reports only when sharing is unavailable or fails.

## 6. Text sharing
"Share as text" sends the title (if any), the quoted text, the reference and translation, the preview line in reviewer previews, and "Shared from My Word Bible".

## 7. Code
- `lib/features/share/scripture_image_composer.dart`: layout, pagination and drawing.
- `lib/features/share/scripture_share_sheet.dart`: builders from rendered verses, canonical verses and presentations; the sheet.
- `lib/features/share/share_service.dart`: native boundary (`shareImages` added).
- The old `scripture_card_sheet.dart` was removed; `scripture_card_renderer.dart` is kept for its existing test.
