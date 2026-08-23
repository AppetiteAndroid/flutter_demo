import 'package:dio/dio.dart';

import '../error/app_failure.dart';
import '../result/result.dart';
import 'failure_mapper.dart';

abstract final class RequestMetadata {
  static const skipAuth = 'skipAuth',
      skipRefresh = 'skipRefresh',
      retried = 'authRetried';
}

class ApiClient {
  ApiClient(Dio dio) : _dio = dio;
  final Dio _dio;
  Future<Result<T>> get<T>(
    String path, {
    Map<String, Object?>? query,
    Map<String, Object?>? headers,
    required T Function(Object?) parser,
    bool authorized = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) => _request(
    'GET',
    path,
    query: query,
    headers: headers,
    parser: parser,
    authorized: authorized,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
  );
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    Map<String, Object?>? headers,
    required T Function(Object?) parser,
    bool authorized = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => _request(
    'POST',
    path,
    body: body,
    query: query,
    headers: headers,
    parser: parser,
    authorized: authorized,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
  );
  Future<Result<T>> put<T>(
    String path, {
    Object? body,
    required T Function(Object?) parser,
    bool authorized = true,
  }) =>
      _request('PUT', path, body: body, parser: parser, authorized: authorized);
  Future<Result<T>> patch<T>(
    String path, {
    Object? body,
    required T Function(Object?) parser,
    bool authorized = true,
  }) => _request(
    'PATCH',
    path,
    body: body,
    parser: parser,
    authorized: authorized,
  );
  Future<Result<T>> delete<T>(
    String path, {
    Object? body,
    required T Function(Object?) parser,
    bool authorized = true,
  }) => _request(
    'DELETE',
    path,
    body: body,
    parser: parser,
    authorized: authorized,
  );
  Future<Result<T>> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    Map<String, Object?>? headers,
    required T Function(Object?) parser,
    bool authorized = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: headers,
          extra: {
            RequestMetadata.skipAuth: !authorized,
            RequestMetadata.skipRefresh: !authorized,
          },
        ),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      try {
        return Success(parser(response.data));
      } catch (error) {
        return Failure(DecodingFailure(error.toString()));
      }
    } on DioException catch (error) {
      return Failure(mapDioFailure(error));
    } catch (error) {
      return Failure(UnknownFailure(error.toString()));
    }
  }

  Future<Result<void>> download(
    String path,
    String savePath, {
    bool authorized = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        path,
        savePath,
        options: Options(extra: {RequestMetadata.skipAuth: !authorized}),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return const Success(null);
    } on DioException catch (error) {
      return Failure(mapDioFailure(error));
    }
  }
}
