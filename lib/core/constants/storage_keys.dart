/// Keys used for local persistence. Versioned so formats can evolve safely.
abstract final class StorageKeys {
  static const onboardingComplete = 'mwb.v1.onboarding_complete';
  static const userProfile = 'mwb.v1.user_profile';
  static const interests = 'mwb.v1.interests';
  static const readingPreferences = 'mwb.v1.reading_preferences';
  static const dailyExperience = 'mwb.v1.daily_experience';
  static const notificationPreferences = 'mwb.v1.notification_preferences';

  static const themeId = 'mwb.v1.theme_id';
  static const themeMode = 'mwb.v1.theme_mode';

  static const bookmarks = 'mwb.v1.bookmarks';
  static const highlights = 'mwb.v1.highlights';
  static const notes = 'mwb.v1.notes';
  static const savedScripture = 'mwb.v1.saved_scripture';
  static const savedContent = 'mwb.v1.saved_content';
  static const readingHistory = 'mwb.v1.reading_history';
  static const recentlyViewed = 'mwb.v1.recently_viewed';
  static const collections = 'mwb.v1.collections';
  static const recentSearches = 'mwb.v1.recent_searches';
  static const uploadDrafts = 'mwb.v1.upload_drafts';
  static const contentReports = 'mwb.v1.content_reports';

  /// Secure storage (Keychain / Android Keystore) keys.
  static const secureAccessToken = 'mwb.secure.access_token';
  static const secureRefreshToken = 'mwb.secure.refresh_token';
}
