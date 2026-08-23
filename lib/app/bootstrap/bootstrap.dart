import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/logger/app_logger.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/database/app_database.dart';
import '../../core/lifecycle/app_lifecycle_service.dart';
import '../../core/navigation/app_link_service.dart';
import '../../core/navigation/route_intent_coordinator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/observability/crash_reporter.dart';
import '../../core/session/user_session.dart';
import '../../core/realtime/realtime_client.dart';
import '../../core/realtime/websocket_transport.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_remote_data_source.dart';
import '../../core/sync/sync_store.dart';
import '../../features/offline_tasks/presentation/offline_development_tools.dart';
import '../../features/offline_tasks/presentation/offline_tasks_bloc.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/presentation/settings_bloc.dart';
import '../app.dart';
import '../config/app_config.dart';
import '../di/dependency_injection.dart';
import '../router/app_router.dart';
import '../session/user_data_boundary_coordinator.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  await configureDependencies(config: config);
  final logger = getIt<AppLogger>();
  final crashReporter = getIt<CrashReporter>();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.error('Flutter framework error', details.exception, details.stack);
    crashReporter.record(
      details.exception,
      details.stack ?? StackTrace.current,
      fatal: false,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('Uncaught platform error', error, stack);
    crashReporter.record(error, stack, fatal: true);
    return true;
  };
  final settingsValue = await getIt<SettingsRepository>().load();
  final settings = SettingsBloc(getIt(), initial: settingsValue);
  await getIt<UserSession>().initialize();
  await getIt<AppDatabase>().customSelect('SELECT 1').get();
  getIt<AppLifecycleService>().start();
  await getIt<ConnectivityService>().start();
  getIt<SyncEngine>().start();
  getIt<RealtimeClient>().start();
  final router = createRouter(
    config: config,
    session: getIt(),
    searchRepository: () => getIt(),
    notifications: getIt(),
    offlineTasksBloc: () => getIt<OfflineTasksBloc>(),
    offlineDevelopmentTools:
        developmentToolsEnabled(
          environment: config.environment,
          isDebugBuild: kDebugMode,
        )
        ? () => OfflineDevelopmentTools(
            connectivity: getIt<FakeConnectivityService>(),
            remote: getIt<FakeSyncRemoteDataSource>(),
            transport: getIt<FakeWebSocketTransport>(),
            syncEngine: getIt<SyncEngine>(),
            realtime: getIt<RealtimeClient>(),
            store: getIt<SyncStore>(),
            database: getIt<AppDatabase>(),
            session: getIt<UserSession>(),
          )
        : null,
  );
  final coordinator = RouteIntentCoordinator(router: router, session: getIt())
    ..start();
  final links = getIt<AppLinkService>();
  final notifications = getIt<LocalNotificationService>();
  coordinator.bind(links.intents);
  coordinator.bind(notifications.taps);
  UserDataBoundaryCoordinator(
    session: getIt(),
    tasks: getIt(),
    analytics: getIt(),
    crashReporter: getIt(),
    clearProtectedRouteIntent: coordinator.clearProtectedPending,
  ).start();
  await links.initialize();
  await notifications.initialize();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ru')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: settingsValue.locale,
      saveLocale: false,
      child: StarterApp(config: config, settingsBloc: settings, router: router),
    ),
  );
}
