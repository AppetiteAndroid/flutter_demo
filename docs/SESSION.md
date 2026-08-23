# Session

`UserSession` is a GetIt lazy singleton and is normally constructor-injected.
Its private seeded `BehaviorSubject` exposes only a read-only, replaying stream
and synchronous snapshots. Authentication and subscription status remain
separate. Premium access is derived only for trial, active, and grace period.

Tokens are stored only through `TokenStorage` (FlutterSecureStorage in the app).
The preferences snapshot contains only user identity and raw subscription
metadata. Initialization remains explicit until storage is restored; logout or
terminal refresh failure clears both stores and emits guest. Owners call
`dispose()` during dependency teardown.

v0.3 adds a monotonically increasing in-memory `tokenRevision`. Successful Dio
refresh notifies the session so realtime can reconnect with the new access
token without exposing it. A terminal sync/realtime refresh failure still uses
the existing `invalidate()` path.

`UserDataBoundaryCoordinator` enforces the template's single-account cache
policy. Logout or a direct user switch immediately changes repository streams
to the new owner/guest, asynchronously deletes the old owner's demo tasks (the
foreign-key cascade removes outbox rows), resets analytics/crash identity, and
clears unsafe protected route intents. Theme, locale, and other non-user
settings remain untouched. Realtime and sync observe the same session transition
and stop old-owner work.
