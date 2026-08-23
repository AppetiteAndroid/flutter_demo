import 'package:flutter_starter/core/feature_flags/feature_flag_service.dart';
import 'package:flutter_starter/core/logger/app_logger.dart';
import 'package:flutter_starter/core/navigation/app_route_intent.dart';
import 'package:flutter_starter/core/notifications/notification_service.dart';
import 'package:flutter_starter/core/observability/analytics_service.dart';
import 'package:flutter_starter/core/observability/crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

class LoggerFake implements AppLogger {
  final entries = <String>[];
  @override
  void debug(String message) => entries.add(message);
  @override
  void info(String message) => entries.add(message);
  @override
  void warning(String message) => entries.add(message);
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      entries.add(message);
}

void main() {
  test('notification fake handles permission and operations', () async {
    final service = MemoryLocalNotificationService(
      permissionRequestResult: NotificationPermissionStatus.denied,
    );
    await service.initialize();
    expect(
      await service.requestPermission(),
      NotificationPermissionStatus.denied,
    );
    const request = LocalNotificationRequest(
      id: 1,
      title: 'Title',
      body: 'Body',
    );
    await service.show(request);
    await service.schedule(request, DateTime(2030));
    expect(service.shown, hasLength(1));
    expect(service.scheduled, hasLength(1));
    await service.cancel(1);
    expect(service.scheduled, isEmpty);
    await service.dispose();
  });
  test('notification payload parser rejects malformed payload', () {
    final parser = AppLinkParser(customSchemes: {'app'}, allowedHosts: {});
    expect(parser.parsePayload('app:/search?q=hello'), isA<SearchIntent>());
    expect(parser.parsePayload('evil:/settings'), isNull);
  });
  test('analytics strips sensitive values and resets identity', () {
    final logger = LoggerFake();
    final service = DevelopmentAnalyticsService(logger)..setConsent(true);
    service.setUserProperties({
      'plan': 'free',
      'email': 'secret@example.com',
      'access_token': 'secret',
    });
    expect(service.userProperties, {'plan': 'free'});
    service.track(
      AnalyticsEvent.screenView,
      properties: {'password': 'secret', 'screen': 'home'},
    );
    expect(logger.entries.single, isNot(contains('secret')));
    service.resetIdentity();
    expect(service.userProperties, isEmpty);
  });
  test('crash reporter deduplicates and sanitizes', () {
    final logger = LoggerFake();
    final reporter = DevelopmentCrashReporter(logger)
      ..setAnonymousUser('anonymous-1');
    final stack = StackTrace.current;
    reporter.record(
      StateError('failure'),
      stack,
      context: {'password': 'secret', 'screen': 'home'},
    );
    reporter.record(
      StateError('failure'),
      stack,
      context: {'password': 'secret'},
    );
    expect(logger.entries, hasLength(1));
    expect(logger.entries.single, isNot(contains('secret')));
    reporter.clearIdentity();
    expect(reporter.anonymousUser, isNull);
  });
  test('feature flags replay defaults, override and reset', () async {
    final service = LocalFeatureFlagService(allowOverrides: true);
    expect(
      (await service.stream.first).isEnabled(FeatureFlag.paginationExample),
      isTrue,
    );
    service.setOverride(FeatureFlag.paginationExample, false);
    expect(service.current.isEnabled(FeatureFlag.paginationExample), isFalse);
    service.resetOverrides();
    expect(service.current.isEnabled(FeatureFlag.paginationExample), isTrue);
    await service.dispose();
  });
}
