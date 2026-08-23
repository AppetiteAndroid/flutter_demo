# Networking

`ApiClient` wraps Dio and returns `Result<T>`. It supports the common HTTP
verbs, parsing callbacks, query/headers/body, `FormData`, cancellation,
progress, downloads, and per-request auth opt-out. `mapDioFailure` converts Dio
and status failures into typed application failures.

`AuthInterceptor` reads secure tokens and retries a 401 request once. All
concurrent callers share `SingleFlightTokenRefresher`; refresh uses a separate
Dio instance marked to skip auth/refresh, so it cannot recurse. Terminal refresh
failure clears credentials and invalidates `UserSession`. There is no general
retry policy, especially for non-idempotent writes.

Development request logs pass headers and bodies through `redactSensitive`.
Authorization, cookies, token/password/API-key/secret fields are removed.
Production configuration forcibly disables verbose networking logs.
