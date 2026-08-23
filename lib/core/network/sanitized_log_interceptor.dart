import 'package:dio/dio.dart';

import '../logger/app_logger.dart';
import '../logger/redactor.dart';

class SanitizedLogInterceptor extends Interceptor {
  SanitizedLogInterceptor(this.logger);
  final AppLogger logger;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.debug(
      '${options.method} ${safeUriForLog(options.uri)} '
      'headers=${redactSensitive(options.headers)} '
      'body=${redactSensitive(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    logger.debug(
      '${response.statusCode} ${safeUriForLog(response.requestOptions.uri)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.warning(
      '${err.response?.statusCode ?? 'network'} '
      '${safeUriForLog(err.requestOptions.uri)}',
    );
    handler.next(err);
  }
}
