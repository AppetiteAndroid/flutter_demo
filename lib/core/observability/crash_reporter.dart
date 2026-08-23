import '../logger/app_logger.dart';
import 'analytics_service.dart';

abstract interface class CrashReporter {
  void record(
    Object error,
    StackTrace stack, {
    bool fatal,
    Map<String, Object?> context,
  });
  void setAnonymousUser(String? id);
  void clearIdentity();
}

class NoopCrashReporter implements CrashReporter {
  @override
  void record(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) {}
  @override
  void setAnonymousUser(String? id) {}
  @override
  void clearIdentity() {}
}

class DevelopmentCrashReporter implements CrashReporter {
  DevelopmentCrashReporter(this.logger);
  final AppLogger logger;
  String? anonymousUser;
  final Set<String> _seen = {};
  @override
  void record(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) {
    final key =
        '${error.runtimeType}:$error:${stack.toString().split('\n').firstOrNull}';
    if (!_seen.add(key)) return;
    logger.error(
      'crash fatal=$fatal user=$anonymousUser context=${sanitizeTelemetry(context)}',
      error,
      stack,
    );
  }

  @override
  void setAnonymousUser(String? id) => anonymousUser = id;
  @override
  void clearIdentity() => anonymousUser = null;
}
