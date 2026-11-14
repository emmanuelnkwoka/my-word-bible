import '../data/models/personal_rhythm.dart';
import '../data/models/scripture_reference.dart';

/// Route paths. Centralised so features never hardcode locations.
abstract final class AppRoutes {
  // Personal Word Rhythm and private reflections (F1, root navigator).
  static const rhythm = '/rhythm';
  static const journal = '/journal';
  static String journalEntry(String id) => '/journal/e/$id';
  static String newReflection({
    ScriptureReference? reference,
    String? versionId,
    PersonalOrigin source = PersonalOrigin.independent,
    String? dailyWordDate,
  }) {
    final q = <String, String>{
      if (reference != null) 'r': encodeReference(reference),
      'v': ?versionId,
      'src': source.name,
      'dw': ?dailyWordDate,
    };
    return Uri(path: '/journal/new', queryParameters: q).toString();
  }

  static const journalPrivacy = '/profile/journal';

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

  // Daily Word (root navigator).
  static String dailyWord([String? dateKey]) => dateKey == null ? '/daily-word' : '/daily-word?d=$dateKey';
  static const dailyWordHistory = '/daily-word/history';

  // Personalisation review centre (reviewer builds).
  static const review = '/review';
  static String reviewBook(String edition, String bookId) => '/review/book/$edition/$bookId';
  static String reviewChapter(String edition, String bookId, int chapter) =>
      '/review/chapter/$edition/$bookId/$chapter';
  static String reviewProposal(String edition, String id) => '/review/proposal/$edition/${Uri.encodeComponent(id)}';

  // Scripture sharing & fellowship (root navigator).
  static const inbox = '/inbox';
  static String sharedScripture(String shareId) => '/s/$shareId';
  static const shareHistory = '/sharing/history';
  static const people = '/people';
  static String person(String userId) => '/people/$userId';
  static const sharingPrivacy = '/sharing/privacy';

  // Library.
  static String librarySection(String section) => '/library/section/$section';
  static String collection(String id) => '/library/collection/$id';

  // Profile & settings.
  static const personalInfo = '/profile/personal';
  static const appearance = '/profile/appearance';
  static const readingSettings = '/profile/reading';
  static const dailyWordSettings = '/profile/daily-word';
  static const notifications = '/profile/notifications';
  static const contentPreferences = '/profile/content';
  static const privacy = '/profile/privacy';
  static const account = '/profile/account';
  static const about = '/profile/about';
  static const help = '/profile/help';
}
