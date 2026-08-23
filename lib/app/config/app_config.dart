enum AppEnvironment { development, staging, production }

bool developmentToolsEnabled({
  required AppEnvironment environment,
  required bool isDebugBuild,
}) => isDebugBuild && environment == AppEnvironment.development;

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.environment,
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.networkLogsEnabled,
    this.reachabilityPath = '/health',
    this.realtimePath = '/ws',
  });

  final String appName;
  final AppEnvironment environment;
  final Uri baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool networkLogsEnabled;
  final String reachabilityPath;
  final String realtimePath;

  Uri get reachabilityUrl => baseUrl.resolve(reachabilityPath);
  Uri get realtimeUrl {
    final resolved = baseUrl.resolve(realtimePath);
    return resolved.replace(scheme: resolved.scheme == 'https' ? 'wss' : 'ws');
  }

  factory AppConfig.fromEnvironment({Map<String, String>? values}) {
    String read(String key, String fallback) =>
        values?[key] ??
        switch (key) {
          'APP_NAME' => const String.fromEnvironment(
            'APP_NAME',
            defaultValue: 'Flutter Starter Dev',
          ),
          'ENVIRONMENT' => const String.fromEnvironment(
            'ENVIRONMENT',
            defaultValue: 'development',
          ),
          'BASE_URL' => const String.fromEnvironment(
            'BASE_URL',
            defaultValue: 'https://example.invalid',
          ),
          'CONNECT_TIMEOUT_MS' => const String.fromEnvironment(
            'CONNECT_TIMEOUT_MS',
            defaultValue: '15000',
          ),
          'RECEIVE_TIMEOUT_MS' => const String.fromEnvironment(
            'RECEIVE_TIMEOUT_MS',
            defaultValue: '30000',
          ),
          'ENABLE_NETWORK_LOGS' => const String.fromEnvironment(
            'ENABLE_NETWORK_LOGS',
            defaultValue: 'true',
          ),
          'NATIVE_FLAVOR' => const String.fromEnvironment('NATIVE_FLAVOR'),
          'REACHABILITY_PATH' => const String.fromEnvironment(
            'REACHABILITY_PATH',
            defaultValue: '/health',
          ),
          'REALTIME_PATH' => const String.fromEnvironment(
            'REALTIME_PATH',
            defaultValue: '/ws',
          ),
          _ => fallback,
        };
    final name = read('APP_NAME', '').trim();
    final environment = AppEnvironment.values
        .where((value) => value.name == read('ENVIRONMENT', ''))
        .firstOrNull;
    final uri = Uri.tryParse(read('BASE_URL', ''));
    final connect = int.tryParse(read('CONNECT_TIMEOUT_MS', ''));
    final receive = int.tryParse(read('RECEIVE_TIMEOUT_MS', ''));
    if (name.isEmpty ||
        environment == null ||
        uri == null ||
        !uri.hasScheme ||
        connect == null ||
        connect <= 0 ||
        receive == null ||
        receive <= 0) {
      throw const FormatException(
        'Invalid app configuration: check APP_NAME, ENVIRONMENT, BASE_URL and timeout values.',
      );
    }
    final nativeFlavor = read('NATIVE_FLAVOR', '');
    if (nativeFlavor.isNotEmpty && nativeFlavor != environment.name) {
      throw FormatException(
        'Native flavor "$nativeFlavor" does not match Dart environment "${environment.name}".',
      );
    }
    return AppConfig(
      appName: name,
      environment: environment,
      baseUrl: uri,
      connectTimeout: Duration(milliseconds: connect),
      receiveTimeout: Duration(milliseconds: receive),
      networkLogsEnabled:
          environment != AppEnvironment.production &&
          read('ENABLE_NETWORK_LOGS', 'false').toLowerCase() == 'true',
      reachabilityPath: read('REACHABILITY_PATH', '/health'),
      realtimePath: read('REALTIME_PATH', '/ws'),
    );
  }
}
