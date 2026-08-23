import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/realtime/realtime_models.dart';
import '../../../core/result/result.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_models.dart';
import '../domain/offline_task.dart';
import '../domain/offline_task_repository.dart';

sealed class OfflineTasksEvent {
  const OfflineTasksEvent();
}

final class OfflineTasksStarted extends OfflineTasksEvent {
  const OfflineTasksStarted();
}

final class OfflineTaskAdded extends OfflineTasksEvent {
  const OfflineTaskAdded(this.title);
  final String title;
}

final class OfflineTaskToggled extends OfflineTasksEvent {
  const OfflineTaskToggled(this.task);
  final OfflineTask task;
}

final class OfflineTaskDeleted extends OfflineTasksEvent {
  const OfflineTaskDeleted(this.id);
  final String id;
}

final class OfflineTaskRetried extends OfflineTasksEvent {
  const OfflineTaskRetried(this.operationId);
  final String operationId;
}

final class OfflineTaskConflictResolved extends OfflineTasksEvent {
  const OfflineTaskConflictResolved(this.operationId, this.resolution);
  final String operationId;
  final TaskConflictResolution resolution;
}

final class OfflineSyncRequested extends OfflineTasksEvent {
  const OfflineSyncRequested();
}

final class RealtimeConnectionToggled extends OfflineTasksEvent {
  const RealtimeConnectionToggled();
}

class OfflineTasksState {
  const OfflineTasksState({
    this.tasks = const [],
    this.summary = const OfflineSyncSummary.empty(),
    this.sync = const SyncEngineState(SyncPhase.idle),
    this.connectivity = const BackendConnectivity(
      BackendConnectivityStatus.interfaceAvailableUnknown,
    ),
    this.realtime = const RealtimeConnectionState(RealtimePhase.disconnected),
    this.commandFailure,
  });

  final List<OfflineTask> tasks;
  final OfflineSyncSummary summary;
  final SyncEngineState sync;
  final BackendConnectivity connectivity;
  final RealtimeConnectionState realtime;
  final String? commandFailure;

  OfflineTasksState copyWith({
    List<OfflineTask>? tasks,
    OfflineSyncSummary? summary,
    SyncEngineState? sync,
    BackendConnectivity? connectivity,
    RealtimeConnectionState? realtime,
    String? commandFailure,
    bool clearFailure = false,
  }) => OfflineTasksState(
    tasks: tasks ?? this.tasks,
    summary: summary ?? this.summary,
    sync: sync ?? this.sync,
    connectivity: connectivity ?? this.connectivity,
    realtime: realtime ?? this.realtime,
    commandFailure: clearFailure ? null : commandFailure ?? this.commandFailure,
  );
}

class OfflineTasksBloc extends Bloc<OfflineTasksEvent, OfflineTasksState> {
  OfflineTasksBloc({
    required this.repository,
    required this.syncEngine,
    required this.connectivity,
    required this.realtime,
  }) : super(const OfflineTasksState()) {
    on<OfflineTasksStarted>(_onStarted);
    on<OfflineTaskAdded>(_onAdd);
    on<OfflineTaskToggled>(_onToggle);
    on<OfflineTaskDeleted>(_onDelete);
    on<OfflineTaskRetried>(_onRetry);
    on<OfflineTaskConflictResolved>(_onResolve);
    on<OfflineSyncRequested>((_, _) => repository.requestSync());
    on<RealtimeConnectionToggled>(_onRealtimeToggle);
  }

  final OfflineTaskRepository repository;
  final SyncEngine syncEngine;
  final ConnectivityService connectivity;
  final RealtimeClient realtime;

  Future<void> _onStarted(
    OfflineTasksStarted event,
    Emitter<OfflineTasksState> emit,
  ) => emit.onEach(
    Rx.combineLatest5<
      List<OfflineTask>,
      OfflineSyncSummary,
      SyncEngineState,
      BackendConnectivity,
      RealtimeConnectionState,
      OfflineTasksState
    >(
      repository.watchAll(),
      repository.watchSyncSummary(),
      syncEngine.stream,
      connectivity.stream,
      realtime.state,
      (tasks, summary, sync, network, socket) => state.copyWith(
        tasks: tasks,
        summary: summary,
        sync: sync,
        connectivity: network,
        realtime: socket,
      ),
    ),
    onData: emit.call,
  );

  Future<void> _onAdd(
    OfflineTaskAdded event,
    Emitter<OfflineTasksState> emit,
  ) async => _apply(await repository.create(event.title), emit);

  Future<void> _onToggle(
    OfflineTaskToggled event,
    Emitter<OfflineTasksState> emit,
  ) async => _apply(
    await repository.update(
      event.task.id,
      isCompleted: !event.task.isCompleted,
    ),
    emit,
  );

  Future<void> _onDelete(
    OfflineTaskDeleted event,
    Emitter<OfflineTasksState> emit,
  ) async => _apply(await repository.delete(event.id), emit);

  Future<void> _onRetry(
    OfflineTaskRetried event,
    Emitter<OfflineTasksState> emit,
  ) async => _apply(await repository.retry(event.operationId), emit);

  Future<void> _onResolve(
    OfflineTaskConflictResolved event,
    Emitter<OfflineTasksState> emit,
  ) async => _apply(
    await repository.resolveConflict(event.operationId, event.resolution),
    emit,
  );

  Future<void> _onRealtimeToggle(
    RealtimeConnectionToggled event,
    Emitter<OfflineTasksState> emit,
  ) async {
    if (realtime.current.phase == RealtimePhase.connected ||
        realtime.current.phase == RealtimePhase.connecting ||
        realtime.current.phase == RealtimePhase.reconnecting) {
      await realtime.disconnect();
    } else {
      await realtime.connect();
    }
  }

  void _apply(Result<Object?> result, Emitter<OfflineTasksState> emit) {
    switch (result) {
      case Success():
        emit(state.copyWith(clearFailure: true));
      case Failure(:final error):
        emit(state.copyWith(commandFailure: _failureCode(error)));
    }
  }

  String _failureCode(AppFailure failure) => switch (failure) {
    UnauthorizedFailure() => 'unauthorized',
    ValidationFailure() => 'validation',
    NotFoundFailure() => 'not_found',
    _ => 'unknown',
  };
}
