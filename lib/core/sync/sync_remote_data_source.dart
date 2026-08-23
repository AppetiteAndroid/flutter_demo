import 'dart:async';

import 'sync_models.dart';

abstract interface class SyncRemoteDataSource {
  Future<SyncRemoteResult> send(SyncOperation operation);
}

enum FakeSyncScenario {
  success,
  offline,
  timeout,
  unauthorized,
  validationFailure,
  conflict,
  rateLimited,
  duplicate,
}

class FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  FakeSyncRemoteDataSource({
    this.latency = Duration.zero,
    this.defaultScenario = FakeSyncScenario.success,
  });

  Duration latency;
  FakeSyncScenario defaultScenario;
  final List<FakeSyncScenario> _queued = [];
  final Map<String, SyncRemoteResult> _completed = {};
  int requestCount = 0;

  void enqueue(FakeSyncScenario scenario) => _queued.add(scenario);

  void reset() {
    _queued.clear();
    _completed.clear();
    requestCount = 0;
    latency = Duration.zero;
    defaultScenario = FakeSyncScenario.success;
  }

  @override
  Future<SyncRemoteResult> send(SyncOperation operation) async {
    requestCount++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final previous = _completed[operation.idempotencyKey];
    if (previous != null) {
      return SyncRemoteResult(
        outcome: SyncRemoteOutcome.duplicate,
        remoteId: previous.remoteId,
        serverVersion: previous.serverVersion,
        serverUpdatedAt: previous.serverUpdatedAt,
      );
    }
    final scenario = _queued.isEmpty ? defaultScenario : _queued.removeAt(0);
    final result = switch (scenario) {
      FakeSyncScenario.success => SyncRemoteResult.success(
        remoteId: 'remote-${operation.entityId}',
        serverVersion: (operation.payload['serverVersion'] as int) + 1,
        serverUpdatedAt: DateTime.utc(2026, 1, 1),
      ),
      FakeSyncScenario.offline => SyncRemoteResult(
        outcome: SyncRemoteOutcome.transientFailure,
        safeErrorCode: 'offline',
        safeErrorMessage: 'Backend unavailable',
      ),
      FakeSyncScenario.timeout => SyncRemoteResult(
        outcome: SyncRemoteOutcome.transientFailure,
        safeErrorCode: 'timeout',
        safeErrorMessage: 'Request timed out',
      ),
      FakeSyncScenario.unauthorized => SyncRemoteResult(
        outcome: SyncRemoteOutcome.unauthorized,
        safeErrorCode: 'unauthorized',
        safeErrorMessage: 'Authentication required',
      ),
      FakeSyncScenario.validationFailure => SyncRemoteResult(
        outcome: SyncRemoteOutcome.validationFailure,
        safeErrorCode: 'validation',
        safeErrorMessage: 'Task was rejected',
      ),
      FakeSyncScenario.conflict => SyncRemoteResult(
        outcome: SyncRemoteOutcome.conflict,
        safeErrorCode: 'version_conflict',
        safeErrorMessage: 'Server version changed',
        conflictPayload: {
          'title': 'Server copy',
          'completed': true,
          'serverVersion': 9,
          'serverUpdatedAt': '2026-01-02T00:00:00.000Z',
        },
      ),
      FakeSyncScenario.rateLimited => SyncRemoteResult(
        outcome: SyncRemoteOutcome.rateLimited,
        safeErrorCode: 'rate_limited',
        safeErrorMessage: 'Try again later',
        retryAfter: Duration(seconds: 30),
      ),
      FakeSyncScenario.duplicate => SyncRemoteResult(
        outcome: SyncRemoteOutcome.duplicate,
        serverVersion: 1,
      ),
    };
    if (result.outcome == SyncRemoteOutcome.success) {
      _completed[operation.idempotencyKey] = result;
    }
    return result;
  }
}
