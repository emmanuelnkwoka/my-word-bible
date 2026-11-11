import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/services/notification_service.dart';
import '../core/storage/key_value_store.dart';
import '../core/storage/token_storage.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/bible_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/search_repository.dart';
import '../features/audio/application/audio_playback_service.dart';

/// Composition root. Every dependency is a provider so tests and future
/// remote implementations can override it without touching features.

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// Overridden in `main.dart` with the initialised SharedPreferences store.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider must be overridden at start-up'),
);

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

/// Incremented when the API reports 401 so session-aware UI can react.
final unauthorizedEventsProvider = NotifierProvider<UnauthorizedEvents, int>(UnauthorizedEvents.new);

class UnauthorizedEvents extends Notifier<int> {
  @override
  int build() => 0;
  void signal() => state++;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    onUnauthorized: () => ref.read(unauthorizedEventsProvider.notifier).signal(),
  );
});

final bibleRepositoryProvider = Provider<BibleRepository>((ref) => AssetBibleRepository());

/// Original translations and MWB editions, with licensing and source links.
final versionCatalogueProvider = Provider<VersionCatalogue>(
  (ref) => VersionCatalogue(ref.watch(bibleRepositoryProvider).versions),
);

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.isMock ? MockContentRepository() : RemoteContentRepository(ref.watch(apiClientProvider));
});

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LocalLibraryRepository(ref.watch(keyValueStoreProvider)),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => LocalPreferencesRepository(ref.watch(keyValueStoreProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => LocalSearchRepository(ref.watch(bibleRepositoryProvider), ref.watch(contentRepositoryProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokens = ref.watch(tokenStorageProvider);
  return config.isMock ? DeviceOnlyAuthRepository(tokens) : RemoteAuthRepository(ref.watch(apiClientProvider), tokens);
});

final notificationServiceProvider = Provider<NotificationService>((ref) => DeferredNotificationService());

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = JustAudioPlaybackService();
  ref.onDispose(service.dispose);
  return service;
});
