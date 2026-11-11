import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';
import '../storage/token_storage.dart';

/// Adds standard headers and the bearer token (when a session exists).
class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(this._tokens);

  final TokenStorage _tokens;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers.putIfAbsent('Accept', () => 'application/json');
    options.headers.putIfAbsent('X-Client', () => 'mwb-flutter');
    final tokens = await _tokens.read();
    if (tokens != null && options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }
}

/// Handles 401 responses centrally: clears the stored session and notifies the
/// app so it can return to a signed-out state.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(this._tokens, this._onUnauthorized);

  final TokenStorage _tokens;
  final VoidCallback _onUnauthorized;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _tokens.clear();
      _onUnauthorized();
    }
    handler.next(err);
  }
}

/// Debug-only request/response logging. Never logs headers (tokens).
class SafeLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[MWB API] → ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('[MWB API] ← ${response.statusCode} ${response.requestOptions.uri.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[MWB API] ✕ ${err.type.name} ${err.requestOptions.uri.path}');
    handler.next(err);
  }
}

/// Translates a [DioException] into an [AppFailure].
AppFailure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const UnknownFailure('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('A secure connection could not be established.');
    case DioExceptionType.badResponse:
      return mapStatusCode(e.response?.statusCode, e.response?.data);
    case DioExceptionType.unknown:
      return const NetworkFailure();
  }
}

/// Maps HTTP status codes (Laravel conventions) to failures.
AppFailure mapStatusCode(int? status, Object? body) {
  final message = body is Map && body['message'] is String ? body['message'] as String : null;
  switch (status) {
    case 401:
      return const UnauthorizedFailure();
    case 403:
      return const ForbiddenFailure();
    case 404:
      return const NotFoundFailure();
    case 422:
      final errors = <String, String>{};
      if (body is Map && body['errors'] is Map) {
        (body['errors'] as Map).forEach((k, v) {
          if (v is List && v.isNotEmpty) errors['$k'] = '${v.first}';
        });
      }
      return ValidationFailure(message ?? 'Please check the information provided.', fieldErrors: errors);
    default:
      if (status != null && status >= 500) return ServerFailure(message ?? const ServerFailure().message, status);
      return UnknownFailure(message ?? const UnknownFailure().message);
  }
}
