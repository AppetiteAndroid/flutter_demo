import 'dart:async';

import 'package:dio/dio.dart';

import '../session/user_session.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

abstract interface class TokenRefreshService {
  Future<TokenPair?> refresh(String refreshToken);
}

class DioTokenRefreshService implements TokenRefreshService {
  DioTokenRefreshService(Dio dio) : _dio = dio;
  final Dio _dio;
  @override
  Future<TokenPair?> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          extra: {
            RequestMetadata.skipAuth: true,
            RequestMetadata.skipRefresh: true,
          },
        ),
      );
      final access = response.data?['access_token'],
          refresh = response.data?['refresh_token'];
      return access is String && refresh is String
          ? TokenPair(accessToken: access, refreshToken: refresh)
          : null;
    } catch (_) {
      return null;
    }
  }
}

class SingleFlightTokenRefresher {
  SingleFlightTokenRefresher(this.service, this.storage);
  final TokenRefreshService service;
  final TokenStorage storage;
  Future<TokenPair?>? _inFlight;
  Future<TokenPair?> refresh() {
    return _inFlight ??= _run();
  }

  Future<TokenPair?> _run() async {
    try {
      final current = await storage.read();
      if (current == null) return null;
      final next = await service.refresh(current.refreshToken);
      if (next != null) {
        await storage.write(next);
      }
      return next;
    } finally {
      _inFlight = null;
    }
  }
}

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(
    this._dio, {
    required this.tokens,
    required this.refresher,
    required this.session,
  });
  final Dio _dio;
  final TokenStorage tokens;
  final SingleFlightTokenRefresher refresher;
  final UserSession session;
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[RequestMetadata.skipAuth] != true) {
      final pair = await tokens.read();
      if (pair != null) {
        options.headers['Authorization'] = 'Bearer ${pair.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra[RequestMetadata.skipRefresh] == true ||
        request.extra[RequestMetadata.retried] == true) {
      handler.next(err);
      return;
    }
    final pair = await refresher.refresh();
    if (pair == null) {
      await session.invalidate();
      handler.next(err);
      return;
    }
    session.notifyTokenRefreshed();
    try {
      request.headers['Authorization'] = 'Bearer ${pair.accessToken}';
      request.extra[RequestMetadata.retried] = true;
      final response = await _dio.fetch<Object?>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
