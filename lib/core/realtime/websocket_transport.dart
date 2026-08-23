import 'dart:async';

import 'package:web_socket_channel/io.dart';

abstract interface class RealtimeSocket {
  Stream<Object?> get messages;
  Future<void> send(Object data);
  Future<void> close();
}

abstract interface class WebSocketTransport {
  Future<RealtimeSocket> connect({
    required Uri url,
    required String accessToken,
  });
}

class IoWebSocketTransport implements WebSocketTransport {
  const IoWebSocketTransport();

  @override
  Future<RealtimeSocket> connect({
    required Uri url,
    required String accessToken,
  }) async {
    final channel = IOWebSocketChannel.connect(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    await channel.ready;
    return _ChannelRealtimeSocket(channel);
  }
}

class _ChannelRealtimeSocket implements RealtimeSocket {
  const _ChannelRealtimeSocket(this.channel);

  final IOWebSocketChannel channel;

  @override
  Stream<Object?> get messages => channel.stream;

  @override
  Future<void> send(Object data) async => channel.sink.add(data);

  @override
  Future<void> close() => channel.sink.close();
}

class FakeWebSocketTransport implements WebSocketTransport {
  final List<FakeRealtimeSocket> sockets = [];
  final List<Uri> urls = [];
  int connectionCount = 0;
  Object? nextConnectError;

  FakeRealtimeSocket? get latest => sockets.lastOrNull;

  @override
  Future<RealtimeSocket> connect({
    required Uri url,
    required String accessToken,
  }) async {
    connectionCount++;
    urls.add(url);
    final error = nextConnectError;
    nextConnectError = null;
    if (error != null) throw error;
    if (accessToken.isEmpty) throw StateError('Missing access token');
    final socket = FakeRealtimeSocket();
    sockets.add(socket);
    return socket;
  }
}

class FakeRealtimeSocket implements RealtimeSocket {
  final StreamController<Object?> _controller = StreamController.broadcast();
  final List<Object> sent = [];
  bool isClosed = false;

  @override
  Stream<Object?> get messages => _controller.stream;

  @override
  Future<void> send(Object data) async {
    if (isClosed) throw StateError('Socket is closed');
    sent.add(data);
  }

  void incoming(Object data) {
    if (!isClosed) _controller.add(data);
  }

  Future<void> unexpectedClose([Object? error]) async {
    if (isClosed) return;
    isClosed = true;
    if (error != null) _controller.addError(error);
    await _controller.close();
  }

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    await _controller.close();
  }
}
