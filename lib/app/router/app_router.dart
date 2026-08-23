import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/components.dart';
import '../../core/session/user_session.dart';
import '../../core/storage/token_storage.dart';
import '../../features/example_search/data/search_repository.dart';
import '../../features/example_search/presentation/search_bloc.dart';
import '../../features/example_search/presentation/search_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../core/pagination/pagination.dart';
import '../../core/notifications/notification_service.dart';
import '../../features/example_pagination/data/demo_pagination_repository.dart';
import '../../features/example_pagination/presentation/pagination_screen.dart';
import '../../features/offline_tasks/presentation/offline_tasks_bloc.dart';
import '../../features/offline_tasks/presentation/offline_tasks_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../config/app_config.dart';

class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }
  late final StreamSubscription<Object?> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter({
  required AppConfig config,
  required UserSession session,
  required SearchRepository Function() searchRepository,
  LocalNotificationService? notifications,
  OfflineTasksBloc Function()? offlineTasksBloc,
  Widget Function()? offlineDevelopmentTools,
}) {
  final refresh = StreamListenable(session.stream);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (session.current.authenticationStatus ==
          AuthenticationStatus.initializing) {
        return null;
      }
      final signingIn = state.matchedLocation == '/sign-in';
      if ((state.matchedLocation.startsWith('/account') ||
              state.matchedLocation == '/offline-tasks') &&
          !session.isAuthenticated) {
        return '/sign-in?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (signingIn && session.isAuthenticated) {
        final from = state.uri.queryParameters['from'];
        return from?.startsWith('/') == true ? from : '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => HomeScreen(
          config: config,
          session: session,
          notifications: notifications,
        ),
      ),
      GoRoute(
        path: '/offline-tasks',
        name: 'offlineTasks',
        builder: (context, state) => offlineTasksBloc == null
            ? AppScaffold(
                title: 'offline.title'.tr(),
                body: const SizedBox.shrink(),
              )
            : BlocProvider(
                create: (_) =>
                    offlineTasksBloc()..add(const OfflineTasksStarted()),
                child: OfflineTasksScreen(
                  developmentTools: offlineDevelopmentTools?.call(),
                ),
              ),
      ),
      GoRoute(
        path: '/pagination',
        name: 'pagination',
        builder: (context, state) => BlocProvider(
          create: (_) => PaginationBloc<DemoItem, int>(
            repository: DemoPaginationRepository(),
            keyOf: (item) => item.id,
          )..add(const PaginationStarted()),
          child: const PaginationScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => BlocProvider(
          create: (_) =>
              SearchBloc(searchRepository())..add(const SearchStarted()),
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/account/:section',
        name: 'account',
        builder: (context, state) => AppScaffold(
          title: state.pathParameters['section'] ?? '',
          body: const SizedBox.shrink(),
        ),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'signIn',
        builder: (context, state) => AppScaffold(
          title: 'nav.sign_in'.tr(),
          body: Center(
            child: AppButton(
              label: 'auth.action'.tr(),
              onPressed: () => session.setAuthenticated(
                user: const User(id: 'demo', email: 'demo@example.invalid'),
                tokens: const TokenPair(
                  accessToken: 'development-only',
                  refreshToken: 'development-only',
                ),
              ),
            ),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => AppScaffold(
      title: 'errors.unknown'.tr(),
      body: AppErrorView(message: 'errors.unknown'.tr()),
    ),
  );
}
