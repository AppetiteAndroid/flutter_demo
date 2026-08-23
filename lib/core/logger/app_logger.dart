import 'dart:developer' as developer;

abstract interface class AppLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

class DeveloperAppLogger implements AppLogger {
  const DeveloperAppLogger();
  @override
  void debug(String message) => developer.log(message, name: 'DEBUG');
  @override
  void info(String message) => developer.log(message, name: 'INFO');
  @override
  void warning(String message) => developer.log(message, name: 'WARNING');
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      developer.log(
        message,
        name: 'ERROR',
        error: error,
        stackTrace: stackTrace,
      );
}

/// Production logging deliberately drops verbose events and never forwards
/// arbitrary error objects or stack traces to the platform log. Applications
/// can replace this with a consent-aware, sanitizing remote adapter.
class ProductionAppLogger implements AppLogger {
  const ProductionAppLogger();

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warning(String message) =>
      developer.log('Application warning', name: 'WARNING');

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      developer.log('Application error', name: 'ERROR');
}
