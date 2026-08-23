# Native flavors

Android defines the `environment` dimension with development (`.dev`), staging
(`.staging`) and production (base ID). iOS has shared schemes with the same
names and checked-in flavor xcconfig values. Each config supplies display name,
bundle ID, custom URL scheme, and placeholder App Link host. `NATIVE_FLAVOR` in
the checked-in Dart config is validated against `ENVIRONMENT` during bootstrap.

Use the canonical `make run-dev`, `make run-staging`, and `make run-prod`
commands. No signing team or credentials are committed. Non-production icons
use different backgrounds; replace/validate assets as described in
`assets/branding/README.md`.
