# Notifications

`FlutterLocalNotificationService` explicitly initializes stable channel
`starter_general`, but never requests permission during bootstrap. Call
`requestPermission` only after user action. Android 13+ and iOS alert/badge/sound
requests are supported. Scheduling is timezone-aware and deliberately uses
inexact delivery, so no exact-alarm permission is requested. Taps and launch
payloads are parsed by `AppLinkParser`; unsupported payloads are discarded.
The app remains functional after denial. Tests use `MemoryLocalNotificationService`.
