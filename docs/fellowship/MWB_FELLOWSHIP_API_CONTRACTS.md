# MWB Fellowship & Growth Engine: API Contracts (Phase 0, proposed)

**[PROPOSAL]**, not implemented.

- **Base:** `{MWB_API_BASE_URL}/v1`, from `--dart-define` [FACT: `AppConfig`].
- **Format:** JSON over HTTPS only.
- **Auth:** `Authorization: Bearer <access>` on every endpoint except those marked **public** [FACT: `AuthHeaderInterceptor`].
- Every mutating endpoint accepts an `Idempotency-Key` (UUID). A replay returns the original response.

## 1. Conventions

### 1.1 Error shape (resolves an existing inconsistency)

`lib/core/network/interceptors.dart` `mapStatusCode` reads Laravel's top-level `message` and `errors` [FACT]. `docs/sharing/MWB_BACKEND_API_CONTRACT.md` instead specifies `{ "error": { "code", "message" } }` [FACT].

**Proposal:** one shape that satisfies the existing client and adds a stable code:

```json
{ "message": "Human-readable, user-safe text", "code": "not_partner", "errors": { "field": ["…"] } }
```

`mapStatusCode` keeps working unchanged. Fellowship repositories can read `code`. The sharing contract should be updated to the same shape when it is implemented.

| HTTP | `code` examples |
|---|---|
| 400 | `bad_request` |
| 401 | `unauthenticated` (the existing interceptor clears tokens) |
| 403 | `forbidden`, `not_member`, `blocked`, `age_required` |
| 404 | `not_found` (also used instead of 403 where existence must not be revealed) |
| 409 | `already_member`, `invitation_used`, `state_conflict` |
| 410 | `invitation_expired` |
| 422 | `validation_failed`, `invalid_scripture`, `personalised_translation`, `late_event`, `future_event`, `paused` |
| 429 | `rate_limited` (with `Retry-After`) |

### 1.2 Other conventions

- **Pagination:** `?cursor=` → `{ "items": [...], "next_cursor": "…" | null }`.
- **Time:**
  - instants are UTC ISO-8601;
  - fellowship dates are `yyyy-mm-dd` in the fellowship timezone;
  - clients send `X-Client-Timezone` (IANA).
- **Versioning:** `/v1`. Breaking changes require `/v2`. The server sends `X-Min-Client-Version`.

## 2. Accounts

| Method | Path | Body → Response |
|---|---|---|
| POST **public** | `/auth/register` | `{email, password, display_name, timezone, adult_attestation: true, accepted: {terms, privacy}}` → `202` (verification email sent; the same response is returned if the email exists) |
| POST **public** | `/auth/verify-email` | `{token}` → `200 {access, refresh, user}` |
| POST **public** | `/auth/login` | `{email, password, device: {platform, app_version}}` → `200 {access, refresh, user}` |
| POST **public** | `/auth/refresh` | `{refresh}` → `200 {access, refresh}` (rotation; reuse of an old refresh token revokes the family) |
| POST **public** | `/auth/password/forgot` | `{email}` → `202` (always) |
| POST **public** | `/auth/password/reset` | `{token, password}` → `204` |
| POST | `/auth/logout` | → `204` (revokes this device's refresh token) |
| GET / PATCH | `/me` | `{display_name, timezone, locale}` |
| POST | `/me/export` | → `202` (an export link is emailed later) |
| DELETE | `/me` | `{password or recent re-auth}` → `202 {scheduled_for}` (sessions revoked immediately) |
| POST / DELETE | `/me/devices` | `{platform, push_token}` / `{device_id}` |

Rate limits: login 5/min per IP and email, register 3/hour per IP, forgot 3/hour per email. Responses are uniform, so they do not reveal whether an account exists.

## 3. Invitations and fellowships

| Method | Path | Notes |
|---|---|---|
| POST | `/fellowships/invitations` | `{features: {streak, prayer, exchange, together}, timezone?}` → `201 {invitation_id, url, code, expires_at}`. The URL is `https://mywordbible.com/i/{token}`. The token is shown once |
| GET | `/invitations/{token}` | → `{inviter_display_name, features, expires_at}` (signed in; the token must be valid). No other inviter data |
| POST | `/invitations/{token}/accept` | → `201 Fellowship` · `403 age_required` · `410` · `409 invitation_used` · `403 blocked` |
| POST | `/invitations/{token}/decline` | → `204`. The inviter sees "not accepted", with no reason |
| DELETE | `/fellowships/invitations/{id}` | Inviter revokes |
| GET | `/fellowships` | → the caller's fellowships (active, paused, invited, ended in the last 30 days) |
| GET | `/fellowships/{id}` | Members only, else `404` |
| POST | `/fellowships/{id}/pause` · `/resume` | Either member. Pause is immediate; resume needs only the pausing member [OPEN: or both] |
| POST | `/fellowships/{id}/leave` | → `204`. Ends it for both, and the partner is told neutrally ("This fellowship has ended") |
| PATCH | `/fellowships/{id}/me` | `{features, muted_until}` (per-member preferences) |

`Fellowship` JSON:

```json
{ "id": "…", "kind": "pair", "status": "active", "timezone": "Africa/Lagos",
  "partner": { "id": "mwb_…", "display_name": "…" },
  "features": { "streak": true, "prayer": true, "exchange": true, "together": true },
  "paused": null, "created_at": "…" }
```

## 4. Participation and WordStreak

| Method | Path | Notes |
|---|---|---|
| POST | `/participation/events` | Batch of up to 100 events: `{events: [{client_event_id, fellowship_id, kind: "engaged", local_date, occurred_at}]}` → `200 {results: [{client_event_id, accepted, code?}]}`. Idempotent per `client_event_id`. The client never sends counts |
| GET | `/fellowships/{id}/days?from=&to=` | → `[{date, state, me: {engaged, acted}, partner: {took_part: bool}}]`. The partner's detail is reduced to one boolean |
| GET | `/fellowships/{id}/summary` | → `{days_together, last_complete_date, today: {state, me, partner_took_part}}`, computed by the server |

`acted` is never posted by the client. The server sets it from exchanges, responses and prayer responses.

## 5. Scripture Exchange

Same semantics as `MWB_BACKEND_API_CONTRACT.md` §3–6 [FACT], scoped to fellowships.

| Method | Path | Notes |
|---|---|---|
| POST | `/fellowships/{id}/exchanges` | `{references, reference_label, translation_id, message?, care_intent?}`. The server re-resolves canonical text and rejects `personalised_translation` → `201 Exchange` |
| GET | `/fellowships/{id}/exchanges?cursor=` | Members only |
| POST | `/exchanges/{id}/opened` | Recipient only |
| POST | `/exchanges/{id}/responses` | `{kind: thanks|amen|prayed|reply, message?}` |
| DELETE | `/exchanges/{id}` | Sender only. Removed for both |

## 6. Prayer Partnership

| Method | Path | Notes |
|---|---|---|
| POST | `/prayers` | `{body, audience: [{fellowship_id}]}`. `audience` is **required and non-empty**; there is no default → `201` |
| GET | `/prayers?scope=mine|shared_with_me&status=` | |
| GET | `/prayers/{id}` | Author or a current audience member, else `404` |
| PATCH | `/prayers/{id}` | Author: `{body?, status?: answered|closed, answered_note?}` |
| DELETE | `/prayers/{id}` | Author. Hard delete for the audience |
| POST | `/prayers/{id}/responses` | `{kind: prayed|encouragement|scripture, message?, exchange?}`. `prayed` once per day per user |

## 7. Daily Word Together

| Method | Path | Notes |
|---|---|---|
| GET | `/fellowships/{id}/together/{date}` | → `{date, schedule_version, candidate_id, reference}`. Created on first request from the server's copy of the schedule. Text is rendered on the device |
| POST | `/fellowships/{id}/together/{date}/thoughts` | `{body}` (explicit share; counts as `acted`) |
| GET | `/fellowships/{id}/together/{date}/thoughts` | Members |
| DELETE | `/together/thoughts/{id}` | Author |

## 8. Safety

| Method | Path | Notes |
|---|---|---|
| PUT / DELETE | `/blocks/{userId}` | Blocking ends all shared fellowships and hides all of the blocked user's content. The blocked user is not notified |
| POST | `/reports` | `{reported_user_id, object_type, object_id, reason, details?, include_content: bool}`. The reporter is told exactly what moderators will see |
| GET | `/notifications?cursor=` · POST `/notifications/read` | As in the sharing contract §7 |

The admin and moderation API is served under a separate host or path, with separate roles and MFA. It is not part of the mobile contract.

## 9. Push payloads

FCM `data` only: `{ "type": "exchange.received" | "prayer.prayed" | "fellowship.invitation_accepted" | "together.thought" | "fellowship.ended", "id": "…" }`. No title or body text that includes names, Scripture, prayer or messages, unless the user opts in to "show previews" [OPEN].

## 10. Flutter mapping

| Endpoint group | New repository interface → implementations |
|---|---|
| §2 | `AuthRepository` [FACT] → `RemoteAuthRepository` (complete it) |
| §3 | `FellowshipRepository` → `LocalDemoFellowshipRepository` (tests) / `RemoteFellowshipRepository` |
| §4 | `ParticipationRepository` + `OutboxService` |
| §5 | `ExchangeRepository` (reuses `ScriptureShare` JSON) |
| §6 | `PrayerRepository` |
| §7 | `TogetherRepository` |
| §8 | `SafetyRepository` [FACT] → `RemoteSafetyRepository`; `NotificationRepository` [FACT] → remote |
