import '../../../core/result/result.dart';
import 'offline_task.dart';

abstract interface class OfflineTaskRepository {
  Stream<List<OfflineTask>> watchAll();
  Stream<OfflineTask?> watchOne(String id);
  Stream<OfflineSyncSummary> watchSyncSummary();
  Future<Result<OfflineTask>> create(String title);
  Future<Result<void>> update(String id, {String? title, bool? isCompleted});
  Future<Result<void>> delete(String id);
  Future<Result<void>> retry(String operationId);
  Future<Result<void>> resolveConflict(
    String operationId,
    TaskConflictResolution resolution,
  );
  Future<void> requestSync();
  Future<void> clearOwnerData(String ownerUserId);
}
