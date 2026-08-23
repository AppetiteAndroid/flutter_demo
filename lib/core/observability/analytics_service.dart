import '../logger/app_logger.dart';
import '../logger/redactor.dart';

enum AnalyticsEvent {
  screenView,
  notificationPermissionRequested,
  paginationRefreshed,
}

abstract interface class AnalyticsService {
  bool get consented;
  void setConsent(bool value);
  void track(AnalyticsEvent event, {Map<String, Object?> properties});
  void screen(String name);
  void setUserProperties(Map<String, Object?> properties);
  void resetIdentity();
}

Map<String, Object?> sanitizeTelemetry(Map<String, Object?> input) {
  final redacted = redactSensitive(input) as Map;
  const forbidden = {
    'email',
    'phone',
    'message',
    'body',
    'token',
    'password',
    'authorization',
  };
  return Map<String, Object?>.fromEntries(
    redacted.entries
        .where(
          (entry) => !forbidden.any(
            (key) => entry.key.toString().toLowerCase().contains(key),
          ),
        )
        .map((entry) => MapEntry(entry.key.toString(), entry.value)),
  );
}

class NoopAnalyticsService implements AnalyticsService {
  @override
  bool consented = false;
  @override
  void setConsent(bool value) => consented = value;
  @override
  void track(
    AnalyticsEvent event, {
    Map<String, Object?> properties = const {},
  }) {}
  @override
  void screen(String name) {}
  @override
  void setUserProperties(Map<String, Object?> properties) {}
  @override
  void resetIdentity() {}
}

class DevelopmentAnalyticsService implements AnalyticsService {
  DevelopmentAnalyticsService(this.logger);
  final AppLogger logger;
  @override
  bool consented = false;
  Map<String, Object?> userProperties = {};
  @override
  void setConsent(bool value) => consented = value;
  @override
  void track(
    AnalyticsEvent event, {
    Map<String, Object?> properties = const {},
  }) {
    if (consented) {
      logger.info('analytics ${event.name} ${sanitizeTelemetry(properties)}');
    }
  }

  @override
  void screen(String name) =>
      track(AnalyticsEvent.screenView, properties: {'screen': name});
  @override
  void setUserProperties(Map<String, Object?> properties) =>
      userProperties = sanitizeTelemetry(properties);
  @override
  void resetIdentity() => userProperties = {};
}
