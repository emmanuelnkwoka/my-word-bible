import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/app/app_router.dart';
import 'package:my_word_bible/app/routes.dart';
import 'package:my_word_bible/core/config/app_config.dart';
import 'package:my_word_bible/core/errors/app_failure.dart';
import 'package:my_word_bible/core/network/api_client.dart';
import 'package:my_word_bible/core/network/interceptors.dart';
import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/core/storage/token_storage.dart';
import 'package:my_word_bible/data/mock/mock_content.dart';
import 'package:my_word_bible/data/repositories/auth_repository.dart';
import 'package:my_word_bible/features/audio/application/audio_controller.dart';
import 'package:my_word_bible/features/upload/application/upload_validation.dart';
import 'package:my_word_bible/features/video/application/video_playback_controller.dart';
import 'package:my_word_bible/features/video/presentation/video_player_view.dart';

import 'helpers/test_app.dart';

DioException _err(DioExceptionType type, {int? status, Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  response: status == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: data,
        ),
);

/// Adapter that answers every request with a fixed status.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{"message":"nope"}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Network error mapping', () {
    test('transport errors', () {
      expect(mapDioException(_err(DioExceptionType.connectionTimeout)), isA<TimeoutFailure>());
      expect(mapDioException(_err(DioExceptionType.receiveTimeout)), isA<TimeoutFailure>());
      expect(mapDioException(_err(DioExceptionType.connectionError)), isA<NetworkFailure>());
      expect(mapDioException(_err(DioExceptionType.unknown)), isA<NetworkFailure>());
    });

    test('HTTP status codes follow Laravel conventions', () {
      expect(mapDioException(_err(DioExceptionType.badResponse, status: 401)), isA<UnauthorizedFailure>());
      expect(mapDioException(_err(DioExceptionType.badResponse, status: 403)), isA<ForbiddenFailure>());
      expect(mapDioException(_err(DioExceptionType.badResponse, status: 404)), isA<NotFoundFailure>());
      final v = mapDioException(
        _err(
          DioExceptionType.badResponse,
          status: 422,
          data: {
            'message': 'Invalid.',
            'errors': {
              'email': ['The email field is required.'],
            },
          },
        ),
      );
      expect(v, isA<ValidationFailure>());
      expect((v as ValidationFailure).fieldErrors['email'], 'The email field is required.');
      expect(mapDioException(_err(DioExceptionType.badResponse, status: 503)), isA<ServerFailure>());
    });

    test('mock mode never performs requests', () async {
      final api = throwingApiClient();
      await expectLater(api.get<Object>('/health'), throwsA(isA<FeatureUnavailableFailure>()));
    });

    test('remote mode attaches the token and handles 401 centrally', () async {
      final tokens = InMemoryTokenStorage();
      await tokens.write(const AuthTokens(accessToken: 'abc'));
      var unauthorized = 0;
      final adapter = _StatusAdapter(401);
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ApiClient(
        config: const AppConfig(dataSource: DataSourceMode.remote, apiBaseUrl: 'https://api.invalid'),
        tokenStorage: tokens,
        onUnauthorized: () => unauthorized++,
        dio: dio,
      );
      await expectLater(api.get<Object>('/me'), throwsA(isA<UnauthorizedFailure>()));
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer abc');
      expect(unauthorized, 1);
      expect(await tokens.read(), isNull, reason: 'session cleared on 401');
    });

    test('configuration defaults to mock mode', () {
      final config = AppConfig.fromEnvironment();
      expect(config.isMock, isTrue);
      expect(config.connectTimeout, const Duration(seconds: 15));
    });
  });

  group('Sessions and storage', () {
    test('device-only auth keeps the user as a guest and explains why', () async {
      final repo = DeviceOnlyAuthRepository(InMemoryTokenStorage());
      expect(repo.accountsAvailable, isFalse);
      expect((await repo.currentSession()).isSignedIn, isFalse);
      await expectLater(repo.signIn(email: 'a@b.co', password: 'password1'), throwsA(isA<FeatureUnavailableFailure>()));
    });

    test('key-value JSON helpers tolerate malformed entries', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('k', '[{"a":1},"bad",{"a":2}]');
      expect(store.readList('k', (j) => j['a'] as int), [1, 2]);
    });
  });

  group('Media playback', () {
    testWidgets('audio controller drives the shared player', (tester) async {
      final c = testContainer(onboardedStore());
      final item = mockContent.firstWhere((i) => i.id == 'a-fear-night');
      final sub = c.listen(audioControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final ctrl = c.read(audioControllerProvider.notifier);

      await ctrl.toggle(item);
      await tester.pump(const Duration(seconds: 2));
      var s = c.read(audioControllerProvider);
      expect(s.item!.id, item.id);
      expect(s.playing, isTrue);
      expect(s.position, greaterThan(Duration.zero));

      await ctrl.setSpeed(1.5);
      await ctrl.toggle(item);
      s = c.read(audioControllerProvider);
      expect(s.playing, isFalse);
      expect(s.speed, 1.5);

      await ctrl.seek(const Duration(seconds: 30));
      await ctrl.skip(const Duration(seconds: 60));
      expect(c.read(audioControllerProvider).position, const Duration(seconds: 48), reason: 'clamped to duration');

      await ctrl.stop();
      expect(c.read(audioControllerProvider).hasItem, isFalse);
    });

    testWidgets('simulated video controller plays, seeks and stops at the end', (tester) async {
      final v = SimulatedVideoPlaybackController(duration: const Duration(seconds: 2));
      addTearDown(v.dispose);
      v.play();
      expect(v.isPlaying, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(v.position, greaterThanOrEqualTo(const Duration(milliseconds: 750)));
      v.seek(const Duration(seconds: 10));
      expect(v.position, const Duration(seconds: 2));
      v.toggle();
      expect(v.isPlaying, isFalse);
      v.play();
      await tester.pump(const Duration(seconds: 3));
      expect(v.isPlaying, isFalse);
      expect(v.position, const Duration(seconds: 2));
    });

    testWidgets('audio and video detail screens expose working controls', (tester) async {
      await pumpMwbApp(tester, onboardedStore());
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = container.read(appRouterProvider);

      router.push(AppRoutes.content('a-fear-night'));
      await settle(tester);
      expect(find.text('When Fear Knocks at Night'), findsWidgets);
      expect(find.textContaining('original sample tone'), findsOneWidget);

      await tester.tap(find.byKey(const Key('audio.playPause')));
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(audioControllerProvider).playing, isTrue);
      expect(find.bySemanticsLabel('Pause'), findsWidgets);

      await tester.tap(find.byKey(const Key('audio.playPause')));
      await settle(tester);
      expect(container.read(audioControllerProvider).playing, isFalse);

      router.push(AppRoutes.content('v-fear-courage'));
      await settle(tester);
      expect(find.textContaining('no video media is bundled'), findsOneWidget);
      await tester.tap(find.byKey(const Key('video.playPause')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Pause video'), findsOneWidget);
      await tester.tap(find.byKey(const Key('video.fullscreen')));
      await settle(tester);
      expect(find.byType(VideoFullscreenPage), findsOneWidget);
      await tester.tap(find.byTooltip('Exit full screen'));
      await settle(tester);
      expect(find.byType(VideoFullscreenPage), findsNothing);
      await tester.tap(find.byKey(const Key('video.playPause')));
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Upload validation', () {
    test('fields, topics, references and rights', () {
      expect(UploadValidation.title('Hi'), isNotNull);
      expect(UploadValidation.title('Courage for today'), isNull);
      expect(UploadValidation.description('Too short'), isNotNull);
      expect(UploadValidation.description('A helpful message about courage in hard seasons.'), isNull);
      expect(UploadValidation.attribution(''), isNotNull);
      expect(UploadValidation.topics({}), isNotNull);
      expect(UploadValidation.topics({'a', 'b', 'c', 'd'}), isNotNull);
      expect(UploadValidation.topics({'fear'}), isNull);
      expect(UploadValidation.rights(false), isNotNull);

      final (ok, err) = UploadValidation.parseReference('Isaiah 41:10', const []);
      expect(ok!.label, 'Isaiah 41:10');
      expect(err, isNull);
      expect(UploadValidation.parseReference('not a verse', const []).$2, isNotNull);
      expect(UploadValidation.parseReference('Isaiah 41:10', [ok]).$2, contains('already'));
    });
  });
}
