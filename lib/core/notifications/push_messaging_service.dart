class PushMessage {
  PushMessage({required this.id, required Map<String, String> data})
    : data = Map.unmodifiable(data);
  final String id;
  final Map<String, String> data;
}

abstract interface class PushMessagingService {
  String? get currentToken;
  Stream<String?> get tokenChanges;
  Stream<PushMessage> get foregroundMessages;
  Stream<String> get notificationOpens;
  Future<bool> requestPermission();
  Future<void> dispose();
}

class NoopPushMessagingService implements PushMessagingService {
  @override
  String? get currentToken => null;
  @override
  Stream<String?> get tokenChanges => const Stream.empty();
  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();
  @override
  Stream<String> get notificationOpens => const Stream.empty();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> dispose() async {}
}
