# F1b: Personal Word Rhythm Reminders (planned, not implemented)

Status: **documented only.** As directed, F1 shipped without reminders, so reminders did not delay it.

## Current state [FACT]

- `NotificationService` (`lib/core/services/notification_service.dart`) is implemented by `DeferredNotificationService`. It reports `canDeliver == false` and delivers nothing.
- Reminder preferences already exist and are stored: `DailyExperience.reminderEnabled` and `reminderTime`, and `NotificationPreferences.readingGoalNudges`, which is off by default.
- No local-notification plugin is installed.

## Proposal

1. **Add `flutter_local_notifications`.** This is a new package and needs approval before it is added.
2. **Implement `LocalNotificationService` behind the existing `NotificationService` interface**, and swap it in at `notificationServiceProvider`. No other code changes.
3. **One optional daily reminder:**
   - at the time the user chose;
   - inexact scheduling, so the exact-alarm permission is not needed;
   - the Android 13+ notification permission is requested only when the user switches the reminder on.
4. **Reminder text is fixed, gentle and contains no personal data.** For example: "A quiet moment in the Word, whenever you're ready."
   - It never mentions missed days, counts or streaks.
   - It never contains reflection text.
5. **Tapping the reminder opens Word rhythm.** It records nothing.
6. **Tests:**
   - the schedule is created and cancelled with the setting;
   - permission is asked in context, never at launch;
   - the payload is free of personal data;
   - no reminder is scheduled when the setting is off.

## Decisions needed

- Approve `flutter_local_notifications`.
- Approve the reminder wording.
- Decide whether reminders also follow Daily Word delivery, or stay a single Rhythm reminder.
