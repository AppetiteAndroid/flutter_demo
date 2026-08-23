# Database migrations

`AppDatabase.schemaVersion` is explicit. Fresh installs create version 2. The
supported released path in v0.3 is v1 → v2:

1. add non-null `demo_tasks.server_version` with default `0`;
2. add nullable `outbox_operations.blocked_reason`;
3. create `sync_metadata`;
4. create owner/eligibility indexes idempotently.

Valid tasks/outbox relationships are preserved. `MigrationReporter` records
only schema numbers and the exception through `AppLogger`/`CrashReporter`; it
never logs rows or payloads.

The test fixture builds an actual v1 SQLite schema and rows, sets
`PRAGMA user_version = 1`, opens current code, then verifies data, relationships,
defaults, indexes, and new tables:

```bash
flutter test test/v03_database_repository_test.dart
```

For every future released version, retain a sequential upgrade branch and add a
fixture from it. Never use a destructive fallback in production.
