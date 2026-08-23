# Flutter Production Starter — Full Specification

## 1. Product vision

Create a reusable Flutter repository that serves two purposes:

1. A production-ready starting point for new Android and iOS applications.
2. A living reference with clear examples for architecture, networking, dependency injection, BLoC, RxDart, theming, localization, session management, testing, and common mobile patterns.

The intended workflow is:

```bash
git clone <template-repository>
cd <template-repository>
dart run tool/rename_project.dart \
  --app-name "My App" \
  --package-name my_app \
  --bundle-id com.company.myapp
flutter pub get
flutter run -t lib/main_development.dart \
  --dart-define-from-file=config/development.json
```

The starter must remain understandable. It should demonstrate production practices without forcing ceremonial Clean Architecture into every small feature.

## 2. Guiding principles

- Feature-first organization.
- Explicit dependency injection and testable boundaries.
- BLoC for presentation state; RxDart for reactive data sources and stream composition.
- Semantic design tokens shared conceptually with Figma.
- Global session availability without uncontrolled mutable globals.
- Safe networking with typed failures and concurrency-safe token refresh.
- Compile-time environments without pretending mobile configuration is secret.
- A working example is more valuable than disconnected snippets.
- Optional integrations should live as recipes until a real application needs them.
- The cloned project must compile before commercial font files or a real backend are supplied.

## 3. Target structure

```text
.
├── AGENTS.md
├── FULL_SPEC.md
├── FEATURE_V0.1.md
├── FEATURE_V0.2.md
├── FEATURE_V0.3.md
├── FEATURE_V1.0.md
├── README.md
├── analysis_options.yaml
├── config/
│   ├── development.json
│   ├── staging.json
│   └── production.json
├── assets/
│   ├── fonts/
│   │   ├── README.md
│   │   ├── gilroy/
│   │   └── cera_round/
│   ├── icons/
│   ├── images/
│   └── translations/
│       ├── en.json
│       └── ru.json
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DESIGN_SYSTEM.md
│   ├── NETWORKING.md
│   ├── SESSION.md
│   └── recipes/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── bootstrap/
│   │   ├── config/
│   │   ├── di/
│   │   └── router/
│   ├── core/
│   │   ├── design_system/
│   │   ├── error/
│   │   ├── extensions/
│   │   ├── localization/
│   │   ├── logger/
│   │   ├── network/
│   │   ├── result/
│   │   ├── session/
│   │   ├── storage/
│   │   └── utils/
│   ├── features/
│   │   ├── home/
│   │   ├── settings/
│   │   └── example_search/
│   ├── main_development.dart
│   ├── main_staging.dart
│   └── main_production.dart
├── test/
├── integration_test/
├── tool/
│   ├── rename_project.dart
│   └── create_feature.dart
└── .github/workflows/
```

The exact number of files may evolve. Boundaries and behaviors matter more than reproducing this tree literally.

## 4. Application bootstrap

Bootstrap must perform asynchronous initialization before the application consumes dependencies:

1. Initialize Flutter bindings.
2. Initialize Easy Localization.
3. Parse and validate `AppConfig` from `--dart-define` values.
4. Initialize preferences and secure storage abstractions.
5. Register GetIt dependencies.
6. Restore persisted settings.
7. Restore the session snapshot and tokens.
8. Install global Flutter/framework error reporting hooks.
9. Run the app.

Bootstrap should expose a testable function and avoid hiding failures. Development builds may show detailed configuration errors; production builds should present a safe failure message and log through the configured logger.

## 5. Environments and configuration

Support:

- development;
- staging;
- production.

Use `--dart-define-from-file` with checked-in, non-secret defaults:

```json
{
  "APP_NAME": "Flutter Starter Dev",
  "ENVIRONMENT": "development",
  "BASE_URL": "https://example.invalid",
  "CONNECT_TIMEOUT_MS": 15000,
  "RECEIVE_TIMEOUT_MS": 30000,
  "ENABLE_NETWORK_LOGS": true
}
```

`AppConfig` must validate required values and provide typed fields. Documentation must state that values compiled into a mobile application are discoverable and must not contain real secrets.

Later native flavors may add different app icons, display names, and bundle identifiers. Compile-time Dart configuration is required independently of native flavors.

## 6. Dependency injection

Use GetIt with explicit module functions:

```text
lib/app/di/
├── dependency_injection.dart
├── core_module.dart
├── network_module.dart
└── feature_module.dart
```

Lifetime conventions:

- lazy singleton: stateless infrastructure, repositories with shared streams, `UserSession`, settings repository;
- factory: BLoCs/Cubits and short-lived coordinators;
- singleton: only when initialization already produced the concrete instance.

Prefer manual registration in the initial versions. `injectable` may be evaluated later if registration volume becomes a demonstrated maintenance problem.

## 7. User session

### 7.1 Responsibilities

`UserSession` is the global, in-memory, reactive snapshot of the current identity and access entitlement. It must:

- expose the latest `UserSessionState` synchronously;
- expose a replaying read-only stream;
- distinguish initialization, guest, and authenticated states;
- distinguish free, trial, active, grace-period, expired, and unknown subscription states;
- derive `hasPremiumAccess` from entitlement rules;
- update user data without reconstructing unrelated fields;
- update entitlement independently;
- clear state on logout or terminal refresh failure;
- restore a safe persisted snapshot during bootstrap;
- never expose mutable subjects.

Suggested types:

```dart
enum AuthenticationStatus { initializing, guest, authenticated }

enum SubscriptionStatus {
  unknown,
  free,
  trial,
  active,
  gracePeriod,
  expired,
}
```

`UserSessionState` contains:

- `AuthenticationStatus authenticationStatus`;
- `SubscriptionStatus subscriptionStatus`;
- `User? user`;
- `UserSubscription? subscription`;
- derived `isAuthenticated`;
- derived `hasPremiumAccess`.

`UserSubscription` should be extensible for:

- product/plan ID;
- expiry date;
- auto-renew state;
- platform/source;
- optional entitlement IDs.

Do not persist a standalone `hasPremiumAccess` boolean. Persist raw, verifiable state and derive access.

### 7.2 Storage and security

- Access and refresh tokens use `FlutterSecureStorage` through `TokenStorage`.
- Non-sensitive session snapshots may use preferences through `SessionSnapshotStorage`.
- Logout clears both.
- User models never contain tokens.
- Storage implementations remain replaceable in tests.

### 7.3 Integration

- `AuthRepository` updates the session after login, profile refresh, and logout.
- `SubscriptionRepository` updates entitlement after validation or restore.
- `AuthInterceptor` reads tokens and invalidates session after a terminal refresh failure.
- GoRouter observes the session stream through a Listenable adapter and performs auth redirects without recreating the router.
- Feature BLoCs receive `UserSession` through constructor injection and may subscribe to the read-only stream.

## 8. RxDart policy

RxDart is a first-class infrastructure tool, not a replacement for BLoC.

Use it for:

- replaying repository state;
- combining session, configuration, and local data;
- debounced search;
- switch-to-latest asynchronous queries;
- WebSocket pipelines;
- observing database changes;
- connectivity signals;
- settings/session streams.

Conventions:

- `BehaviorSubject.seeded` when a latest snapshot is required.
- `PublishSubject` for one-time internal event buses only when a simpler callback/Bloc event is insufficient.
- `ReplaySubject` requires an explicit bounded buffer and justification.
- Expose `Stream<T>`, never `Subject<T>`.
- Use `.distinct()` for stable state streams.
- Use `switchMap` for query streams where stale results must be discarded.
- Use `concatMap` for ordered writes when supported/appropriate.
- Avoid uncontrolled `flatMap` for writes.
- Dispose owners deterministically.

The example feature must demonstrate debounce, distinct queries, switch-to-latest results, loading/error/data states, and deterministic tests with no real network.

## 9. Settings

`SettingsBloc` manages:

- `ThemeMode.system`, `ThemeMode.light`, `ThemeMode.dark`;
- locale selection, initially Russian and English;
- initialization/restoration status;
- persistence through a settings repository;
- reset to defaults.

Requirements:

- restore settings before or during the app bootstrap without a visible incorrect-theme flash;
- apply changes immediately;
- keep localization integration out of data repositories;
- provide a complete settings screen;
- expose app version/build number on the settings screen when available;
- ensure all screen strings are localized.

## 10. Design system and designer handoff

### 10.1 Goals

- The designer and developer use the same semantic vocabulary.
- Rebranding requires changing token mappings rather than screens.
- Light/Dark mode is designed, not generated by blindly inverting colors.
- Feature code never chooses primitive palette values directly.

### 10.2 Token layers

Primitive palette example:

```text
brand.50 … brand.900
neutral.0 … neutral.1000
red.50 … red.900
green.50 … green.900
orange.50 … orange.900
blue.50 … blue.900
```

Semantic color tokens:

```text
brand.primary
brand.secondary

background.primary
background.secondary

surface.primary
surface.secondary
surface.elevated

text.primary
text.secondary
text.tertiary
text.inverse
text.disabled

icon.primary
icon.secondary
icon.inverse
icon.disabled

border.primary
border.secondary
border.focused

status.success
status.warning
status.error
status.info

state.disabled
state.pressed
state.hovered
state.overlay
```

Dart uses idiomatic camelCase equivalents such as `backgroundPrimary`. `docs/DESIGN_SYSTEM.md` must provide the exact mapping table between Figma paths and Dart fields, with Light and Dark values.

### 10.3 Flutter implementation

- `AppPalette`: primitive constants only.
- `AppColors`: immutable `ThemeExtension<AppColors>` containing semantic roles.
- `AppLightColors` and `AppDarkColors`: semantic mappings.
- `AppTheme`: constructs Material `ThemeData` and component themes.
- `BuildContext` extensions: `context.colors`, `context.textStyles`, `context.isDark`.
- Every `ThemeExtension` implements `copyWith` and `lerp` correctly.

### 10.4 Typography

Typography tokens:

```text
display.large
display.medium
headline.large
headline.medium
title.large
title.medium
title.small
body.large
body.medium
body.small
label.large
label.medium
label.small
```

Each token defines family, size, weight, line height, and letter spacing. Gilroy is the intended primary family; Cera Round is an accent/rounded family. The application must fall back safely when licensed binaries are absent.

### 10.5 Layout tokens

Initial spacing scale:

```text
xxs=4, xs=8, sm=12, md=16, lg=24, xl=32, xxl=48
```

Initial radius scale:

```text
xs=4, sm=8, md=12, lg=16, xl=24, full=999
```

Initial icon scale:

```text
small=16, medium=24, large=32
```

Design tokens should be explicit constants rather than magic numbers throughout features.

### 10.6 Component library

Target components over time:

- `AppScaffold`;
- `AppAppBar`;
- `AppButton` with primary/secondary/tertiary/destructive variants and states;
- `AppTextField` with label, hint, error, password, and disabled states;
- `AppLoader`;
- `AppErrorView`;
- `AppEmptyView`;
- `AppSnackBar`;
- `AppDialog`;
- `AppBottomSheet`;
- `AppImage`;
- `AppDivider`;
- `AppSwitch`;
- pagination footer;
- refresh wrapper;
- skeleton loading.

Components must preserve accessibility semantics, minimum touch target size, text scaling, and contrast.

## 11. Fonts

The repository may contain configuration and installation instructions for Gilroy and Cera Round, but must not source unlicensed files.

Expected optional layout:

```text
assets/fonts/gilroy/Gilroy-Regular.ttf
assets/fonts/gilroy/Gilroy-Medium.ttf
assets/fonts/gilroy/Gilroy-SemiBold.ttf
assets/fonts/gilroy/Gilroy-Bold.ttf
assets/fonts/cera_round/CeraRoundPro-Regular.ttf
assets/fonts/cera_round/CeraRoundPro-Medium.ttf
assets/fonts/cera_round/CeraRoundPro-Bold.ttf
```

Actual filenames and licensed weights may differ. `assets/fonts/README.md` explains how to add them and update `pubspec.yaml`. CI must not fail when the files are absent.

## 12. Localization

Use Easy Localization with JSON assets.

Initial locales:

- `en`;
- `ru`.

Conventions:

- hierarchical stable keys such as `settings.theme.title`;
- no complete English sentences as keys;
- interpolation and pluralization examples;
- a documented process for adding a locale;
- no user-facing strings embedded in widgets, exceptions being development-only diagnostics.

Future templates may add Kazakh and Portuguese examples without changing architecture.

## 13. Networking

### 13.1 ApiClient

The client supports:

- GET, POST, PUT, PATCH, DELETE;
- JSON requests/responses;
- multipart upload;
- file download;
- progress callbacks;
- cancellation;
- query parameters and custom headers;
- per-request auth opt-out;
- typed parsing callback;
- configured timeouts;
- development-only sanitized logs.

### 13.2 Authentication and refresh

Use separate concerns:

- `TokenStorage` persists tokens;
- `AuthInterceptor` attaches access tokens;
- `TokenRefreshService` calls the refresh endpoint with an unauthenticated client;
- a single-flight coordinator shares one in-progress refresh Future among concurrent 401 responses;
- original requests retry once after successful refresh;
- terminal failure clears tokens and invalidates `UserSession`;
- login and refresh endpoints can opt out of authorization and refresh handling.

Request recreation must preserve method, path, base URL behavior, body, query, headers, response type, cancellation, and extra metadata where safe.

### 13.3 Logging

Logs must redact at least:

- `Authorization`;
- cookies;
- access and refresh token fields;
- passwords;
- common secret/API-key fields.

Logs are disabled in production by configuration and build mode.

### 13.4 Failure model

Use typed application failures, including:

- network unavailable/connection failure;
- timeout;
- cancelled;
- unauthorized;
- forbidden;
- not found;
- conflict;
- validation, including server field errors;
- rate limited, optionally with retry-after;
- server failure;
- decoding failure;
- unknown failure.

Represent operation outcomes with a typed `Result<T>` sealed type. Do not use exceptions as ordinary UI state.

## 14. Routing

Use GoRouter with:

- named routes;
- path and query parameter examples;
- not-found/error page;
- auth redirect driven by `UserSession`;
- no redirect loop;
- nested navigation/ShellRoute support when bottom navigation is introduced;
- transition helpers for platform-appropriate, fade, slide, and no-transition cases;
- a place for navigation observers and analytics later;
- deep-link-ready route definitions.

The initial app should demonstrate home, settings, and example search routes.

## 15. Storage

Abstractions:

- `KeyValueStorage` for non-sensitive preferences;
- `TokenStorage` for credentials;
- `SessionSnapshotStorage` for a non-sensitive cached identity snapshot;
- `SettingsStorage`/repository for theme and locale.

Tests use in-memory fakes. Infrastructure plugins must not leak into BLoCs or domain models.

## 16. Error reporting and logging

Provide an `AppLogger` abstraction supporting debug, info, warning, and error plus stack trace. Bootstrap should connect:

- `FlutterError.onError`;
- `PlatformDispatcher.instance.onError`;
- guarded-zone errors when useful and compatible with binding initialization.

The base implementation may use `dart:developer`. Later Crashlytics/Sentry adapters should be replaceable without changing features.

## 17. Example features

### 17.1 Settings

A real, fully functional feature demonstrating persistence, BLoC, localization, theme changes, reusable components, and application information.

### 17.2 Reactive search

A deterministic example demonstrating:

- input stream;
- debounce;
- distinct queries;
- `switchMap` cancellation/ignoring stale results;
- repository abstraction;
- loading, empty, data, and failure states;
- UI via BLoC;
- tests without network.

The default data source may be in-memory so the starter runs without a backend. A separate remote data-source example should demonstrate ApiClient usage but must not execute automatically.

### 17.3 Session showcase

The home/debug section displays current auth and entitlement state and provides development-only controls to simulate guest/free/trial/active states. These controls must be clearly isolated and unavailable in production builds.

## 18. Rename tool

`tool/rename_project.dart` should eventually update:

- `pubspec.yaml` package name;
- Dart package imports;
- Android namespace and application ID;
- Android display label;
- iOS bundle identifier references and display name;
- environment display names/identifiers where present;
- README placeholders.

CLI inputs:

```text
--app-name      Human-readable name
--package-name  snake_case Dart package name
--bundle-id     reverse-domain identifier
--dry-run       show intended changes without writing
```

The tool validates all inputs, prints changed files, avoids build/generated directories, and is safe to rerun when possible. It must work on macOS and Linux using Dart APIs rather than platform-specific shell commands.

## 19. Feature generator

Post-v0.1, `tool/create_feature.dart` may generate a minimal feature skeleton:

```bash
dart run tool/create_feature.dart --name profile --with-domain
```

It must not generate unused abstractions by default. This is a roadmap item until explicitly promoted into a feature milestone.

## 20. Testing strategy

### Unit tests

- model derivations and serialization;
- repositories with fake data sources;
- settings persistence;
- session transitions;
- refresh concurrency and error mapping;
- RxDart pipelines;
- configuration validation;
- rename-tool validation and representative transformations.

### Widget tests

- app startup with fakes;
- theme and locale switch;
- settings controls;
- loading/empty/error/data states;
- basic navigation/redirect behavior;
- semantic design token availability.

### Integration tests

Later versions should cover a small critical path without depending on production services. Native permission/dialog automation may be introduced only when required.

No test should depend on a live public API.

## 21. Developer tooling and CI

Required checks:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Use code generation only when it materially improves JSON models or immutable classes. Generated files must stay synchronized.

GitHub Actions should cache Flutter/pub artifacts appropriately and run analysis and tests on pull requests and pushes to the primary branch. Debug build jobs may be added when stable and cost-effective.

Developer command wrappers may include:

```text
make setup
make run-dev
make run-staging
make run-prod
make format
make analyze
make test
make codegen
make rename
```

Scripts must remain understandable to developers who choose to run the underlying Flutter commands directly.

## 22. Documentation

`README.md` must include:

- what the starter provides;
- prerequisites;
- clone/setup/rename/run steps;
- environment configuration;
- font installation;
- architecture summary;
- test and code-generation commands;
- how to add a feature, route, dependency, color token, and translation;
- commercial-font and secret-handling warnings.

Detailed docs should explain decisions and include short copyable examples rather than duplicating source files.

## 23. Optional recipe modules

Keep these out of the base dependency graph until explicitly needed:

- Firebase initialization;
- Analytics and Amplitude;
- Crashlytics/Sentry;
- push/local notifications;
- deep links/universal links/app links;
- WebSockets;
- Drift/SQLite;
- background jobs;
- media/gallery access;
- in-app purchases and entitlement validation;
- remote config/feature flags;
- permissions;
- pagination;
- image caching;
- CI/CD store delivery.

Each recipe should state dependencies, platform setup, architecture integration, tests, privacy implications, and removal steps.

## 24. Roadmap

### v0.1 — foundation

- runnable Flutter project;
- architecture and DI;
- Light/Dark/System design system;
- Gilroy/Cera Round integration points and licensing-safe fallback;
- RU/EN localization;
- SettingsBloc and persistence;
- RxDart conventions and search example;
- global reactive UserSession;
- Dio client, typed failures, secure token storage, single-flight refresh;
- GoRouter integration;
- core UI components;
- dev/staging/production configuration;
- rename tool;
- tests, documentation, and baseline CI.

### v0.2 — production integrations

- native Android/iOS flavors and icons;
- Firebase adapter recipes;
- analytics/crash reporting adapters;
- notifications;
- deep links;
- pagination toolkit;
- feature generator;
- stronger native build CI.

### v0.3 — local data and real-time

- database recipe/reference implementation;
- WebSocket lifecycle and reconnect strategy;
- offline-first synchronization example;
- connectivity-aware UX;
- background task recipes.

### v1.0 — stable template

- public API and naming review;
- dependency and license audit;
- Android/iOS manual QA;
- complete documentation;
- verified rename flow;
- GitHub Template readiness;
- tagged release and migration notes.

## 25. Non-goals

- A universal abstraction over every Flutter plugin.
- Mandatory use cases/interactors for trivial forwarding.
- Shipping credentials or backend-specific business logic.
- Bundling commercial fonts without permission.
- Hiding Flutter, Dio, BLoC, or RxDart behind unnecessary wrappers.
- Automatically retrying every failed request.
- Treating cached subscription state as authoritative purchase validation.
- Supporting every Flutter platform in the first release.

## 26. Success criteria

The starter succeeds when a developer can:

1. Clone and rename it without manually hunting through native files.
2. Replace a documented set of design token values to apply a new brand.
3. Hand `docs/DESIGN_SYSTEM.md` to a designer and receive compatible Figma variables.
4. Configure a backend URL and auth endpoints without rewriting networking.
5. Read or observe the current user/session from any injected consumer.
6. Build reactive flows using demonstrated RxDart patterns.
7. Add a feature by following one obvious existing example.
8. Run analysis and tests successfully before starting product-specific work.
