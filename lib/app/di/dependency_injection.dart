import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../core/background/background_sync_handler.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/database/app_database.dart';
import '../../core/database/migrations/migration_reporter.dart';
import '../../core/lifecycle/app_lifecycle_service.dart';
import '../../core/navigation/app_link_service.dart';
import '../../core/navigation/app_route_intent.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/push_messaging_service.dart';
import '../../core/observability/analytics_service.dart';
import '../../core/observability/crash_reporter.dart';
import '../../core/feature_flags/feature_flag_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/sanitized_log_interceptor.dart';
import '../../core/session/user_session.dart';
import '../../core/realtime/realtime_client.dart';
import '../../core/realtime/realtime_message_parser.dart';
import '../../core/realtime/websocket_transport.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_remote_data_source.dart';
import '../../core/sync/sync_store.dart';
import '../../core/storage/key_value_storage.dart';
import '../../core/storage/token_storage.dart';
import '../../features/example_search/data/search_repository.dart';
import '../../features/offline_tasks/data/drift_offline_task_repository.dart';
import '../../features/offline_tasks/data/drift_sync_store.dart';
import '../../features/offline_tasks/domain/offline_task_repository.dart';
import '../../features/offline_tasks/presentation/offline_tasks_bloc.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/presentation/settings_bloc.dart';
import '../config/app_config.dart';

final getIt = GetIt.instance;
Future<void> configureDependencies({
  required AppConfig config,
  SharedPreferences? preferences,
  KeyValueStorage? keyValueStorage,
  TokenStorage? tokenStorage,
  TokenRefreshService? refreshService,
}) async {
  await getIt.reset();
  getIt.registerSingleton(config);
  getIt.registerLazySingleton<AppLogger>(
    () => config.environment == AppEnvironment.production
        ? const ProductionAppLogger()
        : const DeveloperAppLogger(),
  );
  final suffix = switch (config.environment) {
    AppEnvironment.development => '-dev',
    AppEnvironment.staging => '-staging',
    AppEnvironment.production => '',
  };
  getIt.registerSingleton(
    AppLinkParser(
      customSchemes: {'flutterstarter$suffix'},
      allowedHosts: {
        switch (config.environment) {
          AppEnvironment.development => 'dev.example.invalid',
          AppEnvironment.staging => 'staging.example.invalid',
          AppEnvironment.production => 'example.invalid',
        },
      },
    ),
  );
  getIt.registerLazySingleton<PlatformLinkSource>(AppLinksSource.new);
  getIt.registerLazySingleton(
    () => AppLinkService(source: getIt(), parser: getIt()),
  );
  getIt.registerLazySingleton<LocalNotificationService>(
    () => FlutterLocalNotificationService(parser: getIt()),
  );
  getIt.registerLazySingleton<PushMessagingService>(
    NoopPushMessagingService.new,
  );
  getIt.registerLazySingleton<AnalyticsService>(
    () => config.environment == AppEnvironment.production
        ? NoopAnalyticsService()
        : DevelopmentAnalyticsService(getIt()),
  );
  getIt.registerLazySingleton<CrashReporter>(
    () => config.environment == AppEnvironment.production
        ? NoopCrashReporter()
        : DevelopmentCrashReporter(getIt()),
  );
  getIt.registerLazySingleton(
    () => AppDatabase(migrationReporter: MigrationReporter(getIt(), getIt())),
  );
  getIt.registerLazySingleton<AppLifecycleService>(
    FlutterAppLifecycleService.new,
  );
  getIt.registerLazySingleton<FeatureFlagService>(
    () => LocalFeatureFlagService(
      allowOverrides: config.environment == AppEnvironment.development,
    ),
  );
  final kv =
      keyValueStorage ??
      SharedPreferencesStorage(
        preferences ?? await SharedPreferences.getInstance(),
      );
  getIt.registerSingleton<KeyValueStorage>(kv);
  getIt.registerLazySingleton<SettingsRepository>(
    () => PersistentSettingsRepository(getIt()),
  );
  getIt.registerSingleton<TokenStorage>(
    tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage()),
  );
  getIt.registerLazySingleton(
    () => UserSession(tokenStorage: getIt(), snapshotStorage: getIt()),
  );
  final plain = Dio(
    BaseOptions(
      baseUrl: config.baseUrl.toString(),
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
    ),
  );
  getIt.registerSingleton<Dio>(plain, instanceName: 'refreshDio');
  if (config.environment == AppEnvironment.development) {
    getIt.registerLazySingleton(FakeConnectivityService.new);
    getIt.registerLazySingleton<ConnectivityService>(
      () => getIt<FakeConnectivityService>(),
    );
  } else {
    getIt.registerLazySingleton<ConnectivityService>(
      () => ProbingConnectivityService(
        interfaces: ConnectivityPlusInterfaceSource(),
        probe: DioBackendReachabilityProbe(
          getIt(instanceName: 'refreshDio'),
          config.reachabilityUrl,
        ),
      ),
    );
  }
  getIt.registerLazySingleton<TokenRefreshService>(
    () =>
        refreshService ??
        DioTokenRefreshService(getIt(instanceName: 'refreshDio')),
  );
  getIt.registerLazySingleton(
    () => SingleFlightTokenRefresher(getIt(), getIt()),
  );
  final authorized = Dio(
    BaseOptions(
      baseUrl: config.baseUrl.toString(),
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
    ),
  );
  authorized.interceptors.add(
    AuthInterceptor(
      authorized,
      tokens: getIt(),
      refresher: getIt(),
      session: getIt(),
    ),
  );
  if (config.networkLogsEnabled) {
    authorized.interceptors.add(SanitizedLogInterceptor(getIt()));
  }
  getIt.registerSingleton<Dio>(authorized);
  getIt.registerLazySingleton(() => ApiClient(getIt()));
  getIt.registerLazySingleton(FakeSyncRemoteDataSource.new);
  getIt.registerLazySingleton<SyncRemoteDataSource>(
    () => getIt<FakeSyncRemoteDataSource>(),
  );
  getIt.registerLazySingleton<DriftSyncStore>(() => DriftSyncStore(getIt()));
  getIt.registerLazySingleton<SyncStore>(() => getIt<DriftSyncStore>());
  getIt.registerLazySingleton<DriftOfflineTaskRepository>(
    () => DriftOfflineTaskRepository(database: getIt(), session: getIt()),
  );
  getIt.registerLazySingleton<OfflineTaskRepository>(
    () => getIt<DriftOfflineTaskRepository>(),
  );
  getIt.registerLazySingleton<SyncEngine>(() {
    final engine = SyncEngine(
      store: getIt(),
      remote: getIt(),
      session: getIt(),
      connectivity: getIt(),
      lifecycle: getIt(),
      logger: getIt(),
      recoverAuthentication: () async {
        final pair = await getIt<SingleFlightTokenRefresher>().refresh();
        if (pair == null) return false;
        getIt<UserSession>().notifyTokenRefreshed();
        return true;
      },
    );
    getIt<DriftOfflineTaskRepository>().attachSyncRequest(engine.requestSync);
    return engine;
  });
  if (config.environment == AppEnvironment.development) {
    getIt.registerLazySingleton(FakeWebSocketTransport.new);
    getIt.registerLazySingleton<WebSocketTransport>(
      () => getIt<FakeWebSocketTransport>(),
    );
  } else {
    getIt.registerLazySingleton<WebSocketTransport>(IoWebSocketTransport.new);
  }
  getIt.registerLazySingleton(
    () => RealtimeClient(
      transport: getIt(),
      parser: const RealtimeMessageParser(),
      session: getIt(),
      tokenStorage: getIt(),
      connectivity: getIt(),
      lifecycle: getIt(),
      url: config.realtimeUrl,
      logger: getIt(),
      recoverAuthentication: () async {
        final pair = await getIt<SingleFlightTokenRefresher>().refresh();
        if (pair == null) return false;
        getIt<UserSession>().notifyTokenRefreshed();
        return true;
      },
    ),
  );
  getIt.registerLazySingleton(
    () => BackgroundSyncHandler(runner: getIt<SyncEngine>(), logger: getIt()),
  );
  getIt.registerFactory(() => SettingsBloc(getIt()));
  getIt.registerFactory<SearchRepository>(
    () => SearchRepository(const InMemorySearchDataSource()),
  );
  getIt.registerFactory(
    () => OfflineTasksBloc(
      repository: getIt(),
      syncEngine: getIt(),
      connectivity: getIt(),
      realtime: getIt(),
    ),
  );
}

Future<void> disposeDependencies() async {
  if (getIt.isRegistered<RealtimeClient>()) {
    await getIt<RealtimeClient>().dispose();
  }
  if (getIt.isRegistered<SyncEngine>()) await getIt<SyncEngine>().dispose();
  if (getIt.isRegistered<ConnectivityService>()) {
    await getIt<ConnectivityService>().dispose();
  }
  if (getIt.isRegistered<AppLifecycleService>()) {
    await getIt<AppLifecycleService>().dispose();
  }
  if (getIt.isRegistered<AppLinkService>()) {
    await getIt<AppLinkService>().dispose();
  }
  if (getIt.isRegistered<LocalNotificationService>()) {
    await getIt<LocalNotificationService>().dispose();
  }
  if (getIt.isRegistered<FeatureFlagService>()) {
    await getIt<FeatureFlagService>().dispose();
  }
  if (getIt.isRegistered<AppDatabase>()) await getIt<AppDatabase>().close();
  if (getIt.isRegistered<UserSession>()) await getIt<UserSession>().dispose();
  await getIt.reset();
}
