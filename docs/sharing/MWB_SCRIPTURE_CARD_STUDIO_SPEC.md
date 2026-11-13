# Scripture Card Studio: Specification

Opened from the quick-share sheet ("Card Studio", or "With encouragement" which opens on the Personal panel). Quick share itself is unchanged.

## Designs

| Template | Character | Default type | Colourways |
|---|---|---|---|
| Classic | The existing quick-share card in the app theme (byte-identical output, tested) | Lora | App theme |
| Ivory & Gold | Ivory panel, double gold frame, corner flourishes | Lora | Ivory, Pearl, Blush |
| Royal Navy | Dark gradient, gold rules, star field | Cormorant Garamond | Navy, Midnight, Emerald |
| Editorial | Magazine layout, large reference heading, rules | Cormorant Garamond | Paper, Newsprint, Ink |
| Minimal | White space, sans type, accent dot | Inter | White, Stone, Black |
| Cinematic | Painted dusk light, rays, hills, grain, vignette, scrim behind text | Lora | Dusk, Dawn, Night |
| Devotional | Warm amber light, soft bokeh, cross of light | Lora | Amber, Rose, Honey |
| Nature | Leafy branches, rolling hills | Lora | Sage, Sea, Forest |
| Vibrant | Bold gradient, blurred colour blobs, reference "sticker" pill | Inter | Electric, Sunset, Lime |

"Cinematic photography" is **procedurally painted**, not a photograph: no photo library is bundled (licensing), and choosing your own photo would need an image-picker dependency. Fonts are the three already bundled (SIL OFL). No new font or image asset was added.

## Formats

Portrait 1080×1350, Square 1080×1080, Story 1080×1920, Landscape 1920×1080 (new; Studio only). Story keeps a 230 px top and 250 px bottom safe zone for WhatsApp Status / Instagram / Facebook Story chrome. Landscape caps the text measure at 1480 px for readability.

## Customisation

Design, background colourway, size, decorative details on/off; typeface (Serif, Garamond, Sans, Bold sans); text size (Smaller/Standard/Larger); alignment (Auto/Left/Centre); text colour (only colours with WCAG contrast ≥ 4.5 against the colourway's text backdrop are offered; an unreadable choice falls back); reference above/below; verse numbers; personal note (≤160 characters, with care-intent suggestions); "Shared by {first name}" (default from Sharing & privacy); small "MY WORD BIBLE" line on/off. The look (not the note or name) is remembered for next time.

## Integrity rules (tested)

- The text drawn is the text given (`ShareScripture`): canonical text, or an approved personal rendering when the reader is viewing one. Review previews keep their "not approved" marking (Classic) and are never sent in-app.
- Reference and translation on every image; "continued" and "n / N" when paginated.
- Never clipped or ellipsised: every design uses `ScriptureImageComposer.paginate` (font ladder, then pages by verse, then by word). Psalm 119 is tested in every design × format with every word kept in order and every page within its text band.
- Preview = export: the preview shows the exact PNG bytes that are saved or sent.
- No recipient data is ever drawn. Branding is small, at the foot, never over Scripture; it can be switched off.

## Export

| Action | Behaviour | Status |
|---|---|---|
| Save to Photos | PNG or JPG (quality 60–100) to `Pictures/My Word Bible` via MediaStore (Android 10+, no permission); Android ≤ 9 asks for storage permission | Working (Android) |
| Save to a folder… | Android "Save as" picker (Storage Access Framework) | Working (Android) |
| Share to a destination | WhatsApp Status/chat, Instagram Story/post/square, Facebook post/Story, Telegram: picks the size, opens the app directly with the image(s) | Working (Android, when the app is installed) |
| Other apps | The existing native share sheet (email, Messages, everything else) | Working |
| Caption | Sent with the image to WhatsApp/Telegram; copied to the clipboard for Instagram/Facebook (they drop shared text) | Working |
| iOS | No native channel: Save and app hand-off fall back to the iOS share sheet (which offers "Save Image") | Fallback only, not device-tested |

The app never posts anything. "Opened WhatsApp" means WhatsApp opened with the card; the user chooses "My status" or a chat and decides whether to post. Direct Story intents (`com.instagram.share.ADD_TO_STORY`, Facebook equivalent) need a registered Meta App ID and are **not used**.

## Dependency added

`image` (pure Dart, MIT): JPEG encoding, which `dart:ui` cannot do. No native code, no network.
