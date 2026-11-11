import '../../core/constants/storage_keys.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/theme/mwb_themes.dart';
import '../models/user_profile.dart';

/// Appearance mode choice. Kept separate from Flutter's ThemeMode so the
/// persisted value is owned by MWB.
enum AppearanceMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const AppearanceMode(this.label);
  final String label;
}

/// User profile, onboarding status and preferences.
abstract interface class PreferencesRepository {
  bool get onboardingComplete;
  Future<void> setOnboardingComplete(bool value);

  UserProfile? loadProfile();
  Future<void> saveProfile(UserProfile profile);

  Set<String> loadInterests();
  Future<void> saveInterests(Set<String> interestIds);

  ReadingPreferences loadReading();
  Future<void> saveReading(ReadingPreferences prefs);

  DailyExperience loadDailyExperience();
  Future<void> saveDailyExperience(DailyExperience value);

  NotificationPreferences loadNotifications();
  Future<void> saveNotifications(NotificationPreferences value);

  MwbThemeId loadThemeId();
  Future<void> saveThemeId(MwbThemeId id);

  AppearanceMode loadAppearanceMode();
  Future<void> saveAppearanceMode(AppearanceMode mode);

  /// Clears onboarding and personal preferences (appearance is kept).
  Future<void> resetOnboarding();
}

class LocalPreferencesRepository implements PreferencesRepository {
  LocalPreferencesRepository(this._store);

  final KeyValueStore _store;

  Map<String, dynamic>? _map(String key) {
    final j = _store.readJson(key);
    return j is Map<String, dynamic> ? j : null;
  }

  @override
  bool get onboardingComplete => _store.getBool(StorageKeys.onboardingComplete) ?? false;

  @override
  Future<void> setOnboardingComplete(bool value) => _store.setBool(StorageKeys.onboardingComplete, value);

  @override
  UserProfile? loadProfile() {
    final m = _map(StorageKeys.userProfile);
    return m == null ? null : UserProfile.fromJson(m);
  }

  @override
  Future<void> saveProfile(UserProfile profile) => _store.writeJson(StorageKeys.userProfile, profile.toJson());

  @override
  Set<String> loadInterests() {
    final j = _store.readJson(StorageKeys.interests);
    return j is List ? j.whereType<String>().toSet() : <String>{};
  }

  @override
  Future<void> saveInterests(Set<String> interestIds) => _store.writeJson(StorageKeys.interests, interestIds.toList());

  @override
  ReadingPreferences loadReading() {
    final m = _map(StorageKeys.readingPreferences);
    return m == null ? const ReadingPreferences() : ReadingPreferences.fromJson(m);
  }

  @override
  Future<void> saveReading(ReadingPreferences prefs) =>
      _store.writeJson(StorageKeys.readingPreferences, prefs.toJson());

  @override
  DailyExperience loadDailyExperience() {
    final m = _map(StorageKeys.dailyExperience);
    return m == null ? const DailyExperience() : DailyExperience.fromJson(m);
  }

  @override
  Future<void> saveDailyExperience(DailyExperience value) =>
      _store.writeJson(StorageKeys.dailyExperience, value.toJson());

  @override
  NotificationPreferences loadNotifications() {
    final m = _map(StorageKeys.notificationPreferences);
    return m == null ? const NotificationPreferences() : NotificationPreferences.fromJson(m);
  }

  @override
  Future<void> saveNotifications(NotificationPreferences value) =>
      _store.writeJson(StorageKeys.notificationPreferences, value.toJson());

  @override
  MwbThemeId loadThemeId() => MwbThemeId.fromStorageKey(_store.getString(StorageKeys.themeId));

  @override
  Future<void> saveThemeId(MwbThemeId id) => _store.setString(StorageKeys.themeId, id.storageKey);

  @override
  AppearanceMode loadAppearanceMode() =>
      AppearanceMode.values.asNameMap()[_store.getString(StorageKeys.themeMode)] ?? AppearanceMode.system;

  @override
  Future<void> saveAppearanceMode(AppearanceMode mode) => _store.setString(StorageKeys.themeMode, mode.name);

  @override
  Future<void> resetOnboarding() async {
    await _store.remove(StorageKeys.onboardingComplete);
    await _store.remove(StorageKeys.userProfile);
    await _store.remove(StorageKeys.interests);
    await _store.remove(StorageKeys.readingPreferences);
    await _store.remove(StorageKeys.dailyExperience);
    await _store.remove(StorageKeys.notificationPreferences);
  }
}
