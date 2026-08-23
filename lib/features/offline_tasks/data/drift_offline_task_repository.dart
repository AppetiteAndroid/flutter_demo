import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../core/session/user_session.dart';
import '../domain/offline_task.dart';
import '../domain/offline_task_repository.dart';

abstract interface class IdGenerator {
  String next();
}

class SecureIdGenerator implements IdGenerator {
  SecureIdGenerator() : _random = Random.secure();

  final Random _random;

  @override
  String next() => List.generate(
    4,
    (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
  ).join();
}

class DriftOfflineTaskRepository implements OfflineTaskRepository {
  DriftOfflineTaskRepository({
    required this.database,
    required this.session,
    IdGenerator? idGenerator,
    DateTime Function()? now,
    this.syncRequested,
  }) : _ids = idGenerator ?? SecureIdGenerator(),
       _now = now ?? DateTime.now;

  final AppDatabase database;
  final UserSession session;
  final IdGenerator _ids;
  final DateTime Function() _now;
  Future<void> Function()? syncRequested;

  void attachSyncRequest(Future<void> Function() callback) {
    syncRequested = callback;
  }

  @override
  Stream<List<OfflineTask>> watchAll() => session.stream
      .switchMap<List<OfflineTask>>((state) {
        final owner = state.user?.id;
        if (!state.isAuthenticated || owner == null) {
          return Stream.value(const <OfflineTask>[]);
        }
        final query = database.select(database.demoTasks)
          ..where(
            (task) => task.ownerUserId.equals(owner) & task.isDeleted.not(),
          )
          ..orderBy([(task) => OrderingTerm.desc(task.updatedAt)]);
        final blocked = database.select(database.outboxOperations)
          ..where(
            (operation) =>
                operation.ownerUserId.equals(owner) &
                operation.blockedReason.isNotNull(),
          );
        return Rx.combineLatest2<
          List<DemoTask>,
          List<OutboxOperation>,
          List<OfflineTask>
        >(
          query.watch(),
          blocked.watch(),
          (rows, operations) => List<OfflineTask>.unmodifiable(
            rows.map((row) {
              final failure = operations
                  .where((operation) => operation.entityId == row.clientId)
                  .firstOrNull;
              return _toDomain(row, failure: failure);
            }),
          ),
        );
      })
      .distinct(_taskListsEqual);

  @override
  Stream<OfflineTask?> watchOne(String id) => session.stream.switchMap((state) {
    final owner = state.user?.id;
    if (!state.isAuthenticated || owner == null) {
      return Stream.value(null);
    }
    final query = database.select(database.demoTasks)
      ..where(
        (task) =>
            task.clientId.equals(id) &
            task.ownerUserId.equals(owner) &
            task.isDeleted.not(),
      );
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  });

  @override
  Stream<OfflineSyncSummary> watchSyncSummary() =>
      session.stream.switchMap((state) {
        final owner = state.user?.id;
        if (!state.isAuthenticated || owner == null) {
          return Stream.value(const OfflineSyncSummary.empty());
        }
        final outbox = database.select(database.outboxOperations)
          ..where((operation) => operation.ownerUserId.equals(owner));
        final metadata = database.select(database.syncMetadata)
          ..where((row) => row.ownerUserId.equals(owner));
        return Rx.combineLatest2<
          List<OutboxOperation>,
          SyncMetadataData?,
          OfflineSyncSummary
        >(
          outbox.watch(),
          metadata.watchSingleOrNull(),
          (operations, meta) => OfflineSyncSummary(
            pendingCount: operations
                .where((operation) => operation.blockedReason == null)
                .length,
            blockedCount: operations
                .where((operation) => operation.blockedReason != null)
                .length,
            lastSuccessfulSyncAt: meta?.lastSuccessfulSyncAt,
          ),
        );
      });

  @override
  Future<Result<OfflineTask>> create(String title) async {
    final owner = _authenticatedOwner;
    final normalized = title.trim();
    if (owner == null) return const Failure(UnauthorizedFailure());
    if (normalized.isEmpty || normalized.length > 200) {
      return Failure(
        ValidationFailure(message: 'Task title must contain 1–200 characters'),
      );
    }
    final id = _ids.next();
    final operationId = _ids.next();
    final now = _now().toUtc();
    try {
      await database.transaction(() async {
        await database
            .into(database.demoTasks)
            .insert(
              DemoTasksCompanion.insert(
                clientId: id,
                ownerUserId: owner,
                title: normalized,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.outboxOperations)
            .insert(
              OutboxOperationsCompanion.insert(
                operationId: operationId,
                ownerUserId: owner,
                entityId: id,
                operationKind: 'create',
                payload: _payload(
                  id: id,
                  title: normalized,
                  completed: false,
                  deleted: false,
                  serverVersion: 0,
                ),
                idempotencyKey: operationId,
                createdAt: now,
              ),
            );
      });
      final task = await _ownedTask(id, owner);
      unawaited(syncRequested?.call() ?? Future.value());
      return Success(_toDomain(task!));
    } catch (error) {
      return Failure(
        UnknownFailure('Could not save task: ${error.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void>> update(
    String id, {
    String? title,
    bool? isCompleted,
  }) async {
    final owner = _authenticatedOwner;
    if (owner == null) return const Failure(UnauthorizedFailure());
    final existing = await _ownedTask(id, owner);
    if (existing == null || existing.isDeleted) {
      return const Failure(NotFoundFailure());
    }
    final normalized = title?.trim();
    if (normalized != null && (normalized.isEmpty || normalized.length > 200)) {
      return Failure(
        ValidationFailure(message: 'Task title must contain 1–200 characters'),
      );
    }
    final nextTitle = normalized ?? existing.title;
    final nextCompleted = isCompleted ?? existing.isCompleted;
    final now = _now().toUtc();
    final operationId = _ids.next();
    try {
      await database.transaction(() async {
        await (database.update(database.demoTasks)..where(
              (task) =>
                  task.clientId.equals(id) & task.ownerUserId.equals(owner),
            ))
            .write(
              DemoTasksCompanion(
                title: Value(nextTitle),
                isCompleted: Value(nextCompleted),
                updatedAt: Value(now),
                syncStatus: const Value('pending'),
              ),
            );
        final coalescible =
            await (database.select(database.outboxOperations)
                  ..where(
                    (operation) =>
                        operation.ownerUserId.equals(owner) &
                        operation.entityId.equals(id) &
                        operation.attemptCount.equals(0) &
                        operation.processingStartedAt.isNull() &
                        operation.blockedReason.isNull() &
                        operation.operationKind.isIn(const [
                          'create',
                          'update',
                        ]),
                  )
                  ..orderBy([
                    (operation) => OrderingTerm.desc(operation.createdAt),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        final payload = _payload(
          id: id,
          title: nextTitle,
          completed: nextCompleted,
          deleted: false,
          serverVersion: existing.serverVersion,
        );
        if (coalescible != null) {
          await (database.update(database.outboxOperations)..where(
                (operation) =>
                    operation.operationId.equals(coalescible.operationId),
              ))
              .write(OutboxOperationsCompanion(payload: Value(payload)));
        } else {
          await database
              .into(database.outboxOperations)
              .insert(
                OutboxOperationsCompanion.insert(
                  operationId: operationId,
                  ownerUserId: owner,
                  entityId: id,
                  operationKind: 'update',
                  payload: payload,
                  idempotencyKey: operationId,
                  createdAt: now,
                ),
              );
        }
      });
      unawaited(syncRequested?.call() ?? Future.value());
      return const Success(null);
    } catch (error) {
      return Failure(
        UnknownFailure('Could not update task: ${error.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    final owner = _authenticatedOwner;
    if (owner == null) return const Failure(UnauthorizedFailure());
    final existing = await _ownedTask(id, owner);
    if (existing == null) return const Failure(NotFoundFailure());
    final now = _now().toUtc();
    final operationId = _ids.next();
    try {
      await database.transaction(() async {
        await (database.update(database.demoTasks)..where(
              (task) =>
                  task.clientId.equals(id) & task.ownerUserId.equals(owner),
            ))
            .write(
              DemoTasksCompanion(
                isDeleted: const Value(true),
                updatedAt: Value(now),
                syncStatus: const Value('pending'),
              ),
            );
        await database
            .into(database.outboxOperations)
            .insert(
              OutboxOperationsCompanion.insert(
                operationId: operationId,
                ownerUserId: owner,
                entityId: id,
                operationKind: 'delete',
                payload: _payload(
                  id: id,
                  title: existing.title,
                  completed: existing.isCompleted,
                  deleted: true,
                  serverVersion: existing.serverVersion,
                ),
                idempotencyKey: operationId,
                createdAt: now,
              ),
            );
      });
      unawaited(syncRequested?.call() ?? Future.value());
      return const Success(null);
    } catch (error) {
      return Failure(
        UnknownFailure('Could not delete task: ${error.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void>> retry(String operationId) async {
    final owner = _authenticatedOwner;
    if (owner == null) return const Failure(UnauthorizedFailure());
    final changed =
        await (database.update(database.outboxOperations)..where(
              (operation) =>
                  operation.operationId.equals(operationId) &
                  operation.ownerUserId.equals(owner),
            ))
            .write(
              const OutboxOperationsCompanion(
                blockedReason: Value(null),
                lastErrorCode: Value(null),
                lastErrorMessage: Value(null),
                nextEligibleAt: Value(null),
              ),
            );
    if (changed == 0) return const Failure(NotFoundFailure());
    unawaited(syncRequested?.call() ?? Future.value());
    return const Success(null);
  }

  @override
  Future<Result<void>> resolveConflict(
    String operationId,
    TaskConflictResolution resolution,
  ) async {
    final owner = _authenticatedOwner;
    if (owner == null) return const Failure(UnauthorizedFailure());
    final operation =
        await (database.select(database.outboxOperations)..where(
              (row) =>
                  row.operationId.equals(operationId) &
                  row.ownerUserId.equals(owner) &
                  row.blockedReason.equals('conflict'),
            ))
            .getSingleOrNull();
    if (operation == null) return const Failure(NotFoundFailure());
    String? serverTitle;
    bool? serverCompleted;
    int? serverVersion;
    DateTime? serverUpdatedAt;
    if (resolution == TaskConflictResolution.useServer) {
      try {
        final payload = jsonDecode(operation.payload);
        final conflict = payload is Map ? payload['_conflict'] : null;
        if (conflict is! Map ||
            conflict['title'] is! String ||
            conflict['completed'] is! bool ||
            conflict['serverVersion'] is! int ||
            conflict['serverUpdatedAt'] is! String) {
          return Failure(
            ValidationFailure(message: 'Conflict has no server snapshot'),
          );
        }
        serverTitle = conflict['title'] as String;
        serverCompleted = conflict['completed'] as bool;
        serverVersion = conflict['serverVersion'] as int;
        serverUpdatedAt = DateTime.tryParse(
          conflict['serverUpdatedAt'] as String,
        )?.toUtc();
        if (serverTitle.isEmpty || serverUpdatedAt == null) {
          return Failure(
            ValidationFailure(message: 'Conflict server snapshot is invalid'),
          );
        }
      } on FormatException {
        return Failure(
          ValidationFailure(message: 'Conflict server snapshot is invalid'),
        );
      }
    }
    await database.transaction(() async {
      if (resolution == TaskConflictResolution.useServer) {
        await (database.delete(
          database.outboxOperations,
        )..where((row) => row.operationId.equals(operationId))).go();
        await (database.update(
          database.demoTasks,
        )..where((task) => task.clientId.equals(operation.entityId))).write(
          DemoTasksCompanion(
            title: Value(serverTitle!),
            isCompleted: Value(serverCompleted!),
            serverVersion: Value(serverVersion!),
            serverUpdatedAt: Value(serverUpdatedAt!),
            syncStatus: const Value('synced'),
          ),
        );
      } else {
        await (database.update(
          database.outboxOperations,
        )..where((row) => row.operationId.equals(operationId))).write(
          OutboxOperationsCompanion(
            idempotencyKey: Value(_ids.next()),
            blockedReason: const Value(null),
            lastErrorCode: const Value(null),
            lastErrorMessage: const Value(null),
            attemptCount: const Value(0),
            nextEligibleAt: const Value(null),
          ),
        );
        await (database.update(database.demoTasks)
              ..where((task) => task.clientId.equals(operation.entityId)))
            .write(const DemoTasksCompanion(syncStatus: Value('pending')));
      }
    });
    unawaited(syncRequested?.call() ?? Future.value());
    return const Success(null);
  }

  @override
  Future<void> requestSync() async => syncRequested?.call();

  @override
  Future<void> clearOwnerData(String ownerUserId) =>
      database.transaction(() async {
        await (database.delete(
          database.demoTasks,
        )..where((task) => task.ownerUserId.equals(ownerUserId))).go();
        await (database.delete(
          database.syncMetadata,
        )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
      });

  String? get _authenticatedOwner =>
      session.isAuthenticated ? session.user?.id : null;

  Future<DemoTask?> _ownedTask(String id, String owner) =>
      (database.select(database.demoTasks)..where(
            (task) => task.clientId.equals(id) & task.ownerUserId.equals(owner),
          ))
          .getSingleOrNull();

  OfflineTask _toDomain(DemoTask row, {OutboxOperation? failure}) =>
      OfflineTask(
        id: row.clientId,
        remoteId: row.remoteId,
        ownerUserId: row.ownerUserId,
        title: row.title,
        isCompleted: row.isCompleted,
        createdAt: row.createdAt.toUtc(),
        updatedAt: row.updatedAt.toUtc(),
        serverUpdatedAt: row.serverUpdatedAt?.toUtc(),
        serverVersion: row.serverVersion,
        syncStatus: OfflineTaskSyncStatus.values.firstWhere(
          (status) => status.name == row.syncStatus,
          orElse: () => OfflineTaskSyncStatus.unknown,
        ),
        isDeleted: row.isDeleted,
        blockedOperationId: failure?.operationId,
        safeErrorCode: failure?.lastErrorCode,
      );

  String _payload({
    required String id,
    required String title,
    required bool completed,
    required bool deleted,
    required int serverVersion,
  }) => jsonEncode({
    'id': id,
    'title': title,
    'completed': completed,
    'deleted': deleted,
    'serverVersion': serverVersion,
  });

  static bool _taskListsEqual(List<OfflineTask> a, List<OfflineTask> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      final left = a[index], right = b[index];
      if (left.id != right.id ||
          left.title != right.title ||
          left.isCompleted != right.isCompleted ||
          left.updatedAt != right.updatedAt ||
          left.syncStatus != right.syncStatus ||
          left.blockedOperationId != right.blockedOperationId ||
          left.safeErrorCode != right.safeErrorCode) {
        return false;
      }
    }
    return true;
  }
}
