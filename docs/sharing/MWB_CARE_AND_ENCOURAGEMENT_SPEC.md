# Care & Encouragement: Specification

## Intents (`CareIntent`)

| Label | Editable starting text |
|---|---|
| I'm thinking of you | I was thinking of you today and wanted to share this. |
| I'm praying for you | I'm praying for you. |
| You're not alone | You're not alone. I'm here with you. |
| Don't lose hope | This verse reminded me not to lose hope. I hope it encourages you too. |
| I'm encouraged by this | This verse encouraged me and I wanted to pass it on. |
| I wanted to share this | I wanted to share this with you. |

Offered as optional chips in **Send to someone** (private message) and in the Card Studio's Personal panel (note printed on the card, with a warning that anyone who sees the image can read it). The quick-share sheet has a **With encouragement** shortcut.

## Safeguards (implemented)

- No intent names or implies a circumstance (financial, medical, emotional). Wording is about the sender, not a diagnosis of the recipient.
- The recipient is never asked to disclose anything; there is no "what's wrong?" field.
- Care intents and messages are private: never on public profiles, public activity or link previews (`PublicShareMetadata` excludes them; tested).
- The Studio's Personal panel reminds: Scripture is not a substitute for being there; a call or visit may mean more.
- Sharing & privacy states that My Word Bible never shows anyone's struggles publicly.
- Controls: block (hides shares and notifications, prevents sending and following), report (saved locally until moderation exists), who can send me Scripture (everyone / people I follow / no one), profile visibility, public activity off by default.

## Foundations for later phases

- `PrayerRequest` model (private-to-selected by default, circle, followers; answered date) and `NotificationCategory.prayer`: **model only**.
- Prayer circles, small study groups, supportive connections: **not implemented**; the follow graph, privacy settings and notification categories are the base they will use. Contracts in `MWB_BACKEND_API_CONTRACT.md` §9.
