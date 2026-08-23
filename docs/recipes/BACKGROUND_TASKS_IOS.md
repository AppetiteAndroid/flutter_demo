# iOS background tasks recipe

Choose BGAppRefresh/BGProcessing or background fetch for the actual work. Add
permitted identifiers to `Info.plist`, register handlers before launch
completes, enable only required Background Modes, and schedule future requests
from foreground code. Identifiers and entitlements must match the chosen
plugin/native bridge.

Set an expiration callback that stops additional work, call
`BackgroundSyncHandler` with a conservative deadline, and report completion
exactly once. Initialize only background-safe dependencies and rely on SQLite
leases if foreground code may overlap.

Use Xcode's documented BGTask simulation/debug flow and a physical device where
possible. The OS decides whether and when tasks run. Force-quit, Low Power Mode,
quotas, usage, power, and network policy can prevent execution. iOS background
execution is not guaranteed and cannot be the sole correctness path.
