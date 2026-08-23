# Security architecture

## Defaults

- Checked-in configs use reserved `.invalid` endpoints and contain no secrets.
- Tokens are stored only through `TokenStorage` backed by secure storage; cached
  session snapshots never contain tokens.
- Dio logs are development-only and recursively redact authorization, cookies,
  password/token/API-key/secret fields. Production logging drops debug/info and
  does not forward arbitrary error objects or stack traces.
- Analytics/crash context rejects sensitive/PII-like keys. Logout and user
  switch reset telemetry identity and clear the previous owner's local rows.
- Outbox payloads and realtime auth/message bodies are not logged.
- Link and notification payloads are untrusted and pass a typed parser/allowlist.
  Feature flags and cached entitlement never authorize protected behavior.

Run `dart run tool/scan_secrets.dart` on every PR. Repository hosting should
also enable GitHub secret scanning and push protection.

## Application-owner responsibilities

- Configure Android backup rules and iOS Data Protection for product data;
  Drift is not encrypted by default.
- Replace placeholder domains/endpoints without committing credentials.
- Configure TLS/API authorization and server-side entitlement validation.
- Establish retention/deletion, consent, telemetry and vulnerability policies.
- Review dependencies and platform advisories during SDK upgrades.
