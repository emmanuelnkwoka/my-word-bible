import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/app/app.dart';
import 'package:my_word_bible/app/app_providers.dart';
import 'package:my_word_bible/core/config/app_config.dart';
import 'package:my_word_bible/core/constants/storage_keys.dart';
import 'package:my_word_bible/core/network/api_client.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/storage/token_storage.dart';
import 'package:my_word_bible/data/local/personal_database.dart';
import 'package:my_word_bible/data/models/user_profile.dart';
import 'package:my_word_bible/data/repositories/bible_repository.dart';
import 'package:my_word_bible/data/repositories/content_repository.dart';
import 'package:my_word_bible/data/repositories/daily_word_repository.dart';
import 'package:my_word_bible/data/repositories/intelligence_repository.dart';
import 'package:my_word_bible/data/repositories/mwb_presentation_repository.dart';
import 'package:my_word_bible/data/repositories/mwb_ruleset_repository.dart';
import 'package:my_word_bible/data/repositories/passage_context_repository.dart';
import 'package:my_word_bible/features/audio/application/audio_playback_service.dart';
import 'package:my_word_bible/features/bible/application/bible_providers.dart';
import 'package:my_word_bible/features/fellowship/application/personal_providers.dart';
import 'package:my_word_bible/features/personalisation/application/personalisation_providers.dart';

/// Raw KJV text, read once. Widget tests each get their own repository so
/// futures are created inside that test's fake-async zone.
final _kjvRaw = File('assets/bible/kjv.json').readAsStringSync();
final _webRaw = File('assets/bible/web.json').readAsStringSync();

/// Reads bundled assets from disk by path, as the app's asset bundle would.
Future<String> readTestAsset(String path) async => switch (path) {
  'assets/bible/kjv.json' => _kjvRaw,
  'assets/bible/web.json' => _webRaw,
  _ => File(path).readAsStringSync(),
};

AssetBibleRepository newTestBible() => AssetBibleRepository(loader: readTestAsset, parseInBackground: false);

/// Shared instance for plain (non-widget) unit tests.
final sharedTestBible = newTestBible();

final fixedNow = DateTime(2026, 11, 10, 8, 30);

/// Store representing a user who has completed onboarding.
InMemoryKeyValueStore onboardedStore({String name = 'Grace'}) {
  final store = InMemoryKeyValueStore({StorageKeys.onboardingComplete: true});
  store.writeJson(StorageKeys.userProfile, UserProfile(firstName: name, gender: GenderPreference.female).toJson());
  store.writeJson(StorageKeys.interests, ['faith', 'prayer']);
  return store;
}

/// [personalStore] replaces the default in-memory F1 personal store.
List<Override> testOverrides(KeyValueStore store, {Future<PersonalStoreStatus> Function()? personalStore}) => [
  keyValueStoreProvider.overrideWithValue(store),
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
  bibleRepositoryProvider.overrideWithValue(newTestBible()),
  contentRepositoryProvider.overrideWithValue(MockContentRepository(latency: Duration.zero)),
  audioPlaybackServiceProvider.overrideWithValue(SimulatedAudioPlaybackService()),
  clockProvider.overrideWithValue(() => fixedNow),
  mwbRulesetRepositoryProvider.overrideWithValue(AssetMwbRulesetRepository(loader: readTestAsset)),
  passageContextRepositoryProvider.overrideWithValue(AssetPassageContextRepository(loader: readTestAsset)),
  intelligenceRepositoryProvider.overrideWithValue(
    AssetIntelligenceRepository(loader: readTestAsset, parseInBackground: false),
  ),
  dailyWordRepositoryProvider.overrideWithValue(AssetDailyWordRepository(loader: readTestAsset)),
  mwbPresentationRepositoryProvider.overrideWithValue(AssetMwbPresentationRepository(loader: readTestAsset)),
  // F1: an in-memory personal store (encryption is tested separately against real SQLCipher files).
  personalStoreProvider.overrideWith((ref) async {
    if (personalStore != null) return personalStore();
    final db = PersonalDatabase.inMemory();
    ref.onDispose(db.close);
    return PersonalStoreReady(db);
  }),
];

ProviderContainer testContainer(KeyValueStore store, {List<Override> extra = const []}) {
  final c = ProviderContainer(overrides: [...testOverrides(store), ...extra]);
  addTearDown(c.dispose);
  return c;
}

/// Pumps the full application with test dependencies.
Future<void> pumpMwbApp(
  WidgetTester tester,
  KeyValueStore store, {
  Size size = const Size(400, 860),
  List<Override> extra = const [],
  Future<PersonalStoreStatus> Function()? personalStore,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(store, personalStore: personalStore),
        ...extra,
      ],
      child: const MwbApp(),
    ),
  );
  await settle(tester);
}

/// pumpAndSettle with a bounded number of frames (some screens keep a
/// progress indicator animating while loading).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The first on-stage vertical scrollable (skips text fields' internal ones).
Finder verticalScrollable() =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// Scrolls the first vertical scrollable until [finder] is visible.
Future<void> scrollTo(WidgetTester tester, Finder finder, {Finder? scrollable}) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: scrollable ?? verticalScrollable(), maxScrolls: 40);
  await settle(tester);
}

extension TapText on WidgetTester {
  Future<void> tapText(String text) async {
    await tap(find.text(text).first);
    await settle(this);
  }
}

/// API client in mock mode (never performs requests).
ApiClient throwingApiClient() => ApiClient(
  config: const AppConfig(dataSource: DataSourceMode.mock, apiBaseUrl: ''),
  tokenStorage: InMemoryTokenStorage(),
  onUnauthorized: () {},
);

Widget wrapForTest(Widget child, KeyValueStore store) => ProviderScope(overrides: testOverrides(store), child: child);

/// A dedicated reviewer build (`--dart-define=MWB_REVIEW_MODE=true`). Only
/// such builds offer the editorial review tools.
final reviewerBuild = <Override>[
  appConfigProvider.overrideWithValue(
    const AppConfig(dataSource: DataSourceMode.mock, apiBaseUrl: '', mwbReviewMode: true),
  ),
];
