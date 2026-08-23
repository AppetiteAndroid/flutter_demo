enum SyncOperationKind { create, update, delete }

class SyncOperation {
  SyncOperation({
    required this.id,
    required this.ownerUserId,
    required this.entityType,
    required this.entityId,
    required this.kind,
    required Map<String, Object?> payload,
    required this.idempotencyKey,
    required this.attemptCount,
  }) : payload = Map.unmodifiable(payload);

  final String id;
  final String ownerUserId;
  final String entityType;
  final String entityId;
  final SyncOperationKind kind;
  final Map<String, Object?> payload;
  final String idempotencyKey;
  final int attemptCount;
}

enum SyncRemoteOutcome {
  success,
  duplicate,
  transientFailure,
  unauthorized,
  validationFailure,
  conflict,
  rateLimited,
}

class SyncRemoteResult {
  SyncRemoteResult({
    required this.outcome,
    this.remoteId,
    this.serverVersion,
    this.serverUpdatedAt,
    this.safeErrorCode,
    this.safeErrorMessage,
    this.retryAfter,
    Map<String, Object?>? conflictPayload,
  }) : conflictPayload = conflictPayload == null
           ? null
           : Map.unmodifiable(conflictPayload);

  const SyncRemoteResult.success({
    this.remoteId,
    this.serverVersion,
    this.serverUpdatedAt,
  }) : outcome = SyncRemoteOutcome.success,
       safeErrorCode = null,
       safeErrorMessage = null,
       retryAfter = null,
       conflictPayload = null;

  final SyncRemoteOutcome outcome;
  final String? remoteId;
  final int? serverVersion;
  final DateTime? serverUpdatedAt;
  final String? safeErrorCode;
  final String? safeErrorMessage;
  final Duration? retryAfter;
  final Map<String, Object?>? conflictPayload;
}

enum SyncPhase {
  idle,
  waiting,
  syncing,
  offline,
  authenticationRequired,
  blocked,
  completed,
  stopped,
  disposed,
}

class SyncEngineState {
  const SyncEngineState(
    this.phase, {
    this.processed = 0,
    this.failed = 0,
    this.nextDelay,
    this.safeMessage,
  });

  final SyncPhase phase;
  final int processed;
  final int failed;
  final Duration? nextDelay;
  final String? safeMessage;

  @override
  bool operator ==(Object other) =>
      other is SyncEngineState &&
      other.phase == phase &&
      other.processed == processed &&
      other.failed == failed &&
      other.nextDelay == nextDelay &&
      other.safeMessage == safeMessage;

  @override
  int get hashCode =>
      Object.hash(phase, processed, failed, nextDelay, safeMessage);
}

class SyncInspectionItem {
  const SyncInspectionItem({
    required this.operationId,
    required this.entityId,
    required this.kind,
    required this.attemptCount,
    required this.isBlocked,
    this.safeErrorCode,
  });

  final String operationId;
  final String entityId;
  final SyncOperationKind kind;
  final int attemptCount;
  final bool isBlocked;
  final String? safeErrorCode;
}
