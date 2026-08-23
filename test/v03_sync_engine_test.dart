import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_starter/core/connectivity/connectivity_service.dart';
import 'package:flutter_starter/core/database/app_database.dart';
import 'package:flutter_starter/core/lifecycle/app_lifecycle_service.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/sync/sync_engine.dart';
import 'package:flutter_starter/core/sync/sync_models.dart';
import 'package:flutter_starter/core/sync/sync_remote_data_source.dart';
import 'package:flutter_starter/features/offline_tasks/data/drift_offline_task_repository.dart';
import 'package:flutter_starter/features/offline_tasks/data/drift_sync_store.dart';
import 'package:flutter_starter/features/offline_tasks/domain/offline_task.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/v03_test_helpers.dart';

void main() {
  test('success reconciles task and removes outbox', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
    );
    await environment.repository.create('Synced');
    environment.engine.start();
    await environment.engine.requestSync();
    await flushEvents();
    expect(environment.remote.requestCount, 1);
    expect(await environment.store.inspect('owner-a'), isEmpty);
    final task = (await environment.repository.watchAll().first).single;
    expect(task.syncStatus, OfflineTaskSyncStatus.synced);
    expect(task.remoteId, 'remote-task-1');
    await environment.dispose();
  });

  test('transient failure uses injected short backoff and retries', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
      baseBackoff: const Duration(milliseconds: 1),
    );
    environment.remote
      ..enqueue(FakeSyncScenario.timeout)
      ..enqueue(FakeSyncScenario.success);
    await environment.repository.create('Retry');
    environment.engine.start();
    await environment.engine.requestSync();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(environment.remote.requestCount, 2);
    expect(await environment.store.inspect('owner-a'), isEmpty);
    expect(environment.engine.current.phase, SyncPhase.completed);
    await environment.dispose();
  });

  test('concurrent triggers share one serialized processing cycle', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
    );
    environment.remote.latency = const Duration(milliseconds: 5);
    await environment.repository.create('Serialized');
    environment.engine.start();
    await Future.wait([
      environment.engine.requestSync(),
      environment.engine.requestSync(),
      environment.engine.requestSync(),
    ]);
    await flushEvents();
    expect(environment.remote.requestCount, 1);
    await environment.dispose();
  });

  test('rate limit persists and exposes server retry-after', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
    );
    environment.remote.enqueue(FakeSyncScenario.rateLimited);
    await environment.repository.create('Rate limited');
    environment.engine.start();
    await environment.engine.requestSync();
    expect(environment.engine.current.phase, SyncPhase.waiting);
    expect(environment.engine.current.nextDelay, const Duration(seconds: 30));
    expect(environment.remote.requestCount, 1);
    await environment.dispose();
  });

  test(
    'permanent validation blocks one operation while next succeeds',
    () async {
      final environment = await SyncTestEnvironment.create(
        ids: ['task-1', 'op-1', 'task-2', 'op-2'],
      );
      environment.remote
        ..enqueue(FakeSyncScenario.validationFailure)
        ..enqueue(FakeSyncScenario.success);
      await environment.repository.create('Rejected');
      await environment.repository.create('Accepted');
      environment.engine.start();
      await environment.engine.requestSync();
      await flushEvents();
      final items = await environment.store.inspect('owner-a');
      expect(items, hasLength(1));
      expect(items.single.isBlocked, isTrue);
      expect(items.single.safeErrorCode, 'validation');
      final tasks = await environment.repository.watchAll().first;
      expect(
        tasks.map((task) => task.syncStatus),
        containsAll([
          OfflineTaskSyncStatus.failed,
          OfflineTaskSyncStatus.synced,
        ]),
      );
      expect(environment.engine.current.phase, SyncPhase.blocked);
      await environment.dispose();
    },
  );

  test('unauthorized pauses sync and invalidates terminal session', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
    );
    environment.remote.enqueue(FakeSyncScenario.unauthorized);
    await environment.repository.create('Auth');
    environment.engine.start();
    await environment.engine.requestSync();
    await flushEvents();
    expect(environment.session.isAuthenticated, isFalse);
    expect(environment.engine.current.phase, SyncPhase.authenticationRequired);
    expect(await environment.store.inspect('owner-a'), hasLength(1));
    await environment.dispose();
  });

  test('duplicate idempotency response completes safely', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
    );
    environment.remote.enqueue(FakeSyncScenario.duplicate);
    await environment.repository.create('Duplicate');
    environment.engine.start();
    await environment.engine.requestSync();
    await flushEvents();
    expect(await environment.store.inspect('owner-a'), isEmpty);
    expect(
      (await environment.repository.watchAll().first).single.syncStatus,
      OfflineTaskSyncStatus.synced,
    );
    await environment.dispose();
  });

  test(
    'conflict persists and retry-client resolution gets a new attempt',
    () async {
      final environment = await SyncTestEnvironment.create(
        ids: ['task-1', 'op-1', 'new-idempotency'],
      );
      environment.remote.enqueue(FakeSyncScenario.conflict);
      await environment.repository.create('Conflict');
      environment.engine.start();
      await environment.engine.requestSync();
      await flushEvents();
      final blocked = (await environment.store.inspect('owner-a')).single;
      expect(blocked.safeErrorCode, 'version_conflict');
      expect(
        (await environment.repository.watchAll().first).single.syncStatus,
        OfflineTaskSyncStatus.conflict,
      );
      await environment.repository.resolveConflict(
        blocked.operationId,
        TaskConflictResolution.retryClient,
      );
      environment.remote.enqueue(FakeSyncScenario.success);
      await environment.engine.requestSync();
      await flushEvents();
      expect(await environment.store.inspect('owner-a'), isEmpty);
      await environment.dispose();
    },
  );

  test('server conflict snapshot can be selected explicitly', () async {
    final environment = await SyncTestEnvironment.create(
      ids: ['task-1', 'op-1'],
    );
    environment.remote.enqueue(FakeSyncScenario.conflict);
    await environment.repository.create('Local copy');
    environment.engine.start();
    await environment.engine.requestSync();
    await flushEvents();
    final blocked = (await environment.store.inspect('owner-a')).single;
    await environment.repository.resolveConflict(
      blocked.operationId,
      TaskConflictResolution.useServer,
    );
    final task = (await environment.repository.watchAll().first).single;
    expect(task.title, 'Server copy');
    expect(task.isCompleted, isTrue);
    expect(task.serverVersion, 9);
    expect(task.syncStatus, OfflineTaskSyncStatus.synced);
    expect(await environment.store.inspect('owner-a'), isEmpty);
    await environment.dispose();
  });

  test(
    'expired processing lease recovers after simulated interruption',
    () async {
      final environment = await SyncTestEnvironment.create(
        ids: ['task-1', 'op-1'],
      );
      await environment.repository.create('Lease');
      final start = DateTime.utc(2026);
      final operation = (await environment.store.eligible(
        'owner-a',
        start,
      )).single;
      expect(
        await environment.store.acquireLease(
          operation,
          start,
          const Duration(minutes: 1),
        ),
        isTrue,
      );
      expect(
        await environment.store.eligible(
          'owner-a',
          start.add(const Duration(seconds: 30)),
        ),
        isEmpty,
      );
      final recoveredAt = start.add(const Duration(minutes: 2));
      await environment.store.recoverExpiredLeases('owner-a', recoveredAt);
      expect(
        await environment.store.eligible('owner-a', recoveredAt),
        hasLength(1),
      );
      await environment.dispose();
    },
  );

  test(
    'connectivity restoration triggers one serialized eligible cycle',
    () async {
      final environment = await SyncTestEnvironment.create(
        ids: ['task-1', 'op-1'],
        initialConnectivity: const BackendConnectivity(
          BackendConnectivityStatus.interfaceUnavailable,
        ),
      );
      await environment.repository.create('Offline');
      environment.engine.start();
      await flushEvents();
      expect(environment.remote.requestCount, 0);
      environment.connectivity.simulate(
        const BackendConnectivity(BackendConnectivityStatus.backendReachable),
      );
      await flushEvents(10);
      expect(environment.remote.requestCount, 1);
      expect(await environment.store.inspect('owner-a'), isEmpty);
      await environment.dispose();
    },
  );
}

class SyncTestEnvironment {
  SyncTestEnvironment._({
    required this.database,
    required this.session,
    required this.repository,
    required this.store,
    required this.remote,
    required this.connectivity,
    required this.lifecycle,
    required this.engine,
  });

  final AppDatabase database;
  final UserSession session;
  final DriftOfflineTaskRepository repository;
  final DriftSyncStore store;
  final FakeSyncRemoteDataSource remote;
  final FakeConnectivityService connectivity;
  final FakeAppLifecycleService lifecycle;
  final SyncEngine engine;

  static Future<SyncTestEnvironment> create({
    required List<String> ids,
    Duration baseBackoff = const Duration(milliseconds: 5),
    BackendConnectivity initialConnectivity = const BackendConnectivity(
      BackendConnectivityStatus.backendReachable,
    ),
  }) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final session = await authenticatedSession();
    final repository = DriftOfflineTaskRepository(
      database: database,
      session: session,
      idGenerator: SequenceIdGenerator(ids),
      now: () => DateTime.now().toUtc(),
    );
    final store = DriftSyncStore(database);
    final remote = FakeSyncRemoteDataSource();
    final connectivity = FakeConnectivityService(initial: initialConnectivity);
    final lifecycle = FakeAppLifecycleService();
    final engine = SyncEngine(
      store: store,
      remote: remote,
      session: session,
      connectivity: connectivity,
      lifecycle: lifecycle,
      logger: TestAppLogger(),
      baseBackoff: baseBackoff,
      maxBackoff: baseBackoff,
      random: Random(1),
    );
    return SyncTestEnvironment._(
      database: database,
      session: session,
      repository: repository,
      store: store,
      remote: remote,
      connectivity: connectivity,
      lifecycle: lifecycle,
      engine: engine,
    );
  }

  Future<void> dispose() async {
    await engine.dispose();
    await connectivity.dispose();
    await lifecycle.dispose();
    await session.dispose();
    await database.close();
  }
}
