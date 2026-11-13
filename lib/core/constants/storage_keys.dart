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

  /// Whether the MWB reviewer preview is switched on (reviewer-capable builds only).
  static const mwbReviewerMode = 'mwb.v1.mwb_reviewer_mode';

  /// Daily Word: delivered words, settings and local relevance signals.
  static const dailyWordHistory = 'mwb.v1.daily_word_history';
  static const dailyWordSettings = 'mwb.v1.daily_word_settings';
  static const dailyWordSignals = 'mwb.v1.daily_word_signals';

  /// Scripture sharing & social connection (Phase I), all on this device.
  static const socialIdentity = 'mwb.v1.social_identity';
  static const socialPrivacy = 'mwb.v1.social_privacy';
  static const socialShares = 'mwb.v1.social_shares';
  static const socialNotifications = 'mwb.v1.social_notifications';
  static const socialFollowing = 'mwb.v1.social_following';
  static const socialFollowers = 'mwb.v1.social_followers';
  static const socialBlocked = 'mwb.v1.social_blocked';
  static const socialReports = 'mwb.v1.social_reports';
  static const socialKnownPeople = 'mwb.v1.social_known_people';
  static const socialOpenedLinks = 'mwb.v1.social_opened_links';
  static const socialRecentRecipients = 'mwb.v1.social_recent_recipients';
  static const pendingShareLink = 'mwb.v1.pending_share_link';
  static const cardStudioLast = 'mwb.v1.card_studio_last';

  /// Secure storage (Keychain / Android Keystore) keys.
  static const secureAccessToken = 'mwb.secure.access_token';
  static const secureRefreshToken = 'mwb.secure.refresh_token';
}
