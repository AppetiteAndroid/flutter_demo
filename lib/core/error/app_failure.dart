sealed class AppFailure {
  const AppFailure([this.message]);
  final String? message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message]);
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message]);
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure([super.message]);
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message]);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([super.message]);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message]);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure([super.message]);
}

final class ValidationFailure extends AppFailure {
  ValidationFailure({
    Map<String, List<String>> fieldErrors = const {},
    String? message,
  }) : fieldErrors = Map<String, List<String>>.unmodifiable(
         fieldErrors.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ),
       super(message);
  final Map<String, List<String>> fieldErrors;
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({this.retryAfter, String? message}) : super(message);
  final Duration? retryAfter;
}

final class ServerFailure extends AppFailure {
  const ServerFailure([super.message]);
}

final class DecodingFailure extends AppFailure {
  const DecodingFailure([super.message]);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message]);
}
