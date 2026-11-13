# Notifications: Specification

## In-app inbox (`/inbox`)

Reached from the bell on Home (unread badge) and Profile → Sharing & fellowship → Inbox. Filter chips: All, Scripture, Followers, Encouragement, Prayer, Replies. "Mark all read".

Each notification shows the sender (avatar, name), the event ("Grace Okafor shared a Scripture with you"), the care intent if any, a Scripture preview with reference and translation, the personal message, the time, and a "Demo" badge when simulated. Tapping opens the shared Scripture (`/s/{id}`) or the person.

## Recipient actions on a shared Scripture

Read in the Bible · Save (share history + Library saved verses) · Thank · Respond (reply text) · Follow sender (explicit tap only) · Share this verse (canonical Scripture only, through the same share sheet; never the message) · Report · Block.

## Categories (`NotificationCategory`)

`scriptureReceived`, `newFollower`, `encouragement`, `prayer` (reserved for Phase II prayer requests), `acknowledgement`.

## Persistence and rules

- `LocalNotificationRepository` stores up to 300 records in `mwb.v1.social_notifications`; they survive restarts (tested).
- One record per event: `dedupeKey` (`share:{id}`, `follow:{userId}`); duplicates are ignored (tested).
- Blocking someone removes their notifications and hides their shares.
- Settings → Sharing & privacy: notify on Scripture / new followers.

## What is and isn't real

| Item | Status |
|---|---|
| Inbox, records, read state, filters, actions | Working (local) |
| Receiving from other people | Needs infrastructure. Until then **Try the demo** (Inbox → ⋯) creates sample notifications from demo people, all marked "Demo" |
| Acknowledgements reaching the sender | Needs infrastructure; stored with status `simulated` or `awaitingServer` |
| Phone (push/OS) notifications | Not implemented (needs FCM/APNs and a local-notification plugin; the existing `NotificationService` remains deferred) |
