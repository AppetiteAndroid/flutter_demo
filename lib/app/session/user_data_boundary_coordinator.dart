import 'dart:async';

import '../../core/observability/analytics_service.dart';
import '../../core/observability/crash_reporter.dart';
import '../../core/session/user_session.dart';
import '../../features/offline_tasks/domain/offline_task_repository.dart';

class UserDataBoundaryCoordinator {
  UserDataBoundaryCoordinator({
    required this.session,
    required this.tasks,
    required this.analytics,
    required this.crashReporter,
    required this.clearProtectedRouteIntent,
  });

  final UserSession session;
  final OfflineTaskRepository tasks;
  final AnalyticsService analytics;
  final CrashReporter crashReporter;
  final void Function() clearProtectedRouteIntent;
  StreamSubscription<UserSessionState>? _subscription;
  String? _owner;

  void start() {
    if (_subscription != null) return;
    _owner = session.user?.id;
    _subscription = session.stream.listen((state) {
      final nextOwner = state.isAuthenticated ? state.user?.id : null;
      final previousOwner = _owner;
      _owner = nextOwner;
      if (previousOwner != null && previousOwner != nextOwner) {
        unawaited(tasks.clearOwnerData(previousOwner));
        analytics.resetIdentity();
        crashReporter.clearIdentity();
        clearProtectedRouteIntent();
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
