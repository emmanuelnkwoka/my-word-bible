import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/bible/presentation/bible_home_screen.dart';
import '../features/bible/presentation/book_chapters_screen.dart';
import '../features/bible/presentation/reader_screen.dart';
import '../features/content/presentation/content_detail_screen.dart';
import '../features/creator/presentation/creator_screen.dart';
import '../features/daily_word/presentation/daily_word_history_screen.dart';
import '../features/daily_word/presentation/daily_word_screen.dart';
import '../features/daily_word/presentation/daily_word_settings_screen.dart';
import '../features/discovery/presentation/discover_screen.dart';
import '../features/discovery/presentation/topic_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/collection_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/library_section_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/personalisation/presentation/review_centre_screens.dart';
import '../features/profile/application/profile_controllers.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/info_screens.dart';
import '../features/social/application/social_providers.dart';
import '../features/social/domain/share_links.dart';
import '../features/social/presentation/inbox_screen.dart';
import '../features/social/presentation/people_screens.dart';
import '../features/social/presentation/share_history_screen.dart';
import '../features/social/presentation/shared_scripture_screen.dart';
import '../features/social/presentation/sharing_privacy_screen.dart';
import '../features/settings/presentation/settings_screens.dart';
import '../features/upload/presentation/upload_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects when onboarding status changes, without
  // rebuilding the router itself.
  final onboarded = ValueNotifier<bool>(ref.read(onboardingCompleteProvider));
  ref.listen<bool>(onboardingCompleteProvider, (_, next) => onboarded.value = next);
  ref.onDispose(onboarded.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final pending = ref.read(pendingShareLinkProvider);
      if (!onboarded.value) {
        // A shared-Scripture link opened before onboarding: keep it (and its
        // attribution) and open it once onboarding is complete.
        final shareId = ShareLinkCodec.parse(Uri(path: state.matchedLocation));
        if (shareId != null) pending.save(shareId);
        return atOnboarding ? null : AppRoutes.onboarding;
      }
      if (atOnboarding) {
        final shareId = pending.take();
        return shareId == null ? AppRoutes.home : AppRoutes.sharedScripture(shareId);
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute(
        builder: (context, state, shell) => shell,
        navigatorContainerBuilder: (context, shell, children) => AppShell(navigationShell: shell, children: children),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bible,
                builder: (_, _) => const BibleHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'book/:bookId',
                    builder: (_, s) => BookChaptersScreen(bookId: s.pathParameters['bookId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.discover, builder: (_, _) => const DiscoverScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (_, _) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'section/:section',
                    builder: (_, s) => LibrarySectionScreen(section: s.pathParameters['section']!),
                  ),
                  GoRoute(
                    path: 'collection/:id',
                    builder: (_, s) => CollectionScreen(collectionId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(path: 'personal', builder: (_, _) => const PersonalInfoScreen()),
                  GoRoute(path: 'appearance', builder: (_, _) => const AppearanceScreen()),
                  GoRoute(path: 'reading', builder: (_, _) => const ReadingSettingsScreen()),
                  GoRoute(path: 'daily-word', builder: (_, _) => const DailyWordSettingsScreen()),
                  GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
                  GoRoute(path: 'content', builder: (_, _) => const ContentPreferencesScreen()),
                  GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
                  GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
                  GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
                  GoRoute(path: 'help', builder: (_, _) => const HelpScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      // Root-level routes: full screen, reachable from any tab.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/read/:bookId/:chapter',
        builder: (_, s) => ReaderScreen(
          bookId: s.pathParameters['bookId']!.toUpperCase(),
          chapter: int.tryParse(s.pathParameters['chapter']!) ?? 1,
          focusVerse: int.tryParse(s.uri.queryParameters['v'] ?? ''),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/daily-word',
        builder: (_, s) => DailyWordScreen(dateKey: s.uri.queryParameters['d']),
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'history',
            builder: (_, _) => const DailyWordHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/topic/:topicId',
        builder: (_, s) => TopicScreen(topicId: s.pathParameters['topicId']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/content/:id',
        builder: (_, s) => ContentDetailScreen(contentId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/creator/:id',
        builder: (_, s) => CreatorScreen(creatorId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/search',
        pageBuilder: (_, s) => CustomTransitionPage(
          child: SearchScreen(initialQuery: s.uri.queryParameters['q']),
          transitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: AppRoutes.upload, builder: (_, _) => const UploadScreen()),
      // Scripture sharing & fellowship.
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: AppRoutes.inbox, builder: (_, _) => const InboxScreen()),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/s/:shareId',
        builder: (_, s) => SharedScriptureScreen(shareId: s.pathParameters['shareId']!),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.shareHistory,
        builder: (_, _) => const ShareHistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.sharingPrivacy,
        builder: (_, _) => const SharingPrivacyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.people,
        builder: (_, _) => const PeopleScreen(),
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: ':userId',
            builder: (_, s) => PersonScreen(userId: s.pathParameters['userId']!),
          ),
        ],
      ),
      // Supervisor review centre (reviewer builds).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.review,
        builder: (_, _) => const ReviewCentreScreen(),
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'book/:edition/:bookId',
            builder: (_, s) => ReviewBookScreen(edition: s.pathParameters['edition']!, bookId: s.pathParameters['bookId']!),
          ),
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'chapter/:edition/:bookId/:chapter',
            builder: (_, s) => ReviewChapterScreen(
              edition: s.pathParameters['edition']!,
              bookId: s.pathParameters['bookId']!,
              chapter: int.tryParse(s.pathParameters['chapter']!) ?? 1,
            ),
          ),
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'proposal/:edition/:id',
            builder: (_, s) => ReviewProposalScreen(edition: s.pathParameters['edition']!, ruleId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
