import '../../data/models/user_profile.dart';

enum NotificationPermissionStatus { notDetermined, granted, denied, unsupported }

/// Local notification boundary (daily Scripture reminders).
///
/// Permission is only requested contextually — when the user turns a
/// reminder on — never automatically at first launch.
abstract interface class NotificationService {
  /// Whether this build can actually deliver notifications.
  bool get canDeliver;

  Future<NotificationPermissionStatus> permissionStatus();
  Future<NotificationPermissionStatus> requestPermission();
  Future<void> scheduleDailyReminder(ReminderTime time);
  Future<void> cancelDailyReminder();
}

/// Foundation V1 implementation: reminder preferences are stored, but
/// delivery is deferred until a local-notification plugin is integrated
/// (planned with the next milestone). The UI discloses this.
class DeferredNotificationService implements NotificationService {
  ReminderTime? _scheduled;

  ReminderTime? get scheduled => _scheduled;

  @override
  bool get canDeliver => false;

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => NotificationPermissionStatus.unsupported;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => NotificationPermissionStatus.unsupported;

  @override
  Future<void> scheduleDailyReminder(ReminderTime time) async => _scheduled = time;

  @override
  Future<void> cancelDailyReminder() async => _scheduled = null;
}
