import 'package:drift/drift.dart';

import 'database_factory.dart';
import 'migrations/migration_reporter.dart';

part 'app_database.g.dart';

class DemoTasks extends Table {
  TextColumn get clientId => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get ownerUserId => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {clientId};
}

class OutboxOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get entityType =>
      text().withDefault(const Constant('demo_task'))();
  TextColumn get entityId =>
      text().references(DemoTasks, #clientId, onDelete: KeyAction.cascade)();
  TextColumn get operationKind => text()();
  TextColumn get payload => text().withLength(min: 2, max: 4096)();
  TextColumn get idempotencyKey => text().unique()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextEligibleAt => dateTime().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  DateTimeColumn get processingStartedAt => dateTime().nullable()();
  DateTimeColumn get leaseExpiresAt => dateTime().nullable()();
  TextColumn get blockedReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

class SyncMetadata extends Table {
  TextColumn get ownerUserId => text()();
  DateTimeColumn get lastSuccessfulSyncAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerUserId};
}

@DriftDatabase(tables: [DemoTasks, OutboxOperations, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase({MigrationReporter? migrationReporter})
    : this.forTesting(
        openApplicationDatabase(),
        migrationReporter: migrationReporter,
      );

  AppDatabase.forTesting(super.executor, {this._migrationReporter});

  final MigrationReporter? _migrationReporter;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      try {
        if (from == 1 && to >= 2) {
          await migrator.addColumn(demoTasks, demoTasks.serverVersion);
          await migrator.addColumn(
            outboxOperations,
            outboxOperations.blockedReason,
          );
          await migrator.createTable(syncMetadata);
          await _createIndexes();
        }
      } catch (error, stackTrace) {
        final reporter = _migrationReporter;
        if (reporter != null) {
          reporter.report(error, stackTrace, from, to);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS demo_tasks_owner_visible '
      'ON demo_tasks (owner_user_id, is_deleted, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS outbox_owner_eligible '
      'ON outbox_operations '
      '(owner_user_id, blocked_reason, next_eligible_at, created_at)',
    );
  }

  Future<void> developmentReset({required bool allowDestructiveReset}) async {
    if (!allowDestructiveReset) {
      throw StateError('Destructive database reset is disabled');
    }
    await transaction(() async {
      await delete(outboxOperations).go();
      await delete(demoTasks).go();
      await delete(syncMetadata).go();
    });
  }
}
