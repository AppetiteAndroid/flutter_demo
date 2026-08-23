import '../error/app_failure.dart';

sealed class Result<T> {
  const Result();
  R fold<R>(R Function(T) success, R Function(AppFailure) failure) =>
      switch (this) {
        Success<T>(:final value) => success(value),
        Failure<T>(:final error) => failure(error),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppFailure error;
}
