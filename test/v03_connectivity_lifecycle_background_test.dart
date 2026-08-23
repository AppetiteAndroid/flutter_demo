import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/app/session/user_data_boundary_coordinator.dart';
import 'package:flutter_starter/core/background/background_sync_handler.dart';
import 'package:flutter_starter/core/connectivity/connectivity_service.dart';
import 'package:flutter_starter/core/database/app_database.dart';
import 'package:flutter_starter/core/lifecycle/app_lifecycle_service.dart';
import 'package:flutter_starter/core/observability/analytics_service.dart';
import 'package:flutter_starter/core/observability/crash_reporter.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_starter/core/sync/sync_engine.dart';
import 'package:flutter_starter/features/offline_tasks/data/drift_offline_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'helpers/v03_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'connectivity distinguishes interface from backend reachability',
    () async {
      final interfaces = TestInterfaceSource(true);
      final probe = TestReachabilityProbe([
        const ReachabilityProbeResult(ReachabilityProbeStatus.reachable),
        const ReachabilityProbeResult(ReachabilityProbeStatus.unreachable),
      ]);
      final service = ProbingConnectivityService(
        interfaces: interfaces,
        probe: probe,
        debounce: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 50),
      );
      await service.start();
      expect(
        service.current.status,
        BackendConnectivityStatus.backendReachable,
      );
      interfaces.emit(false);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        service.current.status,
        BackendConnectivityStatus.interfaceUnavailable,
      );
      interfaces.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        service.current.status,
        BackendConnectivityStatus.backendUnreachable,
      );
      expect(probe.calls, 2);
      await service.dispose();
      await interfaces.dispose();
    },
  );

  test(
    'rapid interface noise is debounced into one reachability probe',
    () async {
      final interfaces = TestInterfaceSource(true);
      final probe = TestReachabilityProbe([
        const ReachabilityProbeResult(ReachabilityProbeStatus.reachable),
        const ReachabilityProbeResult(ReachabilityProbeStatus.reachable),
      ]);
      final service = ProbingConnectivityService(
        interfaces: interfaces,
        probe: probe,
        debounce: const Duration(milliseconds: 5),
      );
      await service.start();
      interfaces
        ..emit(false)
        ..emit(true)
        ..emit(false)
        ..emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(probe.calls, 2); // initial + one debounced restoration
      await service.dispose();
      await interfaces.dispose();
    },
  );

  test(
    'lifecycle normalizes duplicates, replays latest and disposes',
    () async {
      final service = FlutterAppLifecycleService()..start();
      final values = <AppLifecycleStatus>[];
      final subscription = service.stream.listen(values.add);
      service
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flushEvents();
      expect(
        values.where((value) => value == AppLifecycleStatus.background),
        hasLength(1),
      );
      expect(await service.stream.first, AppLifecycleStatus.foreground);
      await subscription.cancel();
      await service.dispose();
    },
  );

  test(
    'background handler maps bounded runner outcomes and rejects input',
    () async {
      final runner = TestBackgroundRunner();
      final handler = BackgroundSyncHandler(
        runner: runner,
        logger: TestAppLogger(),
      );
      expect(
        await handler.handle(taskType: 'unknown'),
        BackgroundTaskResult.failure,
      );
      runner.next = SyncRunOutcome.retry;
      expect(
        await handler.handle(
          taskType: 'offline_sync',
          input: {'maxOperations': 500},
          budget: const Duration(seconds: 1),
          now: () => DateTime.utc(2026),
        ),
        BackgroundTaskResult.retry,
      );
      expect(runner.maxOperations, 50);
      expect(
        runner.deadline,
        DateTime.utc(2026).add(const Duration(seconds: 1)),
      );
      runner.next = SyncRunOutcome.success;
      expect(
        await handler.handle(taskType: 'offline_sync'),
        BackgroundTaskResult.success,
      );
    },
  );

  test('rapid user switch hides and removes old owner data', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final session = await authenticatedSession('owner-a');
    final repository = DriftOfflineTaskRepository(
      database: database,
      session: session,
      idGenerator: SequenceIdGenerator(['task-a', 'op-a']),
    );
    await repository.create('Owner A');
    var clearedRoutes = 0;
    final coordinator = UserDataBoundaryCoordinator(
      session: session,
      tasks: repository,
      analytics: NoopAnalyticsService(),
      crashReporter: NoopCrashReporter(),
      clearProtectedRouteIntent: () => clearedRoutes++,
    )..start();
    await session.setAuthenticated(
      user: const User(id: 'owner-b', email: 'b@example.invalid'),
      tokens: const TokenPair(accessToken: 'b', refreshToken: 'b-refresh'),
    );
    expect(await repository.watchAll().first, isEmpty);
    await flushEvents(10);
    expect(await database.select(database.demoTasks).get(), isEmpty);
    expect(await database.select(database.outboxOperations).get(), isEmpty);
    expect(clearedRoutes, 1);
    await coordinator.dispose();
    await session.dispose();
    await database.close();
  });
}

class TestInterfaceSource implements NetworkInterfaceSource {
  TestInterfaceSource(bool initial)
    : _subject = BehaviorSubject.seeded(initial);

  final BehaviorSubject<bool> _subject;

  @override
  Stream<bool> get changes => _subject.stream;

  @override
  Future<bool> isAvailable() async => _subject.value;

  void emit(bool value) => _subject.add(value);

  Future<void> dispose() => _subject.close();
}

class TestReachabilityProbe implements BackendReachabilityProbe {
  TestReachabilityProbe(Iterable<ReachabilityProbeResult> values)
    : _values = values.iterator;

  final Iterator<ReachabilityProbeResult> _values;
  int calls = 0;

  @override
  Future<ReachabilityProbeResult> probe() async {
    calls++;
    if (!_values.moveNext()) throw StateError('Missing probe result');
    return _values.current;
  }
}

class TestBackgroundRunner implements BackgroundSyncRunner {
  SyncRunOutcome next = SyncRunOutcome.failure;
  int? maxOperations;
  DateTime? deadline;

  @override
  Future<SyncRunOutcome> runBounded({
    required int maxOperations,
    required DateTime deadline,
  }) async {
    this.maxOperations = maxOperations;
    this.deadline = deadline;
    return next;
  }
}
