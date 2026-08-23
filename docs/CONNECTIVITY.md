# Connectivity and reachability

`ConnectivityService` separates interface availability from backend
reachability: interface unavailable, interface available/unknown, backend
reachable, backend unreachable, and rate-limited.

Staging/production use `connectivity_plus` only as an interface hint, debounce
noise, and probe `AppConfig.reachabilityUrl` through unauthenticated Dio with a
timeout. Wi-Fi/mobile never implies Internet access. Sync and realtime still
handle real request failures because the probe is only a hint. Foreground
refreshes reachability.

Development injects `FakeConnectivityService`, so controls simulate states
without changing device networking or calling a backend. Configure
`REACHABILITY_PATH` (default `/health`) to an inexpensive real endpoint.

```bash
flutter test test/v03_connectivity_lifecycle_background_test.dart
```
