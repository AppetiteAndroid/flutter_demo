import 'dart:convert';

import 'realtime_models.dart';

class RealtimeMessageParser {
  const RealtimeMessageParser();

  RealtimeMessage? parse(Object? raw) {
    Object? value = raw;
    if (raw is String) {
      try {
        value = jsonDecode(raw);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map) return null;
    final version = value['version'];
    final type = value['type'];
    final id = value['id'];
    final rawTimestamp = value['timestamp'];
    final payload = value['payload'];
    final timestamp = rawTimestamp is String
        ? DateTime.tryParse(rawTimestamp)?.toUtc()
        : null;
    if (version != 1 ||
        type is! String ||
        id is! String ||
        id.isEmpty ||
        timestamp == null ||
        payload is! Map) {
      return null;
    }
    return switch (type) {
      'demo_task.changed'
          when payload['taskId'] is String && payload['serverVersion'] is int =>
        DemoTaskChangedMessage(
          version: version,
          type: type,
          id: id,
          timestamp: timestamp,
          taskId: payload['taskId'] as String,
          serverVersion: payload['serverVersion'] as int,
        ),
      'pong' => PongMessage(
        version: version,
        type: type,
        id: id,
        timestamp: timestamp,
      ),
      'auth.expired' => AuthenticationExpiredMessage(
        version: version,
        type: type,
        id: id,
        timestamp: timestamp,
      ),
      _ => UnknownRealtimeMessage(
        version: version,
        type: type,
        id: id,
        timestamp: timestamp,
      ),
    };
  }
}
