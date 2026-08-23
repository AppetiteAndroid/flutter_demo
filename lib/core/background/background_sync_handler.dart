import '../logger/app_logger.dart';
import '../sync/sync_engine.dart';

enum BackgroundTaskResult { success, retry, failure }

class BackgroundSyncHandler {
  const BackgroundSyncHandler({required this.runner, required this.logger});

  final BackgroundSyncRunner runner;
  final AppLogger logger;

  Future<BackgroundTaskResult> handle({
    required String taskType,
    Map<String, Object?> input = const {},
    Duration budget = const Duration(seconds: 20),
    DateTime Function()? now,
  }) async {
    if (taskType != 'offline_sync' || budget <= Duration.zero) {
      logger.warning('Rejected unsupported or invalid background task');
      return BackgroundTaskResult.failure;
    }
    final requested = input['maxOperations'];
    final maxOperations = requested is int ? requested.clamp(1, 50) : 10;
    final clock = now ?? DateTime.now;
    final outcome = await runner.runBounded(
      maxOperations: maxOperations,
      deadline: clock().toUtc().add(budget),
    );
    return switch (outcome) {
      SyncRunOutcome.success => BackgroundTaskResult.success,
      SyncRunOutcome.retry => BackgroundTaskResult.retry,
      SyncRunOutcome.failure => BackgroundTaskResult.failure,
    };
  }
}
