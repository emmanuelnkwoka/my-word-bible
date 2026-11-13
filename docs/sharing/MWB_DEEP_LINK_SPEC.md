# Deep Links: Specification

## Link forms

| Form | Example | Status |
|---|---|---|
| Web | `https://mywordbible.com/s/{shareId}` (also `www.`) | Intent filter added; **not verified** (domain files not published), so Android opens it in the browser unless the user enables the link in app settings |
| App scheme | `mywordbible://app/s/{shareId}` | Working on Android |
| In-app route | `/s/{shareId}` | Working |

`shareId` is 16–64 url-safe characters (ours are 24). `ShareLinkCodec.parse` accepts only these origins and exactly `/s/{id}`; anything else is rejected (tested).

## Resolution (`ShareLinkResolver`)

| Outcome | When | Screen |
|---|---|---|
| `opened` | Share is on this device and the user is its sender or recipient | Shared Scripture |
| `forbidden` | Private share for other people | "This Scripture is private" (no content shown) |
| `notOnDevice` | Not stored locally (would be fetched from the server) | "Not on this device"; the open is recorded |
| `invalid` | Malformed id | "This link isn't valid" |

Every open is recorded in Share history → Opened links.

## Scenarios

| | Scenario | Phase I behaviour |
|---|---|---|
| A | App installed, link opened | Opens the exact share in-app (app scheme today; https after verification) |
| B | Installed, not authenticated | Accounts don't exist yet. The same mechanism as D is in place: the router keeps the share id (`PendingShareLinkStore`) and opens it after onboarding; with accounts, the redirect moves to sign-in. Private content is never shown before identity is known |
| C | Not installed | Needs the web service: a page at `/s/{id}` rendering `PublicShareMetadata` (title, Scripture excerpt, reference, translation, sender, Open Graph tags) and store links. **Never** the message, recipient or care intent (enforced by the model, tested) |
| D | Installs, then opens | In-app part done (pending link survives onboarding, tested). Deferred deep linking after install needs the Play Install Referrer / web page passing the id: **needs infrastructure** |

## Required infrastructure (not done)

1. Host `https://mywordbible.com/.well-known/assetlinks.json` with package `com.xpatsoft.my_word_bible` and the **release** signing certificate SHA-256 (from Play App Signing).
2. Host `https://mywordbible.com/.well-known/apple-app-site-association` with `applinks` for `/s/*`; add the Associated Domains entitlement `applinks:mywordbible.com` in Xcode, and the `mywordbible` URL scheme in `Info.plist` (iOS not configured in Phase I).
3. Web preview page and share API (`GET /v1/shares/{id}/public`).
4. Test with `adb shell pm get-app-links com.xpatsoft.my_word_bible` until the domain shows `verified`.

Until then, the app never claims that a web link opens the app; "Share link" explains this.
