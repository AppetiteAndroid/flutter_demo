# Feature v0.3 — Local Data, Offline-First, and Realtime

## 1. Goal

Add a production-oriented reference for reactive local persistence, offline-first synchronization, connectivity-aware UX, and authenticated realtime communication while preserving the clean boundaries established in v0.1 and v0.2.

v0.3 must remain demonstrable without a real backend. Use deterministic fake remote services to prove synchronization and WebSocket behavior; provide clear replacement boundaries for application backends.

## 2. Prerequisites and scope

Prerequisites:

- every v0.1 acceptance criterion remains satisfied;
- every v0.2 acceptance criterion remains satisfied;
- Android/iOS flavors, session, networking, observability interfaces, typed route intents, and CI are working.

Active scope:

- local relational persistence;
- migrations and user-data partitioning;
- reactive local repositories;
- offline-first read/write flow;
- durable outbox and sync engine;
- connectivity/reachability model;
- authenticated WebSocket lifecycle;
- application lifecycle integration;
- background-task integration contracts and platform recipes;
- tests, docs, and examples.

Out of scope:

- a production sync API contract;
- collaborative real-time conflict-free data structures;
- end-to-end encryption;
- store deployment;
- business-specific media upload/download;
- guaranteed background execution on iOS;
- bundling server infrastructure.

## 3. Deliverable overview

v0.3 includes:

- a Drift/SQLite reference database or an equally capable, justified reactive relational solution;
- explicit schema versions and tested migrations;
- a local-first example feature whose UI watches database streams;
- a durable outbox for pending mutations;
- an idempotency-aware `SyncEngine` with state, backoff, retries, and manual recovery;
- connectivity and backend-reachability signals that do not confuse network type with Internet access;
- a typed WebSocket client with authentication, reconnect, heartbeat, app lifecycle, parsing, and disposal;
- development tooling to simulate offline, failures, conflicts, and reconnects;
- background task handler contracts plus Android/iOS recipes and limitations;
- integration tests using fakes/local resources only;
- complete operational documentation.

## 4. Local database

### 4.1 Technology and placement

Use Drift with SQLite unless the existing repository already adopted an equivalent reactive relational database and documents why it is better for the template.

Place infrastructure under a clear boundary such as:

```text
lib/core/database/
├── app_database.dart
├── migrations/
├── tables/
├── converters/
└── database_factory.dart
```

Feature DAOs/repositories may live inside their feature when not shared globally.

Requirements:

- one database instance per application process through DI;
- platform-safe database location;
- explicit schema version;
- migration strategy from every released schema version supported by this milestone;
- database open/close lifecycle;
- no direct Drift/SQLite types in BLoCs or domain entities;
- transactions for multi-step writes;
- indexes for demonstrated query paths;
- foreign keys/cascades configured intentionally;
- timestamps stored consistently in UTC;
- enum/value conversion handles unknown future values safely where practical;
- no sensitive token storage in SQLite.

### 4.2 Schema

Implement an offline-first example entity, for example `DemoTask`, with at least:

- stable client-generated ID;
- optional remote/server ID;
- owner user ID;
- title/body field;
- completion/status field;
- local created/updated timestamps;
- optional server updated/version marker;
- sync status;
- soft-delete/tombstone support where required for deletion sync.

Add an outbox table with:

- stable operation ID;
- owner user ID;
- entity type and entity ID;
- operation kind;
- serialized validated payload or operation data;
- idempotency key;
- attempt count;
- creation time;
- next eligible attempt time;
- last safe error code/message;
- processing/lease metadata that can recover after interruption.

Do not store arbitrary secrets or unbounded raw server responses.

### 4.3 Migrations

Provide:

- migration helper structure;
- at least one real fixture migration test from an older schema to the current schema;
- preservation of valid user data;
- default/backfill policy for new non-null columns;
- index/constraint verification;
- a development-only destructive reset path that cannot execute in production accidentally;
- migration failure reporting through `AppLogger`/`CrashReporter` without logging sensitive rows.

Acceptance criteria:

- a pre-migration fixture opens successfully on the current version;
- expected rows and relationships remain correct;
- fresh install creates the latest schema directly;
- logout/user switch cannot expose another user's rows.

## 5. Reactive local repository

Create a reference repository whose UI reads local data as the source of truth.

Required API shape should support:

- watch all/current-user entities;
- watch one entity;
- create/update/delete commands;
- manual refresh/sync request;
- current sync summary stream;
- typed `Result` for immediate command acceptance/failure.

Flow:

```text
UI command
  -> Repository transaction
  -> Local entity change + outbox operation
  -> Database watch stream updates UI immediately
  -> SyncEngine sends operation later
  -> Server result reconciles local database
  -> Database watch stream updates UI again
```

Requirements:

- repositories expose domain models/read-only streams;
- no `Subject` is needed when Drift already supplies the observation stream;
- local write and outbox enqueue occur atomically;
- rapid edits coalesce only under documented safe rules;
- a delete remains visible as removed locally while its tombstone/outbox data remains syncable;
- errors are typed and do not terminate long-lived watch streams unnecessarily;
- streams are scoped to the authenticated owner.

## 6. Offline-first synchronization

### 6.1 Sync engine

Implement a testable `SyncEngine` registered with an appropriate DI lifetime.

Expose a replaying read-only state stream with states such as:

- idle;
- scheduled/waiting;
- syncing;
- offline;
- authentication required;
- blocked by permanent item error;
- completed with summary;
- stopped/disposed.

The engine must:

- serialize sync cycles;
- avoid duplicate simultaneous processing;
- select only eligible outbox items;
- use stable idempotency keys for write retries;
- mark an operation complete only after a confirmed safe response;
- recover operations left in processing state after interruption/lease expiry;
- stop or pause when the session becomes guest;
- partition work by current user;
- trigger on explicit refresh, eligible connectivity restoration, app foreground, and new outbox work;
- apply bounded exponential backoff with jitter for transient failures;
- respect server `Retry-After` when available;
- stop retrying permanent validation/authorization/conflict failures until policy/user action resolves them;
- never retry a non-idempotent remote mutation without an idempotency contract;
- be cancellable/disposable.

### 6.2 Remote boundary

Define a backend-neutral `SyncRemoteDataSource`/gateway with typed request and response models.

Provide a deterministic fake implementation that can simulate:

- success;
- latency;
- offline/timeout;
- unauthorized;
- validation failure;
- conflict;
- rate limit/retry-after;
- duplicate idempotency key;
- partial batch result if batching is supported.

Do not invent a production endpoint and imply it is universal. Document how an application maps its actual API contract.

### 6.3 Conflict policy

The example must implement one explicit, understandable conflict policy, such as server-version comparison with a visible conflict result. It must not silently claim that last-write-wins solves every domain.

Provide extension points for:

- server wins;
- client wins when server permits;
- manual user resolution;
- field-level/application-specific merge.

Persist enough metadata to prevent the same unresolved conflict from retrying forever.

### 6.4 Sync UI

Add reusable/illustrative UI for:

- offline indicator;
- syncing indicator;
- pending change count;
- last successful sync time;
- item-level permanent failure;
- manual retry;
- conflict resolution entry point;
- non-blocking behavior while local data remains available.

All labels are localized and use semantic tokens.

## 7. Connectivity and reachability

Create a `ConnectivityService` abstraction and fake.

Model at least:

- network interface unavailable;
- network interface available but backend reachability unknown;
- backend reachable;
- backend unreachable;
- rate-limited/maintenance state only if supported by the reachability response.

Requirements:

- do not equate Wi-Fi/mobile connection type with working Internet;
- network-interface signals may trigger a debounced reachability check;
- reachability uses a configurable lightweight backend endpoint or injected probe;
- checks have timeout/cancellation;
- rapid platform changes are debounced/distinct;
- app foreground may refresh stale reachability;
- long-lived stream replays the latest state;
- `SyncEngine` treats reachability as a hint and still handles real request failures;
- development controls can simulate states without changing device networking.

Tests use a fake clock/scheduler or short injected durations, not long real waits.

## 8. WebSocket/realtime

### 8.1 Architecture

Provide layers such as:

```text
WebSocketTransport
    -> RealtimeClient
    -> typed message parser/router
    -> feature repository/BLoC
```

Use a current compatible transport package or `dart:io` abstraction where platform support is appropriate. Keep the transport replaceable for tests.

### 8.2 Connection states

Expose a replaying read-only state stream with:

- disconnected;
- connecting;
- connected;
- reconnecting with attempt/next delay;
- paused/background;
- authentication required;
- failed/permanently stopped;
- disposed.

### 8.3 Lifecycle behavior

The realtime client must:

- connect only when requested/configured and session is authenticated;
- build the URL from typed app configuration;
- authenticate without placing secrets in logs;
- react to token refresh/session logout;
- refresh/reconnect once for authentication expiry without loops;
- reconnect unexpected disconnects with bounded exponential backoff and jitter;
- reset backoff after a stable successful connection;
- not reconnect after explicit manual disconnect/dispose;
- pause or follow documented platform policy in background;
- resume in foreground when appropriate;
- respond to connectivity hints;
- use heartbeat/ping-pong or an application heartbeat when the protocol requires it;
- detect stale connections;
- cancel timers/subscriptions/sockets on disposal.

### 8.4 Messages

Requirements:

- parse an envelope with version/type/id/timestamp/payload;
- validate type and payload before exposing domain messages;
- unknown message types are logged safely and ignored or exposed as a typed unknown event;
- malformed messages do not terminate the entire stream;
- duplicate message IDs can be suppressed with a bounded cache when protocol semantics require it;
- ordering assumptions are documented;
- no unbounded `ReplaySubject`/message history;
- outgoing commands return a typed immediate result and support request correlation only if implemented completely.

### 8.5 Testing

Use a fake transport to test:

- connect/authenticate;
- unexpected close and backoff reconnect;
- manual disconnect does not reconnect;
- logout stops the client;
- token update reconnect/auth behavior;
- background/foreground policy;
- heartbeat timeout;
- malformed/unknown/duplicate messages;
- deterministic disposal with no pending timers.

No test requires an external WebSocket server.

## 9. Application lifecycle coordinator

Centralize app foreground/background events behind an interface rather than letting every repository implement its own `WidgetsBindingObserver`.

Consumers may include:

- `SyncEngine`;
- `RealtimeClient`;
- reachability refresh;
- notification/deep-link coordinators when needed.

Requirements:

- one platform observer fan-outs a read-only typed stream;
- latest lifecycle state is available synchronously/replayed;
- duplicate/noisy transitions are normalized;
- observer and stream are disposed correctly in tests/application teardown;
- background does not imply the process will continue running.

## 10. Background task integration

### 10.1 Shared task handler

Create a platform-independent task handler/coordinator that can execute a bounded sync attempt when invoked by foreground code or a native background plugin.

It must:

- initialize the minimal required dependencies in a background isolate/entry point when applicable;
- identify task type and input safely;
- enforce a time/work budget;
- avoid concurrent foreground/background sync through database leases or another cross-isolate-safe mechanism;
- return success/retry/failure according to platform plugin semantics;
- never assume background work is guaranteed;
- avoid UI/plugin access that is unavailable in the background context;
- redact logs.

### 10.2 Recipes

Create:

- `docs/recipes/BACKGROUND_TASKS_ANDROID.md` for WorkManager-style periodic/one-off work, constraints, reboot behavior, and debugging;
- `docs/recipes/BACKGROUND_TASKS_IOS.md` for BGTaskScheduler/background fetch limitations, identifiers, scheduling, expiration handlers, and testing;
- `docs/recipes/BACKGROUND_SYNC.md` describing DI/bootstrap and how to connect the shared handler.

Installing a background plugin in the base project is optional. If installed, it must be fully configured and tested. Otherwise the shared handler and recipes must compile without the plugin and clearly mark integration steps.

Do not claim exact scheduling or guaranteed execution on either platform.

## 11. Session and user-data boundaries

On logout or user switch:

- stop realtime connection;
- stop/pause sync for the old user;
- clear tokens through the existing secure path;
- prevent old-user streams from appearing in the new session;
- either securely delete old-user local rows or retain them only under an explicit documented multi-account cache policy;
- clear analytics/crash identity per v0.2;
- clear pending protected route intents where unsafe;
- preserve non-user settings such as theme/locale.

The default template policy should remove demo user data on logout unless a documented product policy says otherwise.

Tests must attempt rapid logout/login as another user and prove no cross-user data leakage.

## 12. Developer simulation tools

In development builds only, add controls for:

- online/offline/backend-unreachable;
- remote latency;
- next sync success/failure/conflict/rate-limit;
- pending outbox inspection without sensitive payloads;
- trigger sync;
- WebSocket connect/disconnect/unexpected close;
- fake incoming typed message;
- app lifecycle simulation where practical;
- local database reset with confirmation.

These controls must be excluded or inert in production and must call public abstractions rather than mutate private subjects/database tables directly.

## 13. Documentation

Create/update:

- `README.md`;
- `docs/ARCHITECTURE.md`;
- `docs/DATABASE.md`;
- `docs/MIGRATIONS.md`;
- `docs/OFFLINE_FIRST.md`;
- `docs/SYNC_ENGINE.md`;
- `docs/CONNECTIVITY.md`;
- `docs/REALTIME.md`;
- `docs/SESSION.md`;
- background task recipes.

Documentation must include:

- sequence diagrams or compact Mermaid diagrams where they clarify sync/reconnect;
- ownership/lifecycle of long-lived services;
- application-specific replacement points;
- failure/recovery behavior;
- data privacy and logout policy;
- exact local test/simulation commands;
- platform limitations without overpromising.

## 14. CI and generated code

If Drift/code generation is used:

- generation commands are documented;
- generated files follow one consistent repository policy;
- CI verifies generated output is up to date;
- migrations are tested before platform builds;
- analyzer excludes are not broadened to hide generation problems.

Add CI coverage for:

- unit/widget tests;
- database migration fixtures;
- sync/realtime deterministic tests;
- code generation drift;
- existing Android/iOS build jobs.

Do not run flaky timing-based tests with long real delays.

## 15. Required tests

At minimum add:

1. Fresh database creation and close/reopen.
2. Migration fixture to current schema with data preservation.
3. Owner/user query isolation and logout cleanup.
4. Reactive repository emits after local create/update/delete.
5. Entity change and outbox insert are atomic.
6. Sync success reconciliation and outbox removal.
7. Transient failure backoff/retry using injected time.
8. Permanent validation failure blocks only the affected operation according to policy.
9. Unauthorized state pauses sync and integrates with session refresh/invalidation safely.
10. Idempotency/duplicate response handling.
11. Conflict detection and selected resolution path.
12. Processing lease recovery after simulated interruption.
13. Connectivity distinction between interface and backend reachability.
14. Connectivity restoration triggers at most one eligible sync cycle.
15. WebSocket connection state/reconnect/backoff/heartbeat.
16. Manual disconnect/dispose never reconnects.
17. Token refresh, logout, and user switch realtime behavior.
18. Malformed/unknown/duplicate message handling.
19. Lifecycle foreground/background integration.
20. Shared background handler bounded success/retry/failure behavior.
21. Offline/sync status widgets in Light/Dark and localized locales.
22. All v0.1 and v0.2 tests remain passing.

Tests must use temporary/in-memory databases where supported, fake transports/remotes, and injected clocks/durations. No live backend or external WebSocket service.

## 16. Verification commands

Run all previous milestone checks plus:

```bash
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run the native development builds from v0.2 and any database/platform integration tests supported by the environment.

Manually verify on at least one Android emulator/device and one iOS simulator/device when available:

- create/update/delete while online;
- create/update/delete while simulated offline;
- restart app with pending outbox and recover;
- connectivity restoration sync;
- conflict/permanent failure UI;
- realtime connect, unexpected disconnect, reconnect, background/foreground, and logout;
- no old-user data after user switch;
- production build hides simulation tools.

Report unavailable platform verification precisely.

## 17. Out of scope

- real production API endpoints;
- server implementation;
- CRDT/collaborative editing;
- encrypted database by default;
- large media/background uploads;
- guaranteed periodic background scheduling;
- in-app purchases;
- store release automation;
- web/desktop database implementations.

## 18. Final acceptance checklist

- [ ] All v0.1 and v0.2 tests and behaviors remain working.
- [ ] Database has explicit schema/migrations and a passing migration fixture.
- [ ] Local repository streams are the example UI source of truth.
- [ ] Local mutation and outbox enqueue are atomic.
- [ ] Sync is serialized, idempotency-aware, recoverable, and safely retried.
- [ ] Permanent failures/conflicts stop infinite retry and are visible to the user.
- [ ] Connectivity does not confuse network type with backend reachability.
- [ ] Realtime has typed states/messages, auth, reconnect, heartbeat, lifecycle, and disposal.
- [ ] Logout/user switch cannot leak old-user data or realtime events.
- [ ] Background handler is bounded and recipes state platform limitations honestly.
- [ ] Development simulation tools are absent/inert in production.
- [ ] No live backend is required for tests or demo behavior.
- [ ] Documentation matches implemented ownership, flow, and commands.
- [ ] Code generation, format, analyze, tests, and available native builds pass.
