import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_starter/core/database/app_database.dart';
import 'package:flutter_starter/core/result/result.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_starter/features/offline_tasks/data/drift_offline_task_repository.dart';
import 'package:flutter_starter/features/offline_tasks/domain/offline_task.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/v03_test_helpers.dart';

void main() {
  test(
    'fresh database creates latest schema and survives close/reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('starter-db-');
      final file = File('${directory.path}/starter.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        await database.customSelect('PRAGMA user_version').getSingle(),
        isNotNull,
      );
      await database
          .into(database.demoTasks)
          .insert(
            DemoTasksCompanion.insert(
              clientId: 'task-1',
              ownerUserId: 'owner-a',
              title: 'Persisted',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll(['demo_tasks_owner_visible', 'outbox_owner_eligible']),
      );
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await database.select(database.demoTasks).getSingle()).title,
        'Persisted',
      );
      expect(database.schemaVersion, 2);
      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test('destructive reset requires an explicit development guard', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await expectLater(
      database.developmentReset(allowDestructiveReset: false),
      throwsStateError,
    );
    await database.developmentReset(allowDestructiveReset: true);
    await database.close();
  });

  test(
    'v1 fixture migrates to v2 and preserves data and relationships',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE demo_tasks (
  client_id TEXT NOT NULL PRIMARY KEY,
  remote_id TEXT,
  owner_user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  server_updated_at INTEGER,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  is_deleted INTEGER NOT NULL DEFAULT 0
)
''');
          raw.execute('''
CREATE TABLE outbox_operations (
  operation_id TEXT NOT NULL PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  entity_type TEXT NOT NULL DEFAULT 'demo_task',
  entity_id TEXT NOT NULL REFERENCES demo_tasks(client_id) ON DELETE CASCADE,
  operation_kind TEXT NOT NULL,
  payload TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  next_eligible_at INTEGER,
  last_error_code TEXT,
  last_error_message TEXT,
  processing_started_at INTEGER,
  lease_expires_at INTEGER
)
''');
          raw.execute(
            "INSERT INTO demo_tasks VALUES "
            "('task-old', NULL, 'owner-a', 'Migrated', 0, 1767225600, "
            "1767225600, NULL, 'pending', 0)",
          );
          raw.execute(
            "INSERT INTO outbox_operations VALUES "
            "('op-old', 'owner-a', 'demo_task', 'task-old', 'create', "
            "'{\"id\":\"task-old\",\"title\":\"Migrated\",\"completed\":false,"
            "\"deleted\":false,\"serverVersion\":0}', 'idem-old', 0, "
            "1767225600, NULL, NULL, NULL, NULL, NULL)",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      );
      final database = AppDatabase.forTesting(executor);
      final task = await database.select(database.demoTasks).getSingle();
      final operation = await database
          .select(database.outboxOperations)
          .getSingle();
      expect(task.title, 'Migrated');
      expect(task.serverVersion, 0);
      expect(operation.entityId, task.clientId);
      expect(operation.blockedReason, isNull);
      expect(await database.select(database.syncMetadata).get(), isEmpty);
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);
      await database.close();
    },
  );

  test(
    'repository reacts to atomic create, update and tombstone delete',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final session = await authenticatedSession();
      final repository = DriftOfflineTaskRepository(
        database: database,
        session: session,
        idGenerator: SequenceIdGenerator([
          'task-1',
          'op-create',
          'op-update',
          'op-delete',
        ]),
        now: () => DateTime.utc(2026),
      );
      final emissions = <List<OfflineTask>>[];
      final subscription = repository.watchAll().listen(
        (tasks) => emissions.add(tasks),
      );
      expect(await repository.create('Local first'), isA<Success<Object?>>());
      await flushEvents();
      expect(emissions.last, hasLength(1));
      expect(
        await database.select(database.outboxOperations).get(),
        hasLength(1),
      );

      expect(
        await repository.update('task-1', isCompleted: true),
        isA<Success<Object?>>(),
      );
      await flushEvents();
      expect(emissions.last.single.isCompleted, isTrue);
      // The unsent create safely absorbs the edit without changing its idempotency key.
      expect(
        await database.select(database.outboxOperations).get(),
        hasLength(1),
      );

      expect(await repository.delete('task-1'), isA<Success<Object?>>());
      await flushEvents();
      expect(emissions.last, isEmpty);
      final rows = await database.select(database.demoTasks).get();
      expect(rows.single.isDeleted, isTrue);
      expect(
        await database.select(database.outboxOperations).get(),
        hasLength(2),
      );
      await subscription.cancel();
      await session.dispose();
      await database.close();
    },
  );

  test(
    'task and outbox insert roll back together on outbox conflict',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final session = await authenticatedSession();
      final repository = DriftOfflineTaskRepository(
        database: database,
        session: session,
        idGenerator: SequenceIdGenerator([
          'task-1',
          'same-op',
          'task-2',
          'same-op',
        ]),
      );
      expect(await repository.create('First'), isA<Success<Object?>>());
      expect(await repository.create('Second'), isA<Failure<Object?>>());
      expect(await database.select(database.demoTasks).get(), hasLength(1));
      expect(
        await database.select(database.outboxOperations).get(),
        hasLength(1),
      );
      await session.dispose();
      await database.close();
    },
  );

  test(
    'owner streams isolate users and logout policy clears old rows',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final session = await authenticatedSession('owner-a');
      final repository = DriftOfflineTaskRepository(
        database: database,
        session: session,
        idGenerator: SequenceIdGenerator(['task-a', 'op-a']),
      );
      await repository.create('Private A');
      await session.setAuthenticated(
        user: const User(id: 'owner-b', email: 'b@example.invalid'),
        tokens: const TokenPair(accessToken: 'b', refreshToken: 'b-refresh'),
      );
      expect(await repository.watchAll().first, isEmpty);
      await repository.clearOwnerData('owner-a');
      expect(await database.select(database.demoTasks).get(), isEmpty);
      expect(await database.select(database.outboxOperations).get(), isEmpty);
      await session.logout();
      expect(await repository.watchAll().first, isEmpty);
      await session.dispose();
      await database.close();
    },
  );
}
