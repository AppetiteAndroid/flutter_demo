import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import '../connectivity/connectivity_service.dart';
import '../error/app_failure.dart';
import '../lifecycle/app_lifecycle_service.dart';
import '../logger/app_logger.dart';
import '../result/result.dart';
import '../session/user_session.dart';
import '../storage/token_storage.dart';
import 'realtime_message_parser.dart';
import 'realtime_models.dart';
import 'websocket_transport.dart';

class RealtimeClient {
  RealtimeClient({
    required this.transport,
    required this.parser,
    required this.session,
    required this.tokenStorage,
    required this.connectivity,
    required this.lifecycle,
    required this.url,
    required this.logger,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(minutes: 1),
    this.heartbeatInterval = const Duration(seconds: 20),
    this.heartbeatTimeout = const Duration(seconds: 50),
    this.stableConnectionDuration = const Duration(seconds: 30),
    this.duplicateCacheSize = 100,
    DateTime Function()? now,
    Random? random,
    this.recoverAuthentication,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random();

  final WebSocketTransport transport;
  final RealtimeMessageParser parser;
  final UserSession session;
  final TokenStorage tokenStorage;
  final ConnectivityService connectivity;
  final AppLifecycleService lifecycle;
  final Uri url;
  final AppLogger logger;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final Duration heartbeatInterval;
  final Duration heartbeatTimeout;
  final Duration stableConnectionDuration;
  final int duplicateCacheSize;
  final DateTime Function() _now;
  final Random _random;
  final Future<bool> Function()? recoverAuthentication;
  final BehaviorSubject<RealtimeConnectionState> _state =
      BehaviorSubject.seeded(
        const RealtimeConnectionState(RealtimePhase.disconnected),
      );
  final PublishSubject<RealtimeMessage> _messages = PublishSubject();
  final LinkedHashSet<String> _seenMessageIds = LinkedHashSet();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StreamSubscription<Object?>? _socketSubscription;
  RealtimeSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _stableTimer;
  Future<void>? _connecting;
  DateTime? _lastActivity;
  bool _desired = false;
  bool _manualClose = false;
  bool _disposed = false;
  bool _authRecoveryAttempted = false;
  int _attempt = 0;
  String? _owner;
  int _tokenRevision = -1;

  RealtimeConnectionState get current => _state.value;
  Stream<RealtimeConnectionState> get state => _state.stream.distinct();
  Stream<RealtimeMessage> get messages => _messages.stream;

  void start() {
    if (_subscriptions.isNotEmpty || _disposed) return;
    _subscriptions.add(session.stream.listen(_onSession));
    _subscriptions.add(lifecycle.stream.listen(_onLifecycle));
    _subscriptions.add(connectivity.stream.listen(_onConnectivity));
  }

  Future<void> connect() async {
    if (_disposed) return;
    _desired = true;
    _manualClose = false;
    await _ensureConnected();
  }

  Future<void> _ensureConnected() {
    final existing = _connecting;
    if (existing != null) return existing;
    final future = _connectInternal();
    _connecting = future;
    return future.whenComplete(() => _connecting = null);
  }

  Future<void> _connectInternal() async {
    if (!_desired || _disposed || _socket != null) return;
    if (!session.isAuthenticated || session.user == null) {
      _emit(
        const RealtimeConnectionState(RealtimePhase.authenticationRequired),
      );
      return;
    }
    if (lifecycle.current != AppLifecycleStatus.foreground) {
      _emit(const RealtimeConnectionState(RealtimePhase.paused));
      return;
    }
    if (!connectivity.current.canAttemptRequest) {
      _emit(const RealtimeConnectionState(RealtimePhase.disconnected));
      return;
    }
    final tokens = await tokenStorage.read();
    if (tokens == null) {
      _emit(
        const RealtimeConnectionState(RealtimePhase.authenticationRequired),
      );
      return;
    }
    _emit(
      RealtimeConnectionState(
        _attempt == 0 ? RealtimePhase.connecting : RealtimePhase.reconnecting,
        attempt: _attempt,
      ),
    );
    try {
      final socket = await transport.connect(
        url: url,
        accessToken: tokens.accessToken,
      );
      if (!_desired || _disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _lastActivity = _now().toUtc();
      _emit(const RealtimeConnectionState(RealtimePhase.connected));
      _socketSubscription = socket.messages.listen(
        _onRawMessage,
        onError: (Object error, StackTrace stackTrace) {
          logger.warning('Realtime transport error: ${error.runtimeType}');
        },
        onDone: _onSocketDone,
      );
      _startHeartbeat();
      _stableTimer?.cancel();
      _stableTimer = Timer(stableConnectionDuration, () {
        _attempt = 0;
        _authRecoveryAttempted = false;
      });
    } catch (error) {
      logger.warning('Realtime connection failed: ${error.runtimeType}');
      _scheduleReconnect();
    }
  }

  void _onRawMessage(Object? raw) {
    _lastActivity = _now().toUtc();
    final message = parser.parse(raw);
    if (message == null) {
      logger.warning('Ignored malformed realtime message');
      return;
    }
    if (!_remember(message.id)) return;
    switch (message) {
      case PongMessage():
        return;
      case AuthenticationExpiredMessage():
        unawaited(_handleAuthenticationExpiry());
        return;
      case UnknownRealtimeMessage(:final type):
        logger.warning('Ignored unknown realtime type: $type');
        _messages.add(message);
      case DemoTaskChangedMessage():
        _messages.add(message);
    }
  }

  bool _remember(String id) {
    if (!_seenMessageIds.add(id)) return false;
    while (_seenMessageIds.length > duplicateCacheSize) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }
    return true;
  }

  Future<void> _handleAuthenticationExpiry() async {
    if (_authRecoveryAttempted) {
      await disconnect();
      _emit(
        const RealtimeConnectionState(RealtimePhase.authenticationRequired),
      );
      return;
    }
    _authRecoveryAttempted = true;
    final recovered = await recoverAuthentication?.call() ?? false;
    if (!recovered) {
      await session.invalidate();
      return;
    }
    await _closeSocket(manual: true);
    _manualClose = false;
    await _ensureConnected();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      final last = _lastActivity;
      if (last != null && _now().toUtc().difference(last) >= heartbeatTimeout) {
        logger.warning('Realtime heartbeat timeout');
        unawaited(_closeSocket(manual: false));
        return;
      }
      unawaited(
        _socket?.send(
              jsonEncode({
                'version': 1,
                'type': 'ping',
                'id': 'ping-${_now().toUtc().microsecondsSinceEpoch}',
                'timestamp': _now().toUtc().toIso8601String(),
                'payload': const <String, Object?>{},
              }),
            ) ??
            Future.value(),
      );
    });
  }

  void _onSocketDone() {
    _socket = null;
    _socketSubscription = null;
    _heartbeatTimer?.cancel();
    _stableTimer?.cancel();
    if (!_manualClose && _desired && !_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_desired || _manualClose || _disposed) return;
    _attempt++;
    final delay = _backoff(_attempt);
    _emit(
      RealtimeConnectionState(
        RealtimePhase.reconnecting,
        attempt: _attempt,
        nextDelay: delay,
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => unawaited(_ensureConnected()));
  }

  Duration _backoff(int attempt) {
    final raw = min(
      maxBackoff.inMilliseconds,
      baseBackoff.inMilliseconds * pow(2, min(attempt - 1, 20)).toInt(),
    );
    return Duration(
      milliseconds: max(1, (raw * (.8 + _random.nextDouble() * .4)).round()),
    );
  }

  void _onSession(UserSessionState sessionState) {
    final owner = sessionState.isAuthenticated ? sessionState.user?.id : null;
    if (owner == null) {
      _owner = null;
      _desired = false;
      unawaited(_closeSocket(manual: true));
      _emit(
        const RealtimeConnectionState(RealtimePhase.authenticationRequired),
      );
      return;
    }
    final credentialsChanged =
        owner != _owner || sessionState.tokenRevision != _tokenRevision;
    _owner = owner;
    _tokenRevision = sessionState.tokenRevision;
    if (_desired && credentialsChanged) {
      unawaited(_reconnectForCredentialChange());
    }
  }

  Future<void> _reconnectForCredentialChange() async {
    _authRecoveryAttempted = false;
    await _closeSocket(manual: true);
    _manualClose = false;
    await _ensureConnected();
  }

  void _onLifecycle(AppLifecycleStatus status) {
    if (status == AppLifecycleStatus.foreground) {
      if (_desired) unawaited(_ensureConnected());
    } else if (_desired) {
      unawaited(_pause());
    }
  }

  Future<void> _pause() async {
    await _closeSocket(manual: true);
    _manualClose = false;
    _emit(const RealtimeConnectionState(RealtimePhase.paused));
  }

  void _onConnectivity(BackendConnectivity connectivityState) {
    if (connectivityState.canAttemptRequest && _desired) {
      unawaited(_ensureConnected());
    } else if (!connectivityState.canAttemptRequest && _socket != null) {
      unawaited(_closeSocket(manual: false));
    }
  }

  Future<Result<void>> sendCommand(
    String type,
    Map<String, Object?> payload,
  ) async {
    final socket = _socket;
    if (socket == null || current.phase != RealtimePhase.connected) {
      return const Failure(NetworkFailure('Realtime is disconnected'));
    }
    if (type.isEmpty || payload.length > 50) {
      return Failure(ValidationFailure(message: 'Invalid command'));
    }
    try {
      await socket.send(
        jsonEncode({
          'version': 1,
          'type': type,
          'id': 'command-${_now().toUtc().microsecondsSinceEpoch}',
          'timestamp': _now().toUtc().toIso8601String(),
          'payload': payload,
        }),
      );
      return const Success(null);
    } catch (_) {
      return const Failure(NetworkFailure('Realtime send failed'));
    }
  }

  Future<void> disconnect() async {
    _desired = false;
    await _closeSocket(manual: true);
    _emit(const RealtimeConnectionState(RealtimePhase.disconnected));
  }

  Future<void> _closeSocket({required bool manual}) async {
    _manualClose = manual;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stableTimer?.cancel();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    await socket?.close();
    if (!manual && _desired && !_disposed) _scheduleReconnect();
  }

  void _emit(RealtimeConnectionState value) {
    if (!_state.isClosed && value != _state.value) _state.add(value);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _desired = false;
    await _closeSocket(manual: true);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _emit(const RealtimeConnectionState(RealtimePhase.disposed));
    await _messages.close();
    await _state.close();
  }
}
