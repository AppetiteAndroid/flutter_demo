import 'dart:async';

import 'package:go_router/go_router.dart';

import '../session/user_session.dart';
import 'app_route_intent.dart';

class RouteIntentCoordinator {
  RouteIntentCoordinator({required this.router, required this.session});
  final GoRouter router;
  final UserSession session;
  AppRouteIntent? _pending;
  StreamSubscription<UserSessionState>? _sessionSubscription;
  final List<StreamSubscription<AppRouteIntent>> _intentSubscriptions = [];
  bool _disposed = false;
  void start() {
    _sessionSubscription = session.stream.listen((_) {
      if (session.current.authenticationStatus ==
          AuthenticationStatus.initializing) {
        return;
      }
      final pending = _pending;
      if (pending != null &&
          (!pending.requiresAuthentication || session.isAuthenticated)) {
        _pending = null;
        handle(pending);
      }
    });
  }

  void bind(Stream<AppRouteIntent> intents) {
    _intentSubscriptions.add(intents.listen(handle));
  }

  void handle(AppRouteIntent intent) {
    if (_disposed) return;
    if (session.current.authenticationStatus ==
            AuthenticationStatus.initializing ||
        intent.requiresAuthentication && !session.isAuthenticated) {
      _pending = intent;
      if (session.current.authenticationStatus !=
          AuthenticationStatus.initializing) {
        router.goNamed('signIn');
      }
      return;
    }
    switch (intent) {
      case HomeIntent():
        router.goNamed('home');
      case SettingsIntent():
        router.goNamed('settings');
      case SearchIntent(:final query):
        router.goNamed(
          'search',
          queryParameters: query == null ? const {} : {'q': query},
        );
      case AccountDetailsIntent(:final id):
        router.goNamed('account', pathParameters: {'section': id.toString()});
    }
  }

  void clearProtectedPending() {
    if (_pending?.requiresAuthentication == true) _pending = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _pending = null;
    await _sessionSubscription?.cancel();
    for (final subscription in _intentSubscriptions) {
      await subscription.cancel();
    }
    _intentSubscriptions.clear();
  }
}
