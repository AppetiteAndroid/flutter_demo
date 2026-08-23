import 'sync_models.dart';

abstract interface class SyncStore {
  Future<void> recoverExpiredLeases(String ownerUserId, DateTime now);
  Future<List<SyncOperation>> eligible(
    String ownerUserId,
    DateTime now, {
    int limit,
  });
  Future<bool> acquireLease(
    SyncOperation operation,
    DateTime now,
    Duration leaseDuration,
  );
  Future<void> complete(
    SyncOperation operation,
    SyncRemoteResult result,
    DateTime now,
  );
  Future<void> releaseUnauthorized(SyncOperation operation);
  Future<void> markTransientFailure(
    SyncOperation operation, {
    required DateTime nextEligibleAt,
    required String safeCode,
    String? safeMessage,
  });
  Future<void> markPermanentFailure(
    SyncOperation operation, {
    required String reason,
    required String safeCode,
    String? safeMessage,
    Map<String, Object?>? conflictPayload,
  });
  Future<void> markSuccessfulCycle(String ownerUserId, DateTime at);
  Stream<int> watchPendingCount(String ownerUserId);
  Future<int> blockedCount(String ownerUserId);
  Future<List<SyncInspectionItem>> inspect(String ownerUserId);
}
