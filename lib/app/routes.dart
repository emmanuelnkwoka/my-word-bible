/// Route paths. Centralised so features never hardcode locations.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';

  // Primary tabs.
  static const home = '/home';
  static const bible = '/bible';
  static const discover = '/discover';
  static const library = '/library';
  static const profile = '/profile';

  // Bible.
  static String book(String bookId) => '/bible/book/$bookId';

  /// Full-screen reader (root navigator) so it can be opened from any tab.
  static String reader(String bookId, int chapter, {int? verse}) =>
      '/read/$bookId/$chapter${verse == null ? '' : '?v=$verse'}';

  // Discovery and content (root navigator).
  static String topic(String topicId) => '/topic/$topicId';
  static String content(String contentId) => '/content/$contentId';
  static String creator(String creatorId) => '/creator/$creatorId';
  static const upload = '/upload';
  static String search({String? query}) =>
      query == null || query.isEmpty ? '/search' : '/search?q=${Uri.encodeQueryComponent(query)}';

  // Library.
  static String librarySection(String section) => '/library/section/$section';
  static String collection(String id) => '/library/collection/$id';

  // Profile & settings.
  static const personalInfo = '/profile/personal';
  static const appearance = '/profile/appearance';
  static const readingSettings = '/profile/reading';
  static const notifications = '/profile/notifications';
  static const contentPreferences = '/profile/content';
  static const privacy = '/profile/privacy';
  static const account = '/profile/account';
  static const about = '/profile/about';
  static const help = '/profile/help';
}
