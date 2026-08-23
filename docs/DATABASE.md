# Database

The reference uses Drift 2 with SQLite. `AppDatabase` is a single DI-owned
instance opened from a platform-safe location by `drift_flutter`; tests inject
an in-memory executor or temporary file. Bootstrap forces the open so migration
failures are reported before the first screen.

Schema version 2 contains:

- `demo_tasks`: client ID, optional remote ID, owner, title/completion, UTC
  timestamps, server version/time, sync status, and tombstone;
- `outbox_operations`: stable operation/idempotency IDs, validated bounded JSON,
  attempts/eligibility, safe errors, and recoverable processing lease;
- `sync_metadata`: last successful sync per owner.

`demo_tasks_owner_visible` and `outbox_owner_eligible` index the demonstrated
paths. The outbox foreign key cascades when a task is physically removed after
confirmed deletion or owner cleanup. Foreign keys are enabled on every open.
Tokens and arbitrary server responses never enter SQLite; unknown sync enum
strings map to a safe domain `unknown` value.

Generated code policy:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Commit `app_database.g.dart`; do not edit it. CI regenerates it and fails on a
diff. Replacing Drift requires retaining reactive transactions, migrations,
owner predicates, leases, and the domain-only repository API.

The reset method requires an explicit development guard. The debug UI calls it
only after confirmation; production never constructs these controls.
