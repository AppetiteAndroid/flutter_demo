import 'dart:convert';
import 'dart:math';

import 'package:flutter_starter/core/connectivity/connectivity_service.dart';
import 'package:flutter_starter/core/lifecycle/app_lifecycle_service.dart';
import 'package:flutter_starter/core/realtime/realtime_client.dart';
import 'package:flutter_starter/core/realtime/realtime_message_parser.dart';
import 'package:flutter_starter/core/realtime/realtime_models.dart';
import 'package:flutter_starter/core/realtime/websocket_transport.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/v03_test_helpers.dart';

void main() {
  test('connects with authentication and parses typed messages', () async {
    final environment = await RealtimeTestEnvironment.create();
    await environment.client.connect();
    expect(environment.client.current.phase, RealtimePhase.connected);
    expect(environment.transport.connectionCount, 1);
    final future = environment.client.messages.first;
    environment.transport.latest!.incoming(
      message('task-1', 'demo_task.changed', {
        'taskId': 'task-1',
        'serverVersion': 3,
      }),
    );
    expect(await future, isA<DemoTaskChangedMessage>());
    await environment.dispose();
  });

  test('unexpected close reconnects with bounded short backoff', () async {
    final environment = await RealtimeTestEnvironment.create();
    await environment.client.connect();
    await environment.transport.latest!.unexpectedClose();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(environment.transport.connectionCount, 2);
    expect(environment.client.current.phase, RealtimePhase.connected);
    await environment.dispose();
  });

  test('manual disconnect and dispose never reconnect', () async {
    final environment = await RealtimeTestEnvironment.create();
    await environment.client.connect();
    await environment.client.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(environment.transport.connectionCount, 1);
    expect(environment.client.current.phase, RealtimePhase.disconnected);
    await environment.client.dispose();
    final count = environment.transport.connectionCount;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(environment.transport.connectionCount, count);
    await environment.disposeClientAlreadyClosed();
  });

  test('logout stops socket and user token revision reconnects', () async {
    final environment = await RealtimeTestEnvironment.create();
    await environment.client.connect();
    environment.session.notifyTokenRefreshed();
    await flushEvents(8);
    expect(environment.transport.connectionCount, 2);
    await environment.session.logout();
    await flushEvents();
    expect(
      environment.client.current.phase,
      RealtimePhase.authenticationRequired,
    );
    expect(environment.transport.latest!.isClosed, isTrue);
    await environment.dispose();
  });

  test(
    'user switch reconnects and background pauses then foreground resumes',
    () async {
      final environment = await RealtimeTestEnvironment.create();
      await environment.client.connect();
      await environment.session.setAuthenticated(
        user: const User(id: 'owner-b', email: 'b@example.invalid'),
        tokens: const TokenPair(accessToken: 'b', refreshToken: 'b-refresh'),
      );
      await flushEvents(8);
      expect(environment.transport.connectionCount, 2);
      environment.lifecycle.simulate(AppLifecycleStatus.background);
      await flushEvents();
      expect(environment.client.current.phase, RealtimePhase.paused);
      environment.lifecycle.simulate(AppLifecycleStatus.foreground);
      await flushEvents(8);
      expect(environment.transport.connectionCount, 3);
      expect(environment.client.current.phase, RealtimePhase.connected);
      await environment.dispose();
    },
  );

  test('heartbeat detects stale connection and reconnects', () async {
    var now = DateTime.utc(2026);
    final environment = await RealtimeTestEnvironment.create(
      now: () => now,
      heartbeatInterval: const Duration(milliseconds: 2),
      heartbeatTimeout: const Duration(milliseconds: 5),
    );
    await environment.client.connect();
    now = now.add(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(environment.transport.connectionCount, greaterThanOrEqualTo(2));
    await environment.dispose();
  });

  test(
    'malformed, unknown and duplicate messages do not terminate stream',
    () async {
      final environment = await RealtimeTestEnvironment.create();
      await environment.client.connect();
      final received = <RealtimeMessage>[];
      final subscription = environment.client.messages.listen(received.add);
      final socket = environment.transport.latest!;
      socket
        ..incoming('{bad json')
        ..incoming(message('unknown-1', 'future.event', {}))
        ..incoming(
          message('task-1', 'demo_task.changed', {
            'taskId': 'task-1',
            'serverVersion': 1,
          }),
        )
        ..incoming(
          message('task-1', 'demo_task.changed', {
            'taskId': 'task-1',
            'serverVersion': 1,
          }),
        );
      await flushEvents();
      expect(received, hasLength(2));
      expect(received.first, isA<UnknownRealtimeMessage>());
      expect(received.last, isA<DemoTaskChangedMessage>());
      await subscription.cancel();
      await environment.dispose();
    },
  );

  test(
    'authentication expiry refreshes once and reconnects without loop',
    () async {
      var recoveries = 0;
      late RealtimeTestEnvironment environment;
      environment = await RealtimeTestEnvironment.create(
        recoverAuthentication: () async {
          recoveries++;
          await environment.tokens.write(
            const TokenPair(accessToken: 'new-access', refreshToken: 'refresh'),
          );
          return true;
        },
      );
      await environment.client.connect();
      environment.transport.latest!.incoming(
        message('auth-1', 'auth.expired', {}),
      );
      await flushEvents(10);
      expect(recoveries, 1);
      expect(environment.transport.connectionCount, 2);
      expect(environment.client.current.phase, RealtimePhase.connected);
      await environment.dispose();
    },
  );
}

String message(String id, String type, Map<String, Object?> payload) =>
    jsonEncode({
      'version': 1,
      'type': type,
      'id': id,
      'timestamp': DateTime.utc(2026).toIso8601String(),
      'payload': payload,
    });

class RealtimeTestEnvironment {
  RealtimeTestEnvironment._({
    required this.session,
    required this.tokens,
    required this.connectivity,
    required this.lifecycle,
    required this.transport,
    required this.client,
  });

  final UserSession session;
  final MemoryTokenStorage tokens;
  final FakeConnectivityService connectivity;
  final FakeAppLifecycleService lifecycle;
  final FakeWebSocketTransport transport;
  final RealtimeClient client;

  static Future<RealtimeTestEnvironment> create({
    DateTime Function()? now,
    Duration heartbeatInterval = const Duration(seconds: 1),
    Duration heartbeatTimeout = const Duration(seconds: 3),
    Future<bool> Function()? recoverAuthentication,
  }) async {
    final tokens = MemoryTokenStorage();
    final session = UserSession(
      tokenStorage: tokens,
      snapshotStorage: MemoryKeyValueStorage(),
    );
    await session.initialize();
    await session.setAuthenticated(
      user: const User(id: 'owner-a', email: 'a@example.invalid'),
      tokens: const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
    );
    final connectivity = FakeConnectivityService();
    final lifecycle = FakeAppLifecycleService();
    final transport = FakeWebSocketTransport();
    final client = RealtimeClient(
      transport: transport,
      parser: const RealtimeMessageParser(),
      session: session,
      tokenStorage: tokens,
      connectivity: connectivity,
      lifecycle: lifecycle,
      url: Uri.parse('wss://example.invalid/ws'),
      logger: TestAppLogger(),
      baseBackoff: const Duration(milliseconds: 1),
      maxBackoff: const Duration(milliseconds: 2),
      heartbeatInterval: heartbeatInterval,
      heartbeatTimeout: heartbeatTimeout,
      stableConnectionDuration: const Duration(milliseconds: 20),
      now: now,
      random: Random(1),
      recoverAuthentication: recoverAuthentication,
    )..start();
    return RealtimeTestEnvironment._(
      session: session,
      tokens: tokens,
      connectivity: connectivity,
      lifecycle: lifecycle,
      transport: transport,
      client: client,
    );
  }

  Future<void> dispose() async {
    await client.dispose();
    await disposeClientAlreadyClosed();
  }

  Future<void> disposeClientAlreadyClosed() async {
    await connectivity.dispose();
    await lifecycle.dispose();
    await session.dispose();
  }
}
