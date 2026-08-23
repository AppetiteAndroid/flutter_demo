import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/app/config/app_config.dart';
import 'package:flutter_starter/app/router/app_router.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/navigation/app_route_intent.dart';
import 'package:flutter_starter/core/navigation/route_intent_coordinator.dart';
import 'package:flutter_starter/core/notifications/notification_service.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_starter/features/example_search/data/search_repository.dart';
import 'package:flutter_starter/features/settings/data/settings_repository.dart';
import 'package:flutter_starter/features/settings/presentation/settings_bloc.dart';
import 'package:flutter_starter/features/settings/presentation/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

final config = AppConfig(
  appName: 'Test',
  environment: AppEnvironment.development,
  baseUrl: Uri.parse('https://example.invalid'),
  connectTimeout: Duration(seconds: 1),
  receiveTimeout: Duration(seconds: 1),
  networkLogsEnabled: false,
);
void main() {
  testWidgets('router redirects protected path and leaves sign in after auth', (
    tester,
  ) async {
    final session = UserSession(
      tokenStorage: MemoryTokenStorage(),
      snapshotStorage: MemoryKeyValueStorage(),
    );
    await session.initialize();
    final router = createRouter(
      config: config,
      session: session,
      searchRepository: () =>
          SearchRepository(const InMemorySearchDataSource()),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/account/profile');
    await tester.pump();
    await tester.pump();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/sign-in');
    await session.setAuthenticated(
      user: const User(id: '1', email: 'a@b.c'),
      tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
    );
    await tester.pump();
    await tester.pump();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/account/profile',
    );
    router.dispose();
    await session.dispose();
  });
  testWidgets('settings widget changes theme', (tester) async {
    final bloc = SettingsBloc(
      PersistentSettingsRepository(MemoryKeyValueStorage()),
      initial: const SettingsValue(
        themeMode: ThemeMode.system,
        locale: Locale('en'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: bloc, child: const SettingsScreen()),
      ),
    );
    expect(find.text('settings.theme.title'), findsOneWidget);
    await tester.tap(find.text('settings.theme.dark'));
    await tester.pump();
    expect(bloc.state.themeMode, ThemeMode.dark);
  });
  testWidgets('protected intent survives sign in and notification routes', (
    tester,
  ) async {
    final session = UserSession(
      tokenStorage: MemoryTokenStorage(),
      snapshotStorage: MemoryKeyValueStorage(),
    );
    final router = createRouter(
      config: config,
      session: session,
      searchRepository: () =>
          SearchRepository(const InMemorySearchDataSource()),
    );
    final coordinator = RouteIntentCoordinator(router: router, session: session)
      ..start();
    final notifications = MemoryLocalNotificationService();
    notifications.taps.listen(coordinator.handle);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await session.initialize();
    coordinator.handle(const AccountDetailsIntent(42));
    await tester.pump();
    await tester.pump();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/sign-in');
    await session.setAuthenticated(
      user: const User(id: '1', email: 'a@b.c'),
      tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
    );
    await tester.pump();
    await tester.pump();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/account/42');
    notifications.simulateTap(const HomeIntent());
    await tester.pump();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });
}
