# Backend API Contract: Sharing & Social (Phase I, proposed)

Not implemented in this phase. JSON mirrors the models in `lib/data/models/social.dart` (`toJson`), so remote repositories can reuse them. All endpoints require a bearer token unless marked **public**. Base: `{MWB_API_BASE_URL}` (from `--dart-define`). Errors: `{ "error": { "code": "not_found|blocked|not_accepting|self|invalid_scripture|forbidden|rate_limited", "message": "…" } }`; messages never reveal private data.

## 1. User lookup

`GET /v1/users/search?q={text}&limit=20` → `{ "users": [PublicProfile] }`
- Matches username (with/without `@`), exact user id, display name. Excludes the caller, blocked in either direction, and `onlyMe` profiles except on exact match. Rate-limited.

`GET /v1/users/{userId}` → `PublicProfile` | 404. Server validates `^mwb_[a-z0-9_]{3,40}$`.

## 2. Public profile

`GET /v1/users/{userId}/profile` → `PublicProfile` with `publicActivity` only if visibility allows and the caller is not blocked. `followsYou` computed for the caller.

## 3. Share creation

`POST /v1/shares` · header `Idempotency-Key: {uuid}`
```json
{ "recipientId": "mwb_…", "references": [{"b":"ROM","c":15,"vs":13}], "referenceLabel": "Romans 15:13",
  "translationId": "KJV", "receptionEdition": null, "message": "…", "careIntent": "prayingForYou",
  "templateId": "ivory_gold", "privacy": "private" }
```
→ `201 ScriptureShare` with `status: "sent"`. Server re-resolves the canonical text from its own licensed copy (client text is never trusted), rejects personalised editions as `translationId`, applies `SharePolicy` (block, audience). Same idempotency key → the original share, no second delivery.

## 4. Share delivery

Server pushes to the recipient's devices (FCM/APNs) and marks `delivered` when a device acknowledges:
`POST /v1/shares/{id}/delivered` (recipient device) → 204.
Sender sees status via `GET /v1/shares/sent?cursor=` and push `share.status_changed`.

## 5. Share retrieval

`GET /v1/shares/{id}` → `ScriptureShare` if caller is sender or recipient, else 403 (private) · 404.
`GET /v1/shares/received?cursor=` / `GET /v1/shares/sent?cursor=`.
`POST /v1/shares/{id}/opened` · `PUT /v1/shares/{id}/saved {"saved":true}`.

## 6. Acknowledgement

`POST /v1/shares/{id}/acknowledgements` `{ "kind": "thanks|amen|prayed|reply", "message": "…" }` (Idempotency-Key) → `ShareAcknowledgement`. One of each non-reply kind per user per share.

## 7. Notifications

`GET /v1/notifications?cursor=` → `{ "items": [InAppNotification] }` · `POST /v1/notifications/read {"ids":[…]|"all":true}` · `DELETE /v1/notifications/{id}`.
`POST /v1/devices {platform, pushToken}` registers push. Push payload carries only `{type, notificationId, shareId?}`, never message text (lock-screen privacy).

## 8. Follow / block / report

`PUT /v1/follows/{userId}` · `DELETE /v1/follows/{userId}` · `GET /v1/users/{id}/followers|following?cursor=` (respecting visibility).
`PUT /v1/blocks/{userId}` · `DELETE /v1/blocks/{userId}` · `GET /v1/blocks`.
`POST /v1/reports {userId, shareId?, reason, details?}` → moderation queue.
Following is only ever created by an explicit `PUT` from the follower.

## 9. Privacy settings & future care features

`GET/PUT /v1/me/privacy` → `SocialPrivacySettings`. `GET/PUT /v1/me/identity` (claim username; 409 if taken).
Reserved: `POST /v1/prayer-requests` (`PrayerRequest`), circles `/v1/circles/*`.

## 10. Deep-link resolution (**public**)

`GET /v1/shares/{id}/public` → `PublicShareMetadata` (`title`, `description`, `reference`, `translation`, `senderName`, `url`) or 404. Never includes message, recipient or care intent. Used by the web preview page (`https://mywordbible.com/s/{id}`), which also serves Open Graph tags and app-store links, and hosts `/.well-known/assetlinks.json` and `apple-app-site-association`.

## Mapping to Flutter

| Endpoint group | Replace provider |
|---|---|
| 1–2 | `userDirectoryProvider` |
| 3–6, 10 | `scriptureShareRepositoryProvider` (`isLive: true`) |
| 7 | `notificationRepositoryProvider` |
| 8 | `followRepositoryProvider`, `safetyRepositoryProvider` |
| 9 | `socialSettingsRepositoryProvider` |
