# Public API and extension policy

v1.0 treats the following as stable template extension points. “Stable” means
minor releases avoid gratuitous renames; this is source template code, not a
published Dart package with binary compatibility guarantees.

| Area | Stable extension points | Ownership/lifetime |
|---|---|---|
| Configuration | `AppConfig`, `AppEnvironment` | immutable, composed at bootstrap |
| Results | `Result<T>`, typed `AppFailure` subclasses | immutable operation values |
| Session | `UserSession`, state/user/subscription models | process singleton; replay stream; explicit `dispose` |
| Networking | `ApiClient`, `TokenStorage`, `TokenRefreshService` | injected infrastructure; cancellation remains per request |
| Design | `AppColors`, tokens, `AppTheme`, documented components | immutable themes/widgets |
| Navigation | `AppRouteIntent`, parser, link/notification service interfaces | external input validated before routing |
| Observability | `AppLogger`, `AnalyticsService`, `CrashReporter` | replaceable adapters; restricted production defaults |
| Local data | `AppDatabase`, `OfflineTaskRepository` | one opened database; domain streams |
| Sync | `SyncStore`, `SyncRemoteDataSource`, `SyncEngine` | serialized singleton; idempotent operations |
| Connectivity/lifecycle | service interfaces and typed states | replaying services; explicit start/dispose |
| Realtime | transports, typed messages/parser/client | authenticated singleton; explicit disconnect/dispose |
| Notifications/push | local and push service interfaces | optional platform adapter/no-op push |
| Pagination | page request/result/repository and generic BLoC | route/widget-owned BLoC |

Concrete plugin adapters, fake development implementations, Drift-generated
types, BLoC events/states and DI composition are internal. No `Subject` or
mutable collection is exposed. UI/business code uses constructor injection;
GetIt access is limited to bootstrap/router composition.

Sync retries only eligible idempotent outbox operations; realtime manual
disconnect never reconnects; link/notification streams discard malformed
input; long-lived owners close subscriptions, subjects, timers, sockets and
database handles.
