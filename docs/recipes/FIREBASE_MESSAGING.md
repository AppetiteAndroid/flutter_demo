# Firebase Messaging recipe

After core setup, add `firebase_messaging` and implement `PushMessagingService`.
Android uses each flavor's `android/app/src/<flavor>/google-services.json`; iOS
uses per-scheme plist mapping plus APNs capabilities. Never commit server/APNs
keys. Register the adapter in DI, forward foreground messages to the local
notification service, and parse opens into `AppRouteIntent`.

The background handler must be a top-level `@pragma('vm:entry-point')` function,
initialize only required services, and avoid UI/navigation. Request permission
after explicit explanation, document privacy/token retention, test using fake
streams, and manually cover foreground/background/terminated opens. Roll back
by restoring `NoopPushMessagingService` and removing packages/native files.
