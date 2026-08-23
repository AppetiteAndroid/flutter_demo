import 'package:dio/dio.dart';

import '../error/app_failure.dart';

AppFailure mapDioFailure(DioException error) {
  if (error.type == DioExceptionType.cancel) {
    return const CancelledFailure();
  }
  if ({
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  }.contains(error.type)) {
    return const TimeoutFailure();
  }
  if (error.type == DioExceptionType.connectionError) {
    return const NetworkFailure();
  }
  final code = error.response?.statusCode;
  return switch (code) {
    401 => const UnauthorizedFailure(),
    403 => const ForbiddenFailure(),
    404 => const NotFoundFailure(),
    409 => const ConflictFailure(),
    422 => ValidationFailure(fieldErrors: _fieldErrors(error.response?.data)),
    429 => RateLimitedFailure(
      retryAfter: _retryAfter(error.response?.headers.value('retry-after')),
    ),
    int value when value >= 500 => const ServerFailure(),
    _ => UnknownFailure(error.message),
  };
}

Map<String, List<String>> _fieldErrors(Object? data) {
  if (data is! Map || data['errors'] is! Map) return const {};
  final output = <String, List<String>>{};
  (data['errors'] as Map).forEach((key, value) {
    if (value is List) {
      output[key.toString()] = value.map((e) => e.toString()).toList();
    }
  });
  return output;
}

Duration? _retryAfter(String? value) {
  final seconds = int.tryParse(value ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}
