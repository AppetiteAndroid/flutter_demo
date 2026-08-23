enum RealtimePhase {
  disconnected,
  connecting,
  connected,
  reconnecting,
  paused,
  authenticationRequired,
  failed,
  disposed,
}

class RealtimeConnectionState {
  const RealtimeConnectionState(
    this.phase, {
    this.attempt = 0,
    this.nextDelay,
    this.safeMessage,
  });

  final RealtimePhase phase;
  final int attempt;
  final Duration? nextDelay;
  final String? safeMessage;

  @override
  bool operator ==(Object other) =>
      other is RealtimeConnectionState &&
      other.phase == phase &&
      other.attempt == attempt &&
      other.nextDelay == nextDelay &&
      other.safeMessage == safeMessage;

  @override
  int get hashCode => Object.hash(phase, attempt, nextDelay, safeMessage);
}

sealed class RealtimeMessage {
  const RealtimeMessage({
    required this.version,
    required this.type,
    required this.id,
    required this.timestamp,
  });

  final int version;
  final String type;
  final String id;
  final DateTime timestamp;
}

final class DemoTaskChangedMessage extends RealtimeMessage {
  const DemoTaskChangedMessage({
    required super.version,
    required super.type,
    required super.id,
    required super.timestamp,
    required this.taskId,
    required this.serverVersion,
  });

  final String taskId;
  final int serverVersion;
}

final class PongMessage extends RealtimeMessage {
  const PongMessage({
    required super.version,
    required super.type,
    required super.id,
    required super.timestamp,
  });
}

final class AuthenticationExpiredMessage extends RealtimeMessage {
  const AuthenticationExpiredMessage({
    required super.version,
    required super.type,
    required super.id,
    required super.timestamp,
  });
}

final class UnknownRealtimeMessage extends RealtimeMessage {
  const UnknownRealtimeMessage({
    required super.version,
    required super.type,
    required super.id,
    required super.timestamp,
  });
}
