import 'dart:async';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import '../connectivity/connectivity_service.dart';
import '../lifecycle/app_lifecycle_service.dart';
import '../logger/app_logger.dart';
import '../session/user_session.dart';
import 'sync_models.dart';
import 'sync_remote_data_source.dart';
import 'sync_store.dart';

enum SyncRunOutcome { success, retry, failure }

abstract interface class BackgroundSyncRunner {
  Future<SyncRunOutcome> runBounded({
    required int maxOperations,
    required DateTime deadline,
  });
}

class SyncEngine implements BackgroundSyncRunner {
  SyncEngine({
    required this.store,
    required this.remote,
    required this.session,
    required this.connectivity,
    required this.lifecycle,
    required this.logger,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(minutes: 2),
    this.leaseDuration = const Duration(minutes: 2),
    DateTime Function()? now,
    Random? random,
    this.recoverAuthentication,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random();

  final SyncStore store;
  final SyncRemoteDataSource remote;
  final UserSession session;
  final ConnectivityService connectivity;
  final AppLifecycleService lifecycle;
  final AppLogger logger;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final Duration leaseDuration;
  final DateTime Function() _now;
  final Random _random;
  final Future<bool> Function()? recoverAuthentication;
  final BehaviorSubject<SyncEngineState> _subject = BehaviorSubject.seeded(
    const SyncEngineState(SyncPhase.idle),
  );
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StreamSubscription<int>? _pendingSubscription;
  Timer? _retryTimer;
  Future<void>? _activeRun;
  bool _rerunRequested = false;
  bool _started = false;
  bool _stopped = false;
  String? _owner;

  SyncEngineState get current => _subject.value;
  Stream<SyncEngineState> get stream => _subject.stream.distinct();

  void start() {
    if (_started) return;
    _started = true;
    // Seed owner synchronously so an explicit startup refresh cannot race the
    // replayed session event and incorrectly report authentication-required.
    unawaited(_onSession(session.current));
    _subscriptions.add(
      session.stream.listen((state) => unawaited(_onSession(state))),
    );
    _subscriptions.add(
      connectivity.stream.listen((state) {
        if (state.status == BackendConnectivityStatus.backendReachable) {
          unawaited(requestSync());
        } else if (state.status ==
            BackendConnectivityStatus.interfaceUnavailable) {
          _emit(const SyncEngineState(SyncPhase.offline));
        }
      }),
    );
    _subscriptions.add(
      lifecycle.stream.listen((state) {
        if (state == AppLifecycleStatus.foreground) {
          unawaited(connectivity.checkReachability());
          unawaited(requestSync());
        }
      }),
    );
  }

  Future<void> _onSession(UserSessionState state) async {
    final nextOwner = state.isAuthenticated ? state.user?.id : null;
    if (nextOwner == _owner) return;
    _owner = nextOwner;
    await _pendingSubscription?.cancel();
    _pendingSubscription = null;
    _retryTimer?.cancel();
    if (nextOwner == null) {
      _emit(const SyncEngineState(SyncPhase.authenticationRequired));
      return;
    }
    _pendingSubscription = store.watchPendingCount(nextOwner).listen((count) {
      if (count > 0) unawaited(requestSync());
    });
    await requestSync();
  }

  Future<void> requestSync() {
    if (_stopped || _subject.isClosed) return Future.value();
    final existing = _activeRun;
    if (existing != null) {
      _rerunRequested = true;
      return existing;
    }
    final run = _runCycle(maxOperations: 100);
    _activeRun = run;
    return run.whenComplete(() {
      _activeRun = null;
      if (_retryTimer?.isActive == true) {
        _rerunRequested = false;
        return;
      }
      if (_rerunRequested && !_stopped) {
        _rerunRequested = false;
        unawaited(requestSync());
      }
    });
  }

  Future<SyncRunOutcome> _process({
    required int maxOperations,
    DateTime? deadline,
  }) async {
    final owner = _owner;
    if (owner == null || !session.isAuthenticated) {
      _emit(const SyncEngineState(SyncPhase.authenticationRequired));
      return SyncRunOutcome.failure;
    }
    if (lifecycle.current != AppLifecycleStatus.foreground &&
        deadline == null) {
      _emit(const SyncEngineState(SyncPhase.waiting));
      return SyncRunOutcome.retry;
    }
    if (!connectivity.current.canAttemptRequest) {
      _emit(const SyncEngineState(SyncPhase.offline));
      return SyncRunOutcome.retry;
    }
    final now = _now().toUtc();
    await store.recoverExpiredLeases(owner, now);
    var processed = 0, failed = 0;
    var hadTransient = false;
    _emit(const SyncEngineState(SyncPhase.syncing));
    while (processed + failed < maxOperations &&
        (deadline == null || _now().toUtc().isBefore(deadline))) {
      final operations = await store.eligible(owner, _now().toUtc(), limit: 1);
      if (operations.isEmpty) break;
      final operation = operations.single;
      final acquired = await store.acquireLease(
        operation,
        _now().toUtc(),
        leaseDuration,
      );
      if (!acquired) continue;
      SyncRemoteResult result;
      try {
        result = await remote.send(operation);
      } catch (error, stackTrace) {
        logger.error('Sync transport failed safely', error, stackTrace);
        result = SyncRemoteResult(
          outcome: SyncRemoteOutcome.transientFailure,
          safeErrorCode: 'transport',
          safeErrorMessage: 'Temporary sync failure',
        );
      }
      switch (result.outcome) {
        case SyncRemoteOutcome.success:
        case SyncRemoteOutcome.duplicate:
          await store.complete(operation, result, _now().toUtc());
          processed++;
        case SyncRemoteOutcome.transientFailure:
        case SyncRemoteOutcome.rateLimited:
          final delay =
              result.retryAfter ?? _backoff(operation.attemptCount + 1);
          await store.markTransientFailure(
            operation,
            nextEligibleAt: _now().toUtc().add(delay),
            safeCode: result.safeErrorCode ?? 'transient',
            safeMessage: result.safeErrorMessage,
          );
          _scheduleRetry(delay);
          _emit(
            SyncEngineState(
              SyncPhase.waiting,
              processed: processed,
              failed: failed,
              nextDelay: delay,
              safeMessage: result.safeErrorMessage,
            ),
          );
          hadTransient = true;
          failed++;
          return SyncRunOutcome.retry;
        case SyncRemoteOutcome.unauthorized:
          await store.releaseUnauthorized(operation);
          _emit(const SyncEngineState(SyncPhase.authenticationRequired));
          final recovered = await recoverAuthentication?.call() ?? false;
          if (recovered) {
            _rerunRequested = true;
          } else {
            await session.invalidate();
          }
          return SyncRunOutcome.failure;
        case SyncRemoteOutcome.validationFailure:
        case SyncRemoteOutcome.conflict:
          final conflict = result.outcome == SyncRemoteOutcome.conflict;
          await store.markPermanentFailure(
            operation,
            reason: conflict ? 'conflict' : 'validation',
            safeCode:
                result.safeErrorCode ?? (conflict ? 'conflict' : 'validation'),
            safeMessage: result.safeErrorMessage,
            conflictPayload: conflict ? result.conflictPayload : null,
          );
          failed++;
      }
    }
    final blocked = await store.blockedCount(owner);
    if (processed > 0 && !hadTransient) {
      await store.markSuccessfulCycle(owner, _now().toUtc());
    }
    _emit(
      SyncEngineState(
        blocked > 0 ? SyncPhase.blocked : SyncPhase.completed,
        processed: processed,
        failed: failed,
      ),
    );
    return blocked > 0 ? SyncRunOutcome.failure : SyncRunOutcome.success;
  }

  Future<void> _runCycle({required int maxOperations}) async {
    await _process(maxOperations: maxOperations);
  }

  @override
  Future<SyncRunOutcome> runBounded({
    required int maxOperations,
    required DateTime deadline,
  }) => _process(maxOperations: maxOperations, deadline: deadline.toUtc());

  Duration _backoff(int attempt) {
    final exponent = min(attempt - 1, 20);
    final raw = min(
      maxBackoff.inMilliseconds,
      baseBackoff.inMilliseconds * pow(2, exponent).toInt(),
    );
    final jitter = .8 + (_random.nextDouble() * .4);
    return Duration(milliseconds: max(1, (raw * jitter).round()));
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(requestSync()));
  }

  void _emit(SyncEngineState state) {
    if (!_subject.isClosed && state != _subject.value) _subject.add(state);
  }

  Future<void> stop() async {
    _stopped = true;
    _retryTimer?.cancel();
    await _pendingSubscription?.cancel();
    await _activeRun;
    _emit(const SyncEngineState(SyncPhase.stopped));
  }

  Future<void> dispose() async {
    await stop();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _emit(const SyncEngineState(SyncPhase.disposed));
    await _subject.close();
  }
}
