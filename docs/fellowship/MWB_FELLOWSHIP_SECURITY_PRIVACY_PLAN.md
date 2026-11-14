# MWB Fellowship & Growth Engine: Security & Privacy Plan (Phase 0)

Labels: **[FACT]** · **[PROPOSAL]** · **[OPEN]** · **[EXTERNAL]** · **[BLOCKER]**. This is an engineering plan, not legal advice. Legal review is required before any real-user pilot.

## 1. Commitments, and how each is enforced

| Rule (from directive) | Enforcement [PROPOSAL] |
|---|---|
| Canonical Scripture unchanged | Fellowship has no Bible data. Text comes from `BibleRepository`; the server re-resolves references against canonical text and rejects personalised translation ids [FACT: the same rule exists in `LocalScriptureShareRepository._canonical`]. Tests assert byte equality with the Bible assets |
| Notes never shown as Scripture | Reflections and messages use distinct widgets ("Your reflection", "Message from …"). Never use Scripture typography or the verse layout. Card Studio keeps personal notes labelled [FACT]. Widget tests check the labels |
| Reflections private by default | Journal is local-only in the MVP. No sync code path exists. Not in the outbox schema. Not in notifications |
| Reflection text not in analytics | No analytics exists today [FACT]. If any is added, it uses an **allow-list** of event names with no free text, and journal and prayer screens send nothing. CI test: no analytics call in `features/fellowship/**/journal*` and `prayer*` |
| Prayer audience explicit | API requires a non-empty `audience`. The UI has no preselected audience. The `followers` and `circle` options are not offered in MVP [FACT: they exist in the enum] |
| Prayer never used for ads or AI training | No ad SDKs. No third-party AI processors receive user content. Vendor contracts (DPAs) exclude training. Stated in the privacy notice [EXTERNAL] |
| No public scores or leaderboards | No endpoint returns any user's numbers to anyone but the two partners. No ranking endpoint exists |
| No guilt-driven messages | Copy guidelines (§6). There is no missed-day notification type in the push catalogue (API contracts §9) |
| Missed day ≠ spiritual failure | Neutral calendar mark. "Days together" restarts quietly. No loss animations |
| No automatic disclosure of reflections | The partner API exposes only `took_part: bool` (API contracts §4) |
| No public people discovery | No search endpoint in Fellowship. Connection only by invitation link or code. Phase I directory search stays demo-only (§4) |
| No unrestricted adult-to-minor communication | Pilot is adults only: attestation at registration and again at invitation acceptance (`403 age_required`). No minor accounts exist |
| Adult consenting pairs only | Invitation must be accepted by a signed-in, attested adult. Either side can leave at any time |
| Block, report, mute, pause, leave, deletion | Each has an endpoint (API contracts §3, §8, §2) and a UI path no more than two taps from the partner screen |

## 2. Threat model (main cases)

| Threat | Mitigation |
|---|---|
| Account takeover | Argon2id/bcrypt hashes; rate limits; email verification; refresh rotation with reuse detection; sessions listed and revocable |
| Invitation link forwarded to the wrong person | Single-use, 7-day expiry, revocable. The inviter sees the acceptor's display name and can leave immediately. The token is hashed at rest |
| Enumeration (users, invitations, prayers) | Opaque ids. `404` for non-members. Uniform auth responses |
| Insecure direct object reference across pairs | Every query is scoped by membership through a policy layer. Automated authorisation tests for every endpoint (non-member gets `404`) |
| Spoofed participation | `acted` is server-observed only. `engaged` is accepted within time windows and is labelled as self-reported participation |
| Coercion or abuse by a partner | Leave, block and report without notifying the other side of the reason. No location or online-presence data is collected |
| Lock-screen exposure | Push carries ids only [FACT: required by the existing contract] |
| Device loss | Journal encrypted with a Keystore/Keychain-held key. Optional app lock [OPEN] |
| Insider access | Moderators see only reported content snapshots. Admin access needs MFA. Every access is audit-logged without content |
| Backups leaking deleted data | Encrypted backups with fixed retention (35 days proposed). Deletion is documented to users |
| Secrets in the repository | None tracked today [FACT]. Keep all keys (FCM service account, APNs, DB, signing) in CI or the host's secret store. Never use `--dart-define` for server secrets |

## 3. Data protection

- **In transit:** HTTPS only. Certificate pinning is not proposed for the MVP (operational risk); revisit later.
- **At rest (server):** encrypted volumes plus application-level encryption for P3 columns (`*_enc`): prayer bodies, messages, thoughts, report snapshots. Keys are held in the host's key management service and rotated yearly.
- **At rest (device):** tokens in secure storage [FACT]; journal body encrypted [PROPOSAL, needs a package decision]; other local data in the app sandbox as today [FACT].
- **Logs:** request paths and status codes only. Never bodies, tokens or emails in plain text. This extends the existing `SafeLogInterceptor` principle [FACT].
- **End-to-end encryption:** **not proposed for the MVP**, because moderation of reported content needs a server-readable copy of what was reported. Re-evaluate for prayer requests after the pilot [OPEN].
- **Data residency:** [OPEN, EXTERNAL] where the database is hosted relative to users (for example, Nigeria NDPA 2023, UK/EU GDPR). Religious belief is a special or sensitive category under these regimes. **Legal confirmation is a release blocker.**

## 4. The Phase I social layer and Fellowship [OPEN, founder decision]

Facts:

- Phase I includes public profiles (default visibility `everyone`), username and name search, followers and following, and public Scripture activity in Discover.
- All of it is local and demo-only today (`DemoUserDirectory`, `isLive == false`).

Proposal:

1. **Keep the Phase I directory, follows and public activity on the device as a demo. Do not connect them to the real backend in the Fellowship MVP.**
2. Real Scripture sending in the pilot happens only between accepted fellowship partners.
3. Re-evaluate public profiles and follows after the pilot, with a separate privacy review.

## 5. Moderation and safeguarding [BLOCKER items marked]

- **Report flow:** the reporter chooses a reason and whether to attach the content. They are shown exactly what moderators will see. They are offered block and leave in the same flow.
- **Queue:** a named moderator role and a target first-review time [OPEN]. Actions are warn, remove content, suspend or ban, all audit-logged.
- **Crisis content [BLOCKER]:** a written safeguarding protocol before the pilot.
  - In-app "If you are in danger" resources (region-specific numbers [EXTERNAL]).
  - Guidance for moderators.
  - **No** automated scanning of prayer text.
- **Minors:** none are permitted in the pilot. A separate safeguarding and legal review is required before any age-related experience (directive).

## 6. Copy guidelines (no guilt, no pressure)

| Avoid | Use |
|---|---|
| "Don't break your streak!" | "Your partner took part today." |
| "You missed yesterday" | (No message. The calendar shows the day neutrally) |
| "Streak lost" | "Starting fresh together" (only if the user opens the calendar) |
| "Only 2 hours left!" | (No countdowns) |
| Any implication about faithfulness or God's favour | Never |

Reminders are opt-in, at most one per day, at a time the user chose, and the user can turn them off from the notification itself.

## 7. User controls

- **Pause:** either partner; it pauses the day calendar.
- **Leave:** ends the fellowship for both.
- **Mute:** notifications only.
- **Block** and **report.**
- **Delete** a prayer, exchange or thought.
- **Export** account data. **Delete** account.
- **Delete journal:** on the device. Its own "Delete all reflections", separate from "Clear library" [FACT: `settings_screens.dart` already has clear-library and reset-onboarding patterns].

## 8. Privacy notice changes [FACT → BLOCKER]

`PrivacyScreen` currently says there is no account and nothing leaves the device [FACT]. Before any Layer B feature is enabled, this screen and the published privacy notice must describe:

- accounts;
- what Fellowship stores on the server;
- who sees it;
- retention;
- deletion;
- the processors (hosting, email, FCM).

Layer A features keep the current statement true.
