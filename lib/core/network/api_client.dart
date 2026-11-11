import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../errors/app_failure.dart';
import '../storage/token_storage.dart';
import 'interceptors.dart';

/// Thin wrapper around Dio for the future MWB API.
///
/// All calls return decoded JSON or throw an [AppFailure]. Feature code never
/// sees Dio types, which keeps the transport replaceable.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
    required VoidCallback onUnauthorized,
    Dio? dio,
  }) : _config = config,
       _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = config.apiBaseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..sendTimeout = config.sendTimeout
      ..responseType = ResponseType.json;
    _dio.interceptors.addAll([
      AuthHeaderInterceptor(tokenStorage),
      UnauthorizedInterceptor(tokenStorage, onUnauthorized),
      if (config.enableNetworkLogging && kDebugMode) SafeLogInterceptor(),
    ]);
  }

  final AppConfig _config;
  final Dio _dio;

  Dio get dio => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) => _send(() => _dio.post<T>(path, data: body));

  Future<T> put<T>(String path, {Object? body}) => _send(() => _dio.put<T>(path, data: body));

  Future<T> delete<T>(String path) => _send(() => _dio.delete<T>(path));

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    if (_config.isMock || _config.apiBaseUrl.isEmpty) {
      // Guard: Foundation V1 runs in mock mode and must never hit a server.
      throw const FeatureUnavailableFailure('Online services are not enabled in this build.');
    }
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const UnknownFailure();
    }
  }
}
