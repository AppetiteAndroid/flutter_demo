# Sync engine

`SyncEngine` is a DI singleton with replaying idle, waiting, syncing, offline,
authentication-required, blocked, completed, stopped, and disposed states. It
triggers on explicit refresh, new outbox work, backend restoration, and app
foreground. Concurrent triggers serialize into at most one later pass.

Each operation atomically obtains a SQLite lease. Expired leases recover after
interruption and coordinate foreground with a future background isolate. A
confirmed success or duplicate-idempotency response removes the operation.
Transient failures persist the next eligible UTC time using bounded exponential
backoff with jitter; rate limits honor `Retry-After`. Validation/conflict blocks
only that item. Unauthorized attempts invoke the existing single-flight token
refresh once and invalidate the session on terminal failure.

`FakeSyncRemoteDataSource` simulates latency, offline, timeout, unauthorized,
validation, conflict, rate limit, duplicate, and success. It is a demonstration
boundary, not a production API. Replace it with a gateway mapping the actual
authenticated contract to `SyncRemoteResult`. Never retry mutations unless the
server honors the stable idempotency key.

```bash
flutter test test/v03_sync_engine_test.dart
```
