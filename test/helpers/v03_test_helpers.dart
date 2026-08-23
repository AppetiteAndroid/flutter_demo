import 'package:flutter_starter/core/logger/app_logger.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_starter/features/offline_tasks/data/drift_offline_task_repository.dart';

class TestAppLogger implements AppLogger {
  final List<String> messages = [];

  @override
  void debug(String message) => messages.add(message);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      messages.add(message);

  @override
  void info(String message) => messages.add(message);

  @override
  void warning(String message) => messages.add(message);
}

class SequenceIdGenerator implements IdGenerator {
  SequenceIdGenerator(Iterable<String> values) : _values = values.iterator;

  final Iterator<String> _values;

  @override
  String next() {
    if (!_values.moveNext()) throw StateError('No test IDs remain');
    return _values.current;
  }
}

Future<UserSession> authenticatedSession([String owner = 'owner-a']) async {
  final session = UserSession(
    tokenStorage: MemoryTokenStorage(),
    snapshotStorage: MemoryKeyValueStorage(),
  );
  await session.initialize();
  await session.setAuthenticated(
    user: User(id: owner, email: '$owner@example.invalid'),
    tokens: const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
  );
  return session;
}

Future<void> flushEvents([int turns = 4]) async {
  for (var index = 0; index < turns; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}
