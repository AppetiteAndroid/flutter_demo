import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_store.dart';

class DriftSyncStore implements SyncStore {
  const DriftSyncStore(this.database);

  final AppDatabase database;

  @override
  Future<void> recoverExpiredLeases(String ownerUserId, DateTime now) async {
    await (database.update(database.outboxOperations)..where(
          (operation) =>
              operation.ownerUserId.equals(ownerUserId) &
              operation.leaseExpiresAt.isSmallerOrEqualValue(now.toUtc()),
        ))
        .write(
          const OutboxOperationsCompanion(
            processingStartedAt: Value(null),
            leaseExpiresAt: Value(null),
          ),
        );
  }

  @override
  Future<List<SyncOperation>> eligible(
    String ownerUserId,
    DateTime now, {
    int limit = 20,
  }) async {
    final utcNow = now.toUtc();
    final rows =
        await (database.select(database.outboxOperations)
              ..where(
                (operation) =>
                    operation.ownerUserId.equals(ownerUserId) &
                    operation.blockedReason.isNull() &
                    (operation.nextEligibleAt.isNull() |
                        operation.nextEligibleAt.isSmallerOrEqualValue(
                          utcNow,
                        )) &
                    (operation.processingStartedAt.isNull() |
                        operation.leaseExpiresAt.isSmallerOrEqualValue(utcNow)),
              )
              ..orderBy([(operation) => OrderingTerm.asc(operation.createdAt)])
              ..limit(limit))
            .get();
    final operations = <SyncOperation>[];
    for (final row in rows) {
      final parsed = _parse(row);
      if (parsed == null) {
        await _blockMalformed(row);
      } else {
        operations.add(parsed);
      }
    }
    return operations;
  }

  @override
  Future<bool> acquireLease(
    SyncOperation operation,
    DateTime now,
    Duration leaseDuration,
  ) async {
    final utcNow = now.toUtc();
    final changed =
        await (database.update(database.outboxOperations)..where(
              (row) =>
                  row.operationId.equals(operation.id) &
                  row.ownerUserId.equals(operation.ownerUserId) &
                  row.blockedReason.isNull() &
                  (row.processingStartedAt.isNull() |
                      row.leaseExpiresAt.isSmallerOrEqualValue(utcNow)),
            ))
            .write(
              OutboxOperationsCompanion(
                attemptCount: Value(operation.attemptCount + 1),
                processingStartedAt: Value(utcNow),
                leaseExpiresAt: Value(utcNow.add(leaseDuration)),
              ),
            );
    return changed == 1;
  }

  @override
  Future<void> complete(
    SyncOperation operation,
    SyncRemoteResult result,
    DateTime now,
  ) => database.transaction(() async {
    await (database.delete(
      database.outboxOperations,
    )..where((row) => row.operationId.equals(operation.id))).go();
    if (operation.kind == SyncOperationKind.delete) {
      final remaining = await _remaining(operation.entityId);
      if (remaining == 0) {
        await (database.delete(database.demoTasks)..where(
              (task) =>
                  task.clientId.equals(operation.entityId) &
                  task.ownerUserId.equals(operation.ownerUserId),
            ))
            .go();
      }
      return;
    }
    final remaining = await _remaining(operation.entityId);
    await (database.update(database.demoTasks)..where(
          (task) =>
              task.clientId.equals(operation.entityId) &
              task.ownerUserId.equals(operation.ownerUserId),
        ))
        .write(
          DemoTasksCompanion(
            remoteId: result.remoteId == null
                ? const Value.absent()
                : Value(result.remoteId),
            serverVersion: result.serverVersion == null
                ? const Value.absent()
                : Value(result.serverVersion!),
            serverUpdatedAt: result.serverUpdatedAt == null
                ? Value(now.toUtc())
                : Value(result.serverUpdatedAt!.toUtc()),
            syncStatus: Value(remaining == 0 ? 'synced' : 'pending'),
          ),
        );
  });

  @override
  Future<void> releaseUnauthorized(SyncOperation operation) =>
      (database.update(
        database.outboxOperations,
      )..where((row) => row.operationId.equals(operation.id))).write(
        const OutboxOperationsCompanion(
          processingStartedAt: Value(null),
          leaseExpiresAt: Value(null),
          lastErrorCode: Value('unauthorized'),
          lastErrorMessage: Value('Authentication required'),
        ),
      );

  @override
  Future<void> markTransientFailure(
    SyncOperation operation, {
    required DateTime nextEligibleAt,
    required String safeCode,
    String? safeMessage,
  }) =>
      (database.update(
        database.outboxOperations,
      )..where((row) => row.operationId.equals(operation.id))).write(
        OutboxOperationsCompanion(
          processingStartedAt: const Value(null),
          leaseExpiresAt: const Value(null),
          nextEligibleAt: Value(nextEligibleAt.toUtc()),
          lastErrorCode: Value(safeCode),
          lastErrorMessage: Value(safeMessage),
        ),
      );

  @override
  Future<void> markPermanentFailure(
    SyncOperation operation, {
    required String reason,
    required String safeCode,
    String? safeMessage,
    Map<String, Object?>? conflictPayload,
  }) => database.transaction(() async {
    await (database.update(
      database.outboxOperations,
    )..where((row) => row.operationId.equals(operation.id))).write(
      OutboxOperationsCompanion(
        processingStartedAt: const Value(null),
        leaseExpiresAt: const Value(null),
        blockedReason: Value(reason),
        lastErrorCode: Value(safeCode),
        lastErrorMessage: Value(safeMessage),
        payload: conflictPayload == null
            ? const Value.absent()
            : Value(
                jsonEncode({
                  ...operation.payload,
                  '_conflict': conflictPayload,
                }),
              ),
      ),
    );
    await (database.update(
      database.demoTasks,
    )..where((task) => task.clientId.equals(operation.entityId))).write(
      DemoTasksCompanion(
        syncStatus: Value(reason == 'conflict' ? 'conflict' : 'failed'),
      ),
    );
  });

  @override
  Future<void> markSuccessfulCycle(String ownerUserId, DateTime at) => database
      .into(database.syncMetadata)
      .insertOnConflictUpdate(
        SyncMetadataCompanion.insert(
          ownerUserId: ownerUserId,
          lastSuccessfulSyncAt: Value(at.toUtc()),
        ),
      );

  @override
  Stream<int> watchPendingCount(String ownerUserId) =>
      (database.select(database.outboxOperations)..where(
            (operation) =>
                operation.ownerUserId.equals(ownerUserId) &
                operation.blockedReason.isNull(),
          ))
          .watch()
          .map((rows) => rows.length)
          .distinct();

  @override
  Future<int> blockedCount(String ownerUserId) async =>
      (await (database.select(database.outboxOperations)..where(
                (operation) =>
                    operation.ownerUserId.equals(ownerUserId) &
                    operation.blockedReason.isNotNull(),
              ))
              .get())
          .length;

  @override
  Future<List<SyncInspectionItem>> inspect(String ownerUserId) async {
    final rows =
        await (database.select(database.outboxOperations)
              ..where((operation) => operation.ownerUserId.equals(ownerUserId))
              ..orderBy([(operation) => OrderingTerm.asc(operation.createdAt)]))
            .get();
    return List.unmodifiable(
      rows.map(
        (row) => SyncInspectionItem(
          operationId: row.operationId,
          entityId: row.entityId,
          kind: _kind(row.operationKind) ?? SyncOperationKind.update,
          attemptCount: row.attemptCount,
          isBlocked: row.blockedReason != null,
          safeErrorCode: row.lastErrorCode,
        ),
      ),
    );
  }

  Future<int> _remaining(String entityId) async => (await (database.select(
    database.outboxOperations,
  )..where((row) => row.entityId.equals(entityId))).get()).length;

  SyncOperation? _parse(OutboxOperation row) {
    final kind = _kind(row.operationKind);
    if (kind == null || row.payload.length > 4096) return null;
    try {
      final decoded = jsonDecode(row.payload);
      if (decoded is! Map<String, Object?> ||
          decoded['id'] is! String ||
          decoded['title'] is! String ||
          decoded['completed'] is! bool ||
          decoded['deleted'] is! bool ||
          decoded['serverVersion'] is! int) {
        return null;
      }
      return SyncOperation(
        id: row.operationId,
        ownerUserId: row.ownerUserId,
        entityType: row.entityType,
        entityId: row.entityId,
        kind: kind,
        payload: Map.unmodifiable(decoded),
        idempotencyKey: row.idempotencyKey,
        attemptCount: row.attemptCount,
      );
    } on FormatException {
      return null;
    }
  }

  SyncOperationKind? _kind(String value) =>
      SyncOperationKind.values.where((kind) => kind.name == value).firstOrNull;

  Future<void> _blockMalformed(OutboxOperation row) async {
    await (database.update(database.outboxOperations)
          ..where((operation) => operation.operationId.equals(row.operationId)))
        .write(
          const OutboxOperationsCompanion(
            blockedReason: Value('invalid_payload'),
            lastErrorCode: Value('invalid_payload'),
            lastErrorMessage: Value('Stored operation is invalid'),
          ),
        );
  }
}
