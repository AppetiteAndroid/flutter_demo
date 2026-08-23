# Feature v0.2 — Production Platform Integrations

## 1. Goal

Turn the v0.1 architectural foundation into a practical multi-environment mobile starter. v0.2 adds native Android/iOS flavors, application identity assets, deep-link and notification pipelines, observability abstractions, feature flags, reusable pagination, a feature generator, and native build verification.

The base application must still run without Firebase credentials, a real domain, a remote backend, or commercial assets.

## 2. Prerequisites and scope

Before implementation:

1. Read `AGENTS.md`.
2. Verify every `FEATURE_V0.1.md` acceptance criterion that v0.2 depends on.
3. Read this file as the active scope.
4. Use `FULL_SPEC.md` for architectural intent only.

If v0.1 analysis/tests are failing, fix regressions required for v0.2 before adding new code. Do not silently weaken v0.1 behavior.

Out of scope for v0.2:

- a production backend;
- a real database or offline synchronization;
- WebSocket lifecycle implementation;
- real store signing or publishing;
- in-app purchases;
- user media/gallery access;
- committing Firebase service files or credentials.

Those belong to later milestones or application-specific integration.

## 3. Deliverable overview

v0.2 includes:

- native development, staging, and production flavors for Android and iOS;
- flavor-aware names, IDs, icons, splash assets, and Dart configuration checks;
- a stronger rename tool that understands flavors and native configuration;
- a typed deep-link pipeline and routing integration;
- local notifications with permission-safe initialization and typed tap events;
- remote-push/Firebase integration recipes without mandatory credentials;
- analytics, crash reporting, and feature-flag interfaces with safe default implementations;
- a reusable pagination toolkit and example screen;
- expanded design-system components required by the new examples;
- a feature generator with dry-run and conflict safety;
- Android/iOS build CI and environment validation;
- tests and documentation for all new behavior.

## 4. Native flavors

### 4.1 Flavor model

Support exactly these canonical environments:

- `development`;
- `staging`;
- `production`.

The native flavor selected at build time and the Dart `AppEnvironment` selected by the entry point/configuration must agree. A mismatch must fail clearly in development/test rather than silently connecting to the wrong backend.

Canonical commands:

```bash
flutter run \
  --flavor development \
  -t lib/main_development.dart \
  --dart-define-from-file=config/development.json

flutter run \
  --flavor staging \
  -t lib/main_staging.dart \
  --dart-define-from-file=config/staging.json

flutter run \
  --flavor production \
  -t lib/main_production.dart \
  --dart-define-from-file=config/production.json
```

### 4.2 Android

Configure Gradle product flavors with a dedicated flavor dimension.

Requirements:

- development and staging have distinct installable application IDs;
- production keeps the clean base application ID;
- each flavor has a distinct display name such as `Flutter Starter Dev`, `Flutter Starter Staging`, and `Flutter Starter`;
- manifest placeholders/resources are flavor-aware;
- no secret values live in Gradle or committed properties;
- current namespace/application ID conventions remain compatible with the stable Android Gradle Plugin used by the project;
- flavor configuration works with debug and release variants;
- Android 13+ notification permission declarations are present only as required by implemented notification behavior.

Suggested identity convention:

```text
production:  com.example.flutterstarter
staging:     com.example.flutterstarter.staging
development: com.example.flutterstarter.dev
```

The rename tool must derive these from the new base bundle ID rather than hardcoding the starter identifier.

### 4.3 iOS

Create shared Xcode schemes/configurations for development, staging, and production.

Requirements:

- schemes are shared and committed;
- bundle identifiers are distinct and follow the same suffix policy as Android where practical;
- display names identify non-production builds;
- configuration values are expressed through checked-in `.xcconfig` files or an equally maintainable native mechanism;
- Release/Profile/Debug mappings are correct for each scheme;
- no signing team, certificate, provisioning profile, or private key is committed;
- `flutter build ios --simulator --flavor <flavor>` can select the intended configuration;
- URL schemes/deep-link configuration can be flavor-aware.

### 4.4 Flavor validation

Expose a small native flavor identifier to Dart through a compile-time value or other testable mechanism. During bootstrap, compare it with `AppConfig.environment` when the value is available.

Acceptance criteria:

- every flavor can be installed alongside production where the platform allows it;
- display name and package/bundle ID are correct;
- a mismatched Dart/native environment produces a clear diagnostic;
- flavor tests do not rely on real signing.

## 5. Icons and splash assets

Provide a documented, replaceable asset pipeline.

Requirements:

- starter-owned placeholder artwork only; do not copy third-party logos;
- visibly different development/staging icon treatment, such as a small DEV/STG marker or distinct background color;
- production icon has no environment marker;
- Android adaptive icon foreground/background are supported;
- iOS AppIcon sets are flavor-aware where supported by the chosen approach;
- splash screen follows the current native Android/iOS APIs and supports Light/Dark backgrounds;
- generation configuration is committed;
- generated native assets are deterministic;
- README explains how a new project replaces source artwork and regenerates assets.

If helper packages are used, add them only as development dependencies and use current compatible configuration. The app must not download assets during a normal build.

## 6. Rename tool v0.2

Extend `tool/rename_project.dart` without breaking its v0.1 CLI.

It must additionally update:

- all Android flavor application IDs and labels;
- iOS flavor bundle identifiers, schemes/config references, and display names;
- deep-link custom schemes and documented placeholder hosts;
- icon/splash configuration names;
- environment-specific starter placeholders;
- any package name references introduced after v0.1.

Add optional arguments only when they provide clear value:

```text
--deep-link-scheme
--domain
```

Defaults must be derived safely from the package/bundle ID. The tool must never claim that universal links/app links are production-ready without domain association files being hosted.

Acceptance criteria:

- `--dry-run` includes flavor files;
- a second dry run after a successful rename reports no unintended starter identifiers;
- pure transform tests cover all flavor-specific patterns;
- an integration test operates on a temporary fixture/copy, never the working repository;
- binary/generated/build directories remain excluded.

## 7. Deep links and route intents

### 7.1 Architecture

Introduce a typed pipeline:

```text
Platform URI source
    -> AppLinkService
    -> AppLinkParser
    -> AppRouteIntent
    -> Router/navigation coordinator
```

Requirements:

- handle the initial URI that launched the app;
- handle URIs received while the app is running;
- deduplicate the same initial/runtime link when platforms emit both;
- expose a read-only stream;
- parse into typed intents rather than navigating directly from platform callbacks;
- reject unknown schemes, hosts, routes, malformed IDs, and unsafe external targets;
- preserve only explicitly supported query parameters;
- delay protected navigation until `UserSession` initialization completes;
- preserve a safe pending intent through sign-in when appropriate;
- avoid navigation after service disposal.

Initial route intents should cover:

- home;
- settings;
- search with an optional query;
- authenticated sample details with a validated ID.

### 7.2 Native configuration

Support:

- a custom URL scheme that works locally without a hosted domain;
- Android App Links configuration template;
- iOS Universal Links/Associated Domains template;
- flavor-specific schemes to avoid opening the wrong installed flavor.

Domain-based links are incomplete until the owner hosts valid `assetlinks.json` and `apple-app-site-association` files. Provide exact templates and verification instructions, but do not invent signing fingerprints or Team IDs.

### 7.3 Testing

Test:

- valid URI -> typed intent;
- invalid host/scheme/path/ID rejection;
- percent encoding and query normalization;
- duplicate suppression;
- pending protected intent after authentication;
- no redirect loop.

Tests must not open a real browser or require a hosted domain.

## 8. Notifications

### 8.1 Local notification service

Implement a platform-backed `LocalNotificationService` behind an interface, plus an in-memory fake.

Required behavior:

- explicit initialization;
- create Android notification channels with stable IDs;
- request notification permission only after an explicit user/application action, not automatically on first bootstrap;
- expose current permission state where the platform permits it;
- display an immediate notification;
- schedule a timezone-aware notification;
- cancel one notification;
- cancel all template-owned notifications;
- expose typed notification response/tap events as a read-only stream;
- map payloads to the same `AppRouteIntent` model used by deep links;
- reject malformed or unsupported payloads safely;
- close streams/subscriptions on disposal.

Do not request exact-alarm permission in the base template. If exact-to-the-minute delivery needs extra platform permission, document it as an application-specific opt-in.

### 8.2 Permission behavior

- iOS authorization options are documented and requested intentionally.
- Android 13+ runtime notification permission is handled.
- denied/permanently denied states do not crash or repeatedly prompt.
- the app remains fully usable when notification permission is denied.
- permission state is not inferred from a single stale boolean.

### 8.3 Notification routing

Notification open behavior must work when the app is:

- foreground;
- background;
- terminated and launched by the tap.

Cold-start routing waits for bootstrap/session readiness. Duplicate responses do not cause duplicate pages.

### 8.4 Remote-push boundary

Define a small `PushMessagingService` abstraction and fake/no-op implementation for:

- permission delegation;
- token stream/current token;
- token refresh;
- foreground message stream;
- notification-open stream;
- background message entry-point contract.

Do not require Firebase credentials in the base project. Provide `docs/recipes/FIREBASE_MESSAGING.md` with the exact integration points, native file locations, privacy considerations, background-entry-point constraints, and testing checklist.

Acceptance criteria:

- the local notification example works without Firebase;
- taps use typed route intents;
- permission denial is handled;
- service/plugin calls are mockable;
- tests cover payload parsing, deduplication, and cold-start queuing;
- no Firebase service file, server key, APNs key, or credential is committed.

## 9. Analytics, crash reporting, and feature flags

### 9.1 Analytics

Create an `AnalyticsService` interface with no-op and development logger implementations.

Provide:

- typed/stable event names;
- screen-view tracking from the router observer/integration;
- explicit user-property API;
- reset/clear identity on logout;
- opt-in/consent state support;
- central sanitization that rejects or strips sensitive keys;
- no raw email, phone number, token, password, message body, or arbitrary server payload.

Avoid a service-locator call in every widget. Track business events from BLoCs/repositories/coordinators or a dedicated presentation callback.

### 9.2 Crash reporting

Create a `CrashReporter` interface with no-op and development logger implementations.

Support:

- fatal and non-fatal errors;
- stack traces;
- safe key/value context with redaction;
- anonymous session/user identifier only when application policy allows it;
- clearing identity on logout;
- integration with existing global error hooks without double-reporting.

### 9.3 Feature flags

Create a `FeatureFlagService` with:

- strongly named keys rather than arbitrary strings throughout features;
- compiled safe defaults;
- a read-only stream/snapshot;
- development-only local overrides;
- reset override action;
- no remote dependency in the default template;
- deterministic tests.

Flags must not be used as security authorization. Server permissions remain authoritative.

### 9.4 Firebase recipes

Create focused recipes for optional adapters:

- `docs/recipes/FIREBASE_CORE.md`;
- `docs/recipes/FIREBASE_ANALYTICS.md`;
- `docs/recipes/FIREBASE_CRASHLYTICS.md`;
- `docs/recipes/FIREBASE_REMOTE_CONFIG.md`;
- `docs/recipes/FIREBASE_MESSAGING.md`.

Each recipe includes:

- packages and CLI/setup commands;
- Android/iOS native files and flavor mapping;
- DI registration replacement;
- consent/privacy implications;
- debug verification;
- test strategy;
- removal/rollback steps.

The base build and tests must succeed without installing Firebase packages unless the implementation chooses a compile-safe optional example. Never include fake production credentials.

## 10. Pagination toolkit

Create a backend-neutral pagination model supporting page-number and cursor APIs.

Core concepts:

- `PageRequest`/cursor request;
- `PageResult<T>` with items, next cursor/page, and end reached;
- immutable pagination state;
- initial load;
- pull-to-refresh;
- load next page;
- initial failure;
- next-page failure without discarding existing items;
- refresh failure policy;
- de-duplication by stable item key;
- protection from concurrent duplicate loads;
- stale response protection;
- cancellation/disposal.

Provide one clear implementation pattern, preferably a reusable BLoC/helper plus an example feature. Avoid a generic abstraction so complex that normal features cannot customize it.

The example must use an in-memory/fake repository with deterministic latency and failure injection. It must not call a public API.

UI components:

- initial loader;
- empty state;
- retry state;
- next-page progress footer;
- next-page error/retry footer;
- pull-to-refresh;
- end-of-list handling without endless requests.

Acceptance criteria:

- repeated scroll signals produce one active next-page request;
- refresh invalidates stale page responses;
- duplicates are removed predictably;
- existing content remains visible after a load-more failure;
- tests cover page and cursor variants or shared behavior with representative adapters.

## 11. Feature generator

Implement `tool/create_feature.dart`.

Canonical usage:

```bash
dart run tool/create_feature.dart \
  --name profile \
  --state bloc \
  --with-domain \
  --with-route \
  --dry-run
```

Required options:

```text
--name <snake_case>
--state bloc|cubit|none
--with-domain
--with-route
--dry-run
--force (explicit, never default)
```

Default output should be minimal:

```text
lib/features/<name>/
├── data/
└── presentation/
```

Optional flags add only requested layers/files.

Requirements:

- validate names;
- never overwrite an existing feature by default;
- print intended/created files;
- produce analyzer-clean code;
- use current project package name rather than `flutter_starter` literals;
- add TODO/checklist guidance for DI and routes if safe automatic registration is not available;
- if automatic route/DI editing is implemented, use stable explicit markers and fail safely when markers are missing;
- generated tests compile;
- generator logic is separated from CLI/filesystem orchestration for testing.

Do not generate empty repository/use-case/domain abstractions that are not selected.

## 12. Design-system expansion

Add only components needed for complete v0.2 examples:

- `AppDialog`;
- `AppBottomSheet`;
- `AppDivider`;
- `AppSwitch` if v0.1 did not already provide it;
- `AppImage` with asset/network/error/loading handling behind a practical API;
- skeleton/loading placeholder;
- refresh wrapper;
- pagination footer;
- permission explanation card;
- environment badge restricted to non-production.

Requirements:

- semantic tokens only;
- Light/Dark support;
- text scaling and accessibility semantics;
- reduced-motion awareness for nonessential shimmer/animation;
- no package added for behavior that is simple to implement safely;
- image caching is optional and documented if a third-party cache is introduced.

## 13. Developer commands and documentation

Provide readable wrappers such as a `Makefile` or documented scripts for:

```text
setup
run-dev
run-staging
run-prod
format
analyze
test
build-android-dev
build-android-prod
build-ios-dev
generate-icons
generate-splash
rename
create-feature
```

The raw Flutter/Dart commands must remain documented for developers who do not use `make`.

Create/update:

- `README.md`;
- `docs/ARCHITECTURE.md`;
- `docs/FLAVORS.md`;
- `docs/DEEP_LINKS.md`;
- `docs/NOTIFICATIONS.md`;
- `docs/OBSERVABILITY.md`;
- `docs/PAGINATION.md`;
- `docs/FEATURE_GENERATOR.md`;
- Firebase recipes listed above.

Documentation must match actual paths and commands.

## 14. CI

Extend GitHub Actions without requiring secrets for pull-request validation.

Required jobs:

1. Format, analyze, and unit/widget tests.
2. Android debug build for development flavor.
3. Android release-mode unsigned/non-published build for production where feasible.
4. iOS simulator build for at least development flavor on a macOS runner.
5. Optional/manual matrix for all flavors if cost is significant; the policy must be documented.

Requirements:

- no signing secrets;
- no Firebase files required;
- cache keys include lockfile/Flutter version inputs;
- concurrency cancels obsolete runs on the same branch;
- uploaded artifacts exclude secrets and are clearly named by flavor/commit;
- workflow fails on formatting, analysis, tests, or build failure;
- local commands reproduce CI behavior.

## 15. Required tests

At minimum add:

1. Native/Dart flavor mapping validation.
2. Rename transformations for flavor IDs/names/schemes.
3. Deep-link valid/invalid parsing and duplicate suppression.
4. Pending protected intent behavior around session initialization/login.
5. Local notification permission-state logic using fakes.
6. Notification payload -> route-intent parsing and cold-start queuing.
7. Analytics sensitive-property redaction and logout reset.
8. Crash-reporter de-duplication/sanitization behavior.
9. Feature-flag defaults, overrides, stream replay, and reset.
10. Pagination initial load, refresh, load-more, duplicate prevention, stale-result rejection, and next-page error.
11. Feature generator validation, dry-run, conflict protection, and generated-code fixture checks.
12. Essential Light/Dark/accessibility widget smoke tests for new components.
13. Router/deep-link/notification integration test with injected fakes.
14. Existing v0.1 test suite remains passing.

No test may depend on a hosted domain, Firebase project, real notification permission dialog, real backend, or production credential.

## 16. Verification commands

Run and pass all v0.1 checks plus:

```bash
flutter test

flutter build apk \
  --debug \
  --flavor development \
  -t lib/main_development.dart \
  --dart-define-from-file=config/development.json

flutter build apk \
  --release \
  --flavor production \
  -t lib/main_production.dart \
  --dart-define-from-file=config/production.json

flutter build ios \
  --simulator \
  --no-codesign \
  --flavor development \
  -t lib/main_development.dart \
  --dart-define-from-file=config/development.json
```

Also exercise manually or through platform tooling:

- custom-scheme deep link cold start;
- runtime deep link;
- local notification display and tap;
- denied notification permission path;
- dev/staging/prod app identity.

If a native toolchain is unavailable, report the exact unverified command and rely on CI; do not claim success.

## 17. Out of scope

- Drift/SQLite database;
- offline-first sync/outbox;
- WebSocket reconnect manager;
- background sync execution;
- real FCM/APNs delivery;
- real Firebase project provisioning;
- Play/App Store deployment;
- purchase/subscription SDK integration;
- media permissions/gallery features.

## 18. Final acceptance checklist

- [ ] All v0.1 behavior and tests remain intact.
- [ ] Three native flavors build with correct IDs and names.
- [ ] Dart/native environment mismatch is detected.
- [ ] Icon and splash replacement/generation are documented and deterministic.
- [ ] Rename tool updates all flavor/native/deep-link identities safely.
- [ ] Deep links become validated typed route intents and work for cold/runtime delivery.
- [ ] Local notifications handle permission, schedule/display/cancel, and typed taps.
- [ ] Base app works without Firebase files or credentials.
- [ ] Analytics/crash/feature flags have safe no-op or development implementations.
- [ ] Sensitive analytics/crash data is rejected or redacted.
- [ ] Pagination handles refresh, concurrency, errors, duplicates, stale results, and end-of-list.
- [ ] Feature generator is minimal, dry-runnable, conflict-safe, and tested.
- [ ] New components use semantic tokens and are accessible.
- [ ] Native build CI runs without signing secrets.
- [ ] Documentation matches implementation.
- [ ] Format, analyze, tests, Android builds, and available iOS checks pass.
