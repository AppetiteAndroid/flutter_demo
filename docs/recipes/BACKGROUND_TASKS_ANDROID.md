# Android background tasks recipe

If required, add a maintained WorkManager-compatible Flutter plugin and follow
its current manifest/startup setup. Use a unique one-off job after local writes
and optional periodic work with network/battery constraints. Re-register
periodic work idempotently after upgrades and verify reboot behavior for the
selected plugin.

The callback initializes the minimal dependencies from `BACKGROUND_SYNC.md`,
invokes `BackgroundSyncHandler`, maps success/retry/failure to plugin semantics,
and stops at an explicit time/work budget. SQLite leases reject concurrent
ownership; do not loop inside one worker.

Debug using `adb shell dumpsys jobscheduler`, documented plugin test hooks, and
safe filtered logs. Doze, quotas, battery optimization, OEM policies, and
constraints may delay or skip work. Periodic intervals are inexact; execution
is never guaranteed.
