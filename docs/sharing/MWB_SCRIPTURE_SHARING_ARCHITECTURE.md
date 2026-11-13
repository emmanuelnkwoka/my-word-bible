# MWB Scripture Sharing & Christian Social Connection Engine: Architecture (Phase I)

Status key used in all Phase I documents:

| Status | Meaning |
|---|---|
| **Working** | Completed and working on the device, offline |
| **Local mock** | Implemented with on-device data (demo community, simulated delivery) |
| **API-ready** | Interface and contract exist; no remote implementation connected |
| **Needs infrastructure** | Requires a server, domain or store configuration outside the app |
| **Not implemented** | Not built in Phase I |

## 1. Principles

1. **One sharing engine.** Every entry point (Bible reader selection bar, reader chapter share, Daily Word, Home, Library saved verses, Discover, profiles, received shares) builds a `ShareScripture` and opens the existing `showScriptureShareSheet`. The Card Studio, direct sharing, saving and app hand-off all start from that sheet or reuse its pieces.
2. **Enhance, never replace.** The quick-share sheet keeps its preview, Portrait/Square/Story chips, **Share** and **Share as text** exactly as before. New capabilities sit under "More ways to share" and are optional.
3. **Canonical Scripture is never changed.** Cards draw the text they are given; direct shares re-read the canonical text from the installed Bible (`BibleRepository.passage`) using `ShareScripture.sources` and `sourceVersionId`. A personalised MWB rendering is never sent to another person as Scripture; it is named only as a `receptionEdition` hint.
4. **Honesty.** No screen claims delivery, posting or link opening that did not happen. Demo people and simulated records carry a visible "Demo" badge.
5. **Swappable data.** Each data concern is an interface with an on-device implementation, provided through Riverpod in `lib/app/app_providers.dart`.

## 2. Modules and files

| Concern | Files |
|---|---|
| Card rendering (quick share, existing) | `lib/features/share/scripture_image_composer.dart` (pagination now exposed as `ScriptureImageComposer.paginate`, shared by all designs) |
| Card Studio design + rendering | `lib/features/share/studio/card_design.dart`, `card_studio_renderer.dart`, `card_studio_screen.dart` |
| Share composition (builders, quick sheet) | `lib/features/share/scripture_share_sheet.dart` |
| Image export, social destinations | `lib/features/share/export/card_export.dart`, `card_export_flow.dart`; Android channel in `android/app/src/main/kotlin/.../MainActivity.kt` |
| Native share sheet (existing, unchanged interface) | `lib/features/share/share_service.dart` |
| Models | `lib/data/models/social.dart` |
| Repositories | `lib/data/repositories/social_repositories.dart` |
| Deep-link resolution | `lib/features/social/domain/share_links.dart` |
| Application layer | `lib/features/social/application/social_providers.dart` (`SocialActions`, state providers, `PendingShareLinkStore`) |
| Screens | `lib/features/social/presentation/*.dart` |

## 3. Data layer

| Interface | Local implementation | Persists (`StorageKeys`) |
|---|---|---|
| `SocialSettingsRepository` (identity, privacy, recent recipients) | `LocalSocialSettingsRepository` | `social_identity`, `social_privacy`, `social_recent_recipients` |
| `UserDirectoryRepository` (search, lookup, public profiles) | `DemoUserDirectory` (7 invented sample people) | `social_known_people` |
| `ScriptureShareRepository` (create, deliver, receive, open, save, acknowledge, opened links) | `LocalScriptureShareRepository` | `social_shares`, `social_opened_links` |
| `NotificationRepository` | `LocalNotificationRepository` | `social_notifications` |
| `FollowRepository` | `LocalFollowRepository` | `social_following`, `social_followers` |
| `SafetyRepository` (block, report) | `LocalSafetyRepository` | `social_blocked`, `social_reports` |
| `CardExportService` | `PlatformCardExportService` (Android channel) | Gallery / chosen file |

All are overridable providers, so remote versions replace them without touching screens.

## 4. Flow: sending a Scripture to a person

```
Entry point → ShareScripture (verses as displayed + canonical sources)
  → quick-share sheet → "Send to someone" → SendScriptureScreen
    → SocialActions.search → UserDirectoryRepository.search (blocked excluded)
    → SocialActions.sendScripture
        → publicProfileProvider (re-derive recipient) → SharePolicy.check
        → ScriptureShareRepository.create (canonical snapshot, unguessable id)
        → ScriptureShareRepository.deliver (idempotent)
              demo person → simulated   |   anyone else → awaitingServer
```

## 5. Flow: receiving

`SocialActions.receiveShare` checks the user's "who can send me Scripture" setting and blocks, stores the share once (id and idempotency key), and adds one notification (dedupe key `share:{id}`). Today this is reached only through the demo ("Try the demo" in the Inbox); with a server it is called by the push/poll handler.

## 6. Routes

| Route | Screen |
|---|---|
| `/inbox` | Inbox (notifications) |
| `/s/:shareId` | Shared Scripture (deep-link target) |
| `/sharing/history` | Share history |
| `/sharing/privacy` | Sharing & privacy |
| `/people`, `/people/:userId` | People, public profile |

Card Studio and Send to someone are pushed with the `ShareScripture` object (not URL-addressable by design).

## 7. Entry points added

Home header (Inbox bell with unread badge), Profile ("Sharing & fellowship" group), Library ("Shared Scriptures" card), Discover ("From people you follow"), received-share screen ("Share this verse"), public profiles (share public activity). Existing share buttons in the reader, Daily Word and Library are unchanged and gain the new options through the shared sheet.
