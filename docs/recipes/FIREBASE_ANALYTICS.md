# Firebase Analytics recipe

After `FIREBASE_CORE.md`, add `firebase_analytics` and implement
`AnalyticsService`; register it instead of the no-op/development adapter in DI.
Map only typed events and retain central sanitization/consent. Put per-flavor
service files in the native locations produced by FlutterFire. Verify with
DebugView, test via a fake SDK boundary, and document consent/retention. Remove
the adapter, package and native files to roll back.
