import 'package:flutter_starter/app/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates and production disables logs', () {
    final config = AppConfig.fromEnvironment(
      values: {
        'APP_NAME': 'App',
        'ENVIRONMENT': 'production',
        'BASE_URL': 'https://example.com',
        'CONNECT_TIMEOUT_MS': '1',
        'RECEIVE_TIMEOUT_MS': '2',
        'ENABLE_NETWORK_LOGS': 'true',
      },
    );
    expect(config.networkLogsEnabled, isFalse);
    expect(config.environment, AppEnvironment.production);
    expect(config.reachabilityUrl, Uri.parse('https://example.com/health'));
    expect(config.realtimeUrl, Uri.parse('wss://example.com/ws'));
  });
  test(
    'rejects invalid values',
    () => expect(
      () => AppConfig.fromEnvironment(
        values: {
          'APP_NAME': '',
          'ENVIRONMENT': 'wat',
          'BASE_URL': 'nope',
          'CONNECT_TIMEOUT_MS': '0',
          'RECEIVE_TIMEOUT_MS': 'x',
        },
      ),
      throwsFormatException,
    ),
  );
  test('development tools are inert outside debug development builds', () {
    expect(
      developmentToolsEnabled(
        environment: AppEnvironment.development,
        isDebugBuild: true,
      ),
      isTrue,
    );
    expect(
      developmentToolsEnabled(
        environment: AppEnvironment.production,
        isDebugBuild: true,
      ),
      isFalse,
    );
    expect(
      developmentToolsEnabled(
        environment: AppEnvironment.development,
        isDebugBuild: false,
      ),
      isFalse,
    );
  });
}
