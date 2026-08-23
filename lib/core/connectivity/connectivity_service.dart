import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

enum BackendConnectivityStatus {
  interfaceUnavailable,
  interfaceAvailableUnknown,
  backendReachable,
  backendUnreachable,
  rateLimited,
}

class BackendConnectivity {
  const BackendConnectivity(this.status, {this.checkedAt, this.retryAfter});

  final BackendConnectivityStatus status;
  final DateTime? checkedAt;
  final Duration? retryAfter;

  bool get canAttemptRequest =>
      status == BackendConnectivityStatus.backendReachable ||
      status == BackendConnectivityStatus.interfaceAvailableUnknown;

  @override
  bool operator ==(Object other) =>
      other is BackendConnectivity &&
      other.status == status &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(status, retryAfter);
}

abstract interface class ConnectivityService {
  BackendConnectivity get current;
  Stream<BackendConnectivity> get stream;
  Future<void> start();
  Future<void> checkReachability();
  Future<void> dispose();
}

abstract interface class NetworkInterfaceSource {
  Future<bool> isAvailable();
  Stream<bool> get changes;
}

class ConnectivityPlusInterfaceSource implements NetworkInterfaceSource {
  ConnectivityPlusInterfaceSource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isAvailable() async =>
      _hasInterface(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasInterface).distinct();

  static bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

enum ReachabilityProbeStatus { reachable, unreachable, rateLimited }

class ReachabilityProbeResult {
  const ReachabilityProbeResult(this.status, {this.retryAfter});

  final ReachabilityProbeStatus status;
  final Duration? retryAfter;
}

abstract interface class BackendReachabilityProbe {
  Future<ReachabilityProbeResult> probe();
}

class DioBackendReachabilityProbe implements BackendReachabilityProbe {
  const DioBackendReachabilityProbe(Dio dio, this.endpoint) : _dio = dio;

  final Dio _dio;
  final Uri endpoint;

  @override
  Future<ReachabilityProbeResult> probe() async {
    try {
      final response = await _dio.getUri<Object?>(
        endpoint,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null,
        ),
      );
      if (response.statusCode == 429) {
        final seconds = int.tryParse(
          response.headers.value('retry-after') ?? '',
        );
        return ReachabilityProbeResult(
          ReachabilityProbeStatus.rateLimited,
          retryAfter: seconds == null ? null : Duration(seconds: seconds),
        );
      }
      return ReachabilityProbeResult(
        response.statusCode != null && response.statusCode! < 500
            ? ReachabilityProbeStatus.reachable
            : ReachabilityProbeStatus.unreachable,
      );
    } on DioException {
      return const ReachabilityProbeResult(ReachabilityProbeStatus.unreachable);
    }
  }
}

class ProbingConnectivityService implements ConnectivityService {
  ProbingConnectivityService({
    required this.interfaces,
    required this.probe,
    this.debounce = const Duration(milliseconds: 350),
    this.timeout = const Duration(seconds: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NetworkInterfaceSource interfaces;
  final BackendReachabilityProbe probe;
  final Duration debounce;
  final Duration timeout;
  final DateTime Function() _now;
  final BehaviorSubject<BackendConnectivity> _subject = BehaviorSubject.seeded(
    const BackendConnectivity(
      BackendConnectivityStatus.interfaceAvailableUnknown,
    ),
  );
  StreamSubscription<bool>? _subscription;
  int _checkGeneration = 0;

  @override
  BackendConnectivity get current => _subject.value;

  @override
  Stream<BackendConnectivity> get stream => _subject.stream.distinct();

  @override
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = interfaces.changes
        .debounceTime(debounce)
        .distinct()
        .listen(_onInterfaceChanged);
    await _onInterfaceChanged(await interfaces.isAvailable());
  }

  Future<void> _onInterfaceChanged(bool available) async {
    if (!available) {
      _checkGeneration++;
      _emit(
        BackendConnectivity(
          BackendConnectivityStatus.interfaceUnavailable,
          checkedAt: _now().toUtc(),
        ),
      );
      return;
    }
    _emit(
      const BackendConnectivity(
        BackendConnectivityStatus.interfaceAvailableUnknown,
      ),
    );
    await checkReachability();
  }

  @override
  Future<void> checkReachability() async {
    if (current.status == BackendConnectivityStatus.interfaceUnavailable) {
      return;
    }
    final generation = ++_checkGeneration;
    ReachabilityProbeResult result;
    try {
      result = await probe.probe().timeout(timeout);
    } on TimeoutException {
      result = const ReachabilityProbeResult(
        ReachabilityProbeStatus.unreachable,
      );
    }
    if (generation != _checkGeneration || _subject.isClosed) return;
    final checkedAt = _now().toUtc();
    _emit(switch (result.status) {
      ReachabilityProbeStatus.reachable => BackendConnectivity(
        BackendConnectivityStatus.backendReachable,
        checkedAt: checkedAt,
      ),
      ReachabilityProbeStatus.unreachable => BackendConnectivity(
        BackendConnectivityStatus.backendUnreachable,
        checkedAt: checkedAt,
      ),
      ReachabilityProbeStatus.rateLimited => BackendConnectivity(
        BackendConnectivityStatus.rateLimited,
        checkedAt: checkedAt,
        retryAfter: result.retryAfter,
      ),
    });
  }

  void _emit(BackendConnectivity state) {
    if (!_subject.isClosed && state != _subject.value) _subject.add(state);
  }

  @override
  Future<void> dispose() async {
    _checkGeneration++;
    await _subscription?.cancel();
    await _subject.close();
  }
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({
    BackendConnectivity initial = const BackendConnectivity(
      BackendConnectivityStatus.backendReachable,
    ),
  }) : _subject = BehaviorSubject.seeded(initial);

  final BehaviorSubject<BackendConnectivity> _subject;
  int checkCount = 0;

  @override
  BackendConnectivity get current => _subject.value;

  @override
  Stream<BackendConnectivity> get stream => _subject.stream.distinct();

  @override
  Future<void> start() async {}

  void simulate(BackendConnectivity state) {
    if (!_subject.isClosed && state != _subject.value) _subject.add(state);
  }

  @override
  Future<void> checkReachability() async {
    checkCount++;
  }

  @override
  Future<void> dispose() => _subject.close();
}
