# Direct Scripture Sharing ("Send to someone"): Specification

## Flow

1. From the quick-share sheet (or Card Studio, a profile, or a received share) choose **Send to someone**.
2. **Find the person**: search by `@username`, username, MWB user ID (`mwb_…`) or name. With an empty search: Recent, Following and (until accounts exist) the Sample community.
3. **Compose**: the canonical text that will be sent (re-read from the installed Bible), an optional care intent and personal message (≤280), and visibility: *Private* (only the two of you) or *May pass it on* (Scripture only, never the message).
4. **Send** → an honest result: "Sent in the demo" (demo person, nothing left the phone) or "Saved on this device; delivered when accounts are live".

Card design is carried as `templateId` so the recipient's app can present it in the same style later.

## Identity and verification

- The current user has a local identity (`mwb_local_…`, proposed username), shown in Sharing & privacy as *reserved, claimed when accounts launch*. Nothing is published.
- IDs must match `^mwb_[a-z0-9_]{3,40}$`; anything else (injection attempts, paths, upper case) returns nothing without a lookup.
- `PublicProfile` has no private fields at all (no email, phone, location, birthday or private follows), so no lookup can expose them.
- Before creating and again before delivering, the recipient is re-resolved and `SharePolicy.check` refuses: unknown person, yourself, blocked (either direction, as far as known locally), or someone whose setting excludes you ("only people I follow", "no one"). Refusal messages reveal nothing private.

## Share model (`ScriptureShare`)

| Field | Notes |
|---|---|
| `id` | 144-bit random, url-safe; also the deep-link id |
| `idempotencyKey` | Prevents double delivery |
| `direction`, `senderId/Name`, `recipientId/Name` | |
| `references`, `referenceLabel`, `translationId` | Canonical, resolvable; `translationId` must be an installed original translation (never `KJV-MWB`) |
| `verses` | Canonical snapshot verified at creation; canonical Bible records are not copied or changed |
| `receptionEdition` | Optional hint: recipient may read in *their own* approved personal edition |
| `message`, `careIntent` | Private |
| `templateId`, `privacy`, `createdAt` | |
| `status` | `preparedOffline`, `awaitingServer`, `simulated`, `sent`, `delivered`, `failed` |
| `openedAt` (read), `savedAt`, `acknowledgements` | |
| `simulated` | Demo record |

## Status in this build

| Capability | Status |
|---|---|
| Search, verification, policy, canonical snapshot, idempotent delivery, history | Working (local) |
| Recipients | Local mock: 7 invented demo people; profiles seen in received shares are remembered |
| Delivery to another person's device | Needs infrastructure (MWB sharing service + accounts). Real recipients get `awaitingServer` |
| Duplicate prevention | Working (idempotency key, dedupe on receive and on notifications) |
