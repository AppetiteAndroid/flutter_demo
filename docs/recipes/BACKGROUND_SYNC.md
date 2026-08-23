# Shared background sync

`BackgroundSyncHandler` is plugin-independent. It validates task type/input,
clamps work to 1–50 operations, computes a deadline, and maps bounded engine
outcomes to success/retry/failure. SQLite leases prevent foreground and
background invocations from owning the same mutation.

A background entry point initializes only configuration, logger, tokens,
session, database, and sync dependencies, calls
`handle(taskType: 'offline_sync', ...)`, then closes them. It must not construct
UI, navigation, notifications, or plugins unavailable in that isolate. Logs use
safe task/outcome codes only.

No background plugin is installed in the base graph. Connect this handler to
WorkManager/BGTaskScheduler only after the platform recipes. Background work is
an optimization; foreground/startup sync remains the correctness path.
