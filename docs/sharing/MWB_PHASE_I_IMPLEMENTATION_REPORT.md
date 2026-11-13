# Phase I Implementation Report: Scripture Sharing & Christian Social Connection Engine

Date: 13 November 2026 · Build: debug APK, Flutter 3.47.0 · Device: Xiaomi M2101K7BG (Android 11)

The theological review package was not touched: no change to `assets/mwb/**`, review exports, KJV/WEB text or personalisation records.

## 1. Before and after

| Capability | Before Phase I | After Phase I |
|---|---|---|
| Share one verse / several verses / range / chapter from the reader | ✔ quick-share sheet | ✔ **unchanged**, plus extras |
| Daily Word, Home, Library saved-verse sharing | ✔ | ✔ unchanged, plus extras |
| Auto-composed branded images, Portrait/Square/Story | ✔ | ✔ unchanged (Classic in Studio is byte-identical, tested) |
| Pagination, never truncating | ✔ | ✔ same algorithm, now shared by every design |
| Native Android share sheet (WhatsApp, Telegram, email…) | ✔ | ✔ unchanged service; also used as fallback everywhere |
| Share as text | ✔ | ✔ unchanged |
| Offline image generation | ✔ | ✔ (verified in airplane mode) |
| Premium designs | ✗ | ✔ 8 designs × 3 colourways + Classic |
| Landscape 1920×1080 | ✗ | ✔ (Studio) |
| Typography, size, alignment, colour, reference placement, decoration, sender line, personal note, branding toggle | ✗ | ✔ |
| Save to Photos (PNG/JPG + quality), save to a folder | ✗ | ✔ Android |
| Destination-aware export (WhatsApp Status/chat, Instagram Story/post/square, Facebook post/Story, Telegram) | ✗ | ✔ Android hand-off; caption sent or copied |
| Send to an MWB user | ✗ | ✔ local, demo community, honest status |
| Inbox / notifications | ✗ | ✔ local records |
| Follow, followers, public profiles, Discover activity | ✗ | ✔ local |
| Care & encouragement | ✗ | ✔ |
| Block, report, sharing privacy | ✗ | ✔ local |
| Share history (sent, received, saved, opened links, responses) | ✗ | ✔ |
| Share links / deep links | ✗ | ✔ app scheme on device; https needs domain verification |

Nothing was removed or renamed. `ShareService` (native share sheet) keeps its interface; its implementation now labels `.jpg` files as `image/jpeg`. `ScriptureImageComposer.plan` output is unchanged; its algorithm moved into the public `paginate` so new designs reuse it.

## 2. Status by capability

| Capability | Status |
|---|---|
| Card Studio, rendering, PNG/JPG, gallery, Save-as, app hand-off, quick-share extras | **Working** (Android) |
| Direct sharing, inbox, follows, blocks, reports, history, privacy, care | **Local mock** (on-device data; 7 invented demo people; simulated delivery clearly labelled) |
| Remote user directory, delivery, notifications, follow sync, acknowledgements reaching others, public link resolution | **API-ready** (interfaces + `MWB_BACKEND_API_CONTRACT.md`), **not connected** |
| https App Links / iOS Universal Links, web preview page, push notifications, deferred deep link after install | **Needs infrastructure** |
| Instagram/Facebook direct-to-Story intents (Meta App ID), QR codes on cards, user photo backgrounds, prayer requests/circles UI, iOS native save | **Not implemented** |

## 3. Screens

Created: Card Studio · Send to someone (find + compose) · Inbox · Shared Scripture (`/s/:id`) · Share history · People · Public profile · Sharing & privacy · "Try the demo" sheet · "Which WhatsApp?" picker.
Enhanced: quick-share sheet ("More ways to share", inline save confirmation) · Home (Inbox bell + badge) · Profile ("Sharing & fellowship") · Library ("Shared Scriptures") · Discover ("From people you follow") · Reader (canonical sources passed to sharing).

## 4. Files

New:
`lib/data/models/social.dart` · `lib/data/repositories/social_repositories.dart` ·
`lib/features/share/studio/{card_design,card_studio_renderer,card_studio_screen}.dart` ·
`lib/features/share/export/{card_export,card_export_flow}.dart` ·
`lib/features/social/domain/share_links.dart` · `lib/features/social/application/social_providers.dart` ·
`lib/features/social/presentation/{social_widgets,send_scripture_screen,inbox_screen,shared_scripture_screen,share_history_screen,people_screens,sharing_privacy_screen}.dart` ·
`android/app/src/main/res/xml/mwb_card_paths.xml` ·
`test/sharing/{sharing_test_support,card_studio_test,social_repositories_test,sharing_flow_test}.dart` ·
`docs/sharing/MWB_*.md` (8 documents).

Modified:
`lib/features/share/{scripture_image_composer,scripture_share_sheet,share_service}.dart` · `lib/app/{app_providers,app_router,routes}.dart` · `lib/core/constants/storage_keys.dart` · `lib/features/bible/presentation/reader_screen.dart` · `lib/features/home/presentation/home_screen.dart` · `lib/features/profile/presentation/profile_screen.dart` · `lib/features/library/presentation/library_screen.dart` · `lib/features/discovery/presentation/discover_screen.dart` · `android/app/src/main/AndroidManifest.xml` · `android/app/src/main/kotlin/.../MainActivity.kt` · `pubspec.yaml`/`pubspec.lock` (+`image`).

## 5. Models and repositories

Models: `PublicProfile`, `PublicScriptureActivity`, `SocialIdentity`, `SocialPrivacySettings`, `CareIntent`, `PrayerRequest`, `ScriptureShare`, `SharedVerse`, `ShareDraft`, `ShareAcknowledgement`, `DeliveryStatus`, `SharePrivacy`, `OpenedShareLink`, `InAppNotification`, `NotificationCategory`, `SafetyReport`, `CardDesign`, `CardTemplate`, `CardColorway`, `ShareDestination`, `ShareApp`, `CardFileType`, `PublicShareMetadata`.
Repositories (interface → local): `SocialSettingsRepository`, `UserDirectoryRepository` (`DemoUserDirectory`), `ScriptureShareRepository`, `NotificationRepository`, `FollowRepository`, `SafetyRepository`; services `CardExportService` (`PlatformCardExportService`); domain `SharePolicy`, `ShareLinkCodec`, `ShareLinkResolver`, `PendingShareLinkStore`.

## 6. Verification

- `flutter analyze`: **No issues found.**
- `flutter test`: **360 passing** (306 existing, unchanged and passing; 54 new: 19 Card Studio, 23 repository/domain, 12 end-to-end widget flows).
- New tests cover: single/multiple verses, whole chapter (Psalm 119) in every design × format with every word kept and no page overflowing, long verse split, translation integrity, readable-colour rules, PNG/JPG output and dimensions, Classic = quick share (byte-identical), recipient search (username, @, ID, name, private, blocked, injected IDs), canonical snapshot (never `KJV-MWB`), recipient policy, simulated vs awaiting delivery, idempotent delivery, received-share dedupe, notification persistence/dedupe, follow/unfollow, blocked restrictions, incoming audience rules, link parsing, private-share access, public metadata privacy, onboarding link recovery, quick-share regression, Studio → WhatsApp hand-off, two-WhatsApp picker, JPG save, send flow, inbox/receive/save/thank/follow, never auto-following, all 7 themes × light/dark for the new screens.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, **210 MB** (debug; includes the bundled Bibles and corpus).

## 7. Physical device (Xiaomi M2101K7BG, Android 11)

| Test | Result |
|---|---|
| App scheme link `mywordbible://app/s/{id}` (cold start) | ✔ opened `/s/{id}` → "Not on this device" (correct: no server) |
| https link, explicit to package (warm) | ✔ delivered to the app. Domain status `ask` (unverified, expected) |
| Quick share: preview, formats, extras | ✔ unchanged + extras |
| Save image (PNG) to Photos | ✔ `Pictures/My Word Bible/…ephesians-3-20.png`, 1080×1350, `image/png` (MediaStore) |
| Studio JPG (quality 92) to Photos | ✔ 1080×1920, `image/jpeg`, 218 KB |
| Save to a folder… | ✔ system picker → `Download/…ephesians-3-20.jpg` |
| WhatsApp Status hand-off | ✔ WhatsApp Business opened "Send to…" with **My status** at the top and the 1080×1920 card. Nothing was posted (user decision) |
| Two WhatsApps installed | Found on device: plain WhatsApp is not registered. **Fixed**: the app now asks "Which WhatsApp?" |
| Send to someone (demo) | ✔ "Sent in the demo … no one else received it" |
| Airplane mode: demo receive, open, save, thank, re-share, save image | ✔ all offline |
| Instagram / Facebook | Not installed on the device: hand-off untested on hardware; fallback to the share sheet is tested |
| Telegram hand-off | Uses the same verified mechanism; not separately run on the device |
| Emulator | Not run (no emulator running; physical device used) |

Fixes made after device testing: inline save confirmation in the quick-share sheet (the snackbar was hidden behind the sheet); "Which WhatsApp?" picker; consistent avatar colours in the inbox.

Left on the test phone: test images in `Pictures/My Word Bible` (4) and one JPG in `Download`; demo share/notification records inside the app's own storage (Settings → clear data removes them).

## 8. Remaining issues

1. The screen-wide grey overlay on this phone (noted in the previous phase) also tints these screenshots; app colours are correct.
2. The quick-share "Share link" option explains that links aren't live yet: the link service, assetlinks.json (release key) and apple-app-site-association are needed.
3. iOS: no native save/hand-off channel; falls back to the iOS share sheet; not built or tested (Windows host).
4. Debug APK size (210 MB) is dominated by bundled data; a release build with `--split-per-abi` will be much smaller.

## 9. Recommended next phase

1. **MWB accounts + sharing service** per the API contract (auth, user directory, shares, notifications, follows, blocks), then switch providers to remote implementations (`isLive: true`).
2. **Domain association and web preview page** for `https://mywordbible.com/s/{id}`; verify App Links on device.
3. **Push notifications** (FCM/APNs) with privacy-safe payloads.
4. Prayer requests and prayer circles on the existing care foundations; moderation queue for reports.
5. iOS native save/hand-off, optional user photo backgrounds and QR codes once links are live.
