# Firebase Crashlytics recipe

After core setup, add `firebase_crashlytics`, its documented Android Gradle and
iOS upload-symbol integration, and a `CrashReporter` adapter. Replace the DI
registration and forward the existing global hooks exactly once. Never attach
PII; preserve sanitization and consent policy. Verify a non-fatal debug event,
mock the adapter in tests, and remove plugin/build scripts/service files to
roll back.
