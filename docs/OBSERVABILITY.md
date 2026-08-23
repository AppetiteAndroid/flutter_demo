# Observability and flags

Analytics and crash interfaces default to development logging or production
no-op implementations. Consent gates analytics. Central sanitization removes
email, phone, message/body, tokens, passwords and authorization data. Crash
events are de-duplicated and may use only an anonymous policy-approved ID.
Logout integrations must call both identity reset methods.

`FeatureFlagService` exposes typed `FeatureFlag` keys, a replaying snapshot,
safe compiled defaults and development-only overrides. Flags never authorize
protected operations.
