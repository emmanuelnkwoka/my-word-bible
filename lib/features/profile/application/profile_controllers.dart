import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/interest.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/preferences_repository.dart';

/// Whether onboarding has been completed. Drives routing.
final onboardingCompleteProvider = NotifierProvider<OnboardingCompleteController, bool>(
  OnboardingCompleteController.new,
);

class OnboardingCompleteController extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesRepositoryProvider).onboardingComplete;

  Future<void> set(bool value) async {
    await ref.read(preferencesRepositoryProvider).setOnboardingComplete(value);
    state = value;
  }
}

final userProfileProvider = NotifierProvider<UserProfileController, UserProfile?>(UserProfileController.new);

class UserProfileController extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => ref.watch(preferencesRepositoryProvider).loadProfile();

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref.read(preferencesRepositoryProvider).saveProfile(profile);
  }
}

final interestsProvider = NotifierProvider<InterestsController, Set<String>>(InterestsController.new);

class InterestsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(preferencesRepositoryProvider).loadInterests();

  Future<void> save(Set<String> ids) async {
    state = Set.unmodifiable(ids);
    await ref.read(preferencesRepositoryProvider).saveInterests(ids);
  }

  Future<void> toggle(String id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    return save(next);
  }
}

/// Topic ids implied by the user's interests (empty → no personalisation).
final interestTopicIdsProvider = Provider<Set<String>>((ref) {
  final interests = ref.watch(interestsProvider);
  final daily = ref.watch(dailyExperienceProvider);
  if (!daily.personalisedDiscovery) return const {};
  return topicIdsForInterests(interests);
});

final readingPreferencesProvider = NotifierProvider<ReadingPreferencesController, ReadingPreferences>(
  ReadingPreferencesController.new,
);

class ReadingPreferencesController extends Notifier<ReadingPreferences> {
  @override
  ReadingPreferences build() => ref.watch(preferencesRepositoryProvider).loadReading();

  Future<void> save(ReadingPreferences prefs) async {
    state = prefs;
    await ref.read(preferencesRepositoryProvider).saveReading(prefs);
  }

  Future<void> update(ReadingPreferences Function(ReadingPreferences) change) => save(change(state));
}

final dailyExperienceProvider = NotifierProvider<DailyExperienceController, DailyExperience>(
  DailyExperienceController.new,
);

class DailyExperienceController extends Notifier<DailyExperience> {
  @override
  DailyExperience build() => ref.watch(preferencesRepositoryProvider).loadDailyExperience();

  Future<void> save(DailyExperience value) async {
    state = value;
    await ref.read(preferencesRepositoryProvider).saveDailyExperience(value);
    final notifications = ref.read(notificationServiceProvider);
    if (value.reminderEnabled) {
      await notifications.scheduleDailyReminder(value.reminderTime);
    } else {
      await notifications.cancelDailyReminder();
    }
  }

  Future<void> update(DailyExperience Function(DailyExperience) change) => save(change(state));

  /// Turns the reminder on, asking for notification permission in context.
  Future<NotificationPermissionStatus> enableReminder() async {
    final status = await ref.read(notificationServiceProvider).requestPermission();
    await update((d) => d.copyWith(reminderEnabled: true));
    return status;
  }
}

final notificationPreferencesProvider = NotifierProvider<NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);

class NotificationPreferencesController extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() => ref.watch(preferencesRepositoryProvider).loadNotifications();

  Future<void> save(NotificationPreferences value) async {
    state = value;
    await ref.read(preferencesRepositoryProvider).saveNotifications(value);
  }
}

/// Current account session (guest in Foundation V1).
final sessionProvider = FutureProvider<SessionState>((ref) {
  ref.watch(unauthorizedEventsProvider);
  return ref.watch(authRepositoryProvider).currentSession();
});

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);

/// Cross-cutting profile operations.
class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  /// Resets onboarding and personal preferences; the router then shows
  /// onboarding again. Appearance and library data are kept.
  Future<void> resetOnboarding() async {
    final PreferencesRepository repo = _ref.read(preferencesRepositoryProvider);
    await repo.resetOnboarding();
    await _ref.read(notificationServiceProvider).cancelDailyReminder();
    _ref.invalidate(userProfileProvider);
    _ref.invalidate(interestsProvider);
    _ref.invalidate(readingPreferencesProvider);
    _ref.invalidate(dailyExperienceProvider);
    _ref.invalidate(notificationPreferencesProvider);
    await _ref.read(onboardingCompleteProvider.notifier).set(false);
  }
}
