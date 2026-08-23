enum OfflineTaskSyncStatus { pending, synced, failed, conflict, unknown }

class OfflineTask {
  const OfflineTask({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    required this.isDeleted,
    required this.serverVersion,
    this.remoteId,
    this.serverUpdatedAt,
    this.blockedOperationId,
    this.safeErrorCode,
  });

  final String id;
  final String? remoteId;
  final String ownerUserId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? serverUpdatedAt;
  final int serverVersion;
  final OfflineTaskSyncStatus syncStatus;
  final bool isDeleted;
  final String? blockedOperationId;
  final String? safeErrorCode;
}

class OfflineSyncSummary {
  const OfflineSyncSummary({
    required this.pendingCount,
    required this.blockedCount,
    this.lastSuccessfulSyncAt,
  });

  const OfflineSyncSummary.empty()
    : pendingCount = 0,
      blockedCount = 0,
      lastSuccessfulSyncAt = null;

  final int pendingCount;
  final int blockedCount;
  final DateTime? lastSuccessfulSyncAt;
}

enum TaskConflictResolution { useServer, retryClient }
