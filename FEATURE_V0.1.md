# Feature v0.1 — Foundation Milestone

## 1. Goal

Deliver the first runnable version of the Flutter Production Starter. v0.1 must establish the architecture and prove it with working settings, session, networking, design-system, routing, and reactive-search examples.

This is an implementation milestone, not only documentation or folder scaffolding.

## 2. Scope rule

- Implement every acceptance criterion in this document.
- Follow permanent conventions in `AGENTS.md`.
- Use `FULL_SPEC.md` for architectural intent.
- Do not implement v0.2+ integrations unless required to make a v0.1 abstraction real and testable.

## 3. Deliverable overview

v0.1 includes:

- a clean, runnable Flutter Android/iOS project;
- development, staging, and production Dart entry points/configuration;
- feature-first project structure;
- manual GetIt registration;
- Material 3 Light/Dark/System themes;
- semantic design tokens and designer handoff documentation;
- safe Gilroy/Cera Round integration points;
- Easy Localization with Russian and English;
- persisted `SettingsBloc`;
- RxDart conventions and a functional reactive-search example;
- global reactive `UserSession` with auth and subscription state;
- Dio `ApiClient`, typed result/failure model, secure token storage, and single-flight refresh;
- GoRouter with session-aware refresh/redirect support;
- small reusable UI kit;
- project rename tool;
- tests, README, architecture docs, and baseline GitHub Actions.

## 4. Project initialization

If no Flutter project exists, create one in the repository root with a neutral template identity:

```text
package name: flutter_starter
display name: Flutter Starter
bundle/application ID: com.example.flutterstarter
```

Requirements:

- Android and iOS platform folders exist.
- The project uses the stable Flutter/Dart versions available in the implementation environment.
- `flutter pub get`, `flutter analyze`, and `flutter test` succeed.
- Default counter-demo code is removed.

## 5. Dependencies

Use current mutually compatible stable package versions rather than hardcoding versions from this document.

Required runtime capabilities/packages:

- `flutter_bloc`;
- `rxdart`;
- `get_it`;
- `dio`;
- `easy_localization`;
- `go_router`;
- `shared_preferences`;
- `flutter_secure_storage`;
- `package_info_plus`;
- value equality support where needed (`equatable` or an equally clear Dart-native approach);
- JSON support only if used by actual models.

Required test/development capabilities:

- `flutter_test`;
- `flutter_lints`;
- a mocking/faking approach such as `mocktail` when a hand-written fake is not clearer.

Do not add packages that are unused by v0.1. Prefer hand-written immutable/sealed models over adding code generation everywhere. If code generation is used, document it and commit generated output according to repository policy.

## 6. Required application structure

Implement a clear equivalent of:

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap/
│   ├── config/
│   ├── di/
│   └── router/
├── core/
│   ├── design_system/
│   ├── error/
│   ├── extensions/
│   ├── localization/
│   ├── logger/
│   ├── network/
│   ├── result/
│   ├── session/
│   └── storage/
├── features/
│   ├── home/
│   ├── settings/
│   └── example_search/
├── main_development.dart
├── main_staging.dart
└── main_production.dart
```

Exact filenames may differ, but dependencies must flow inward through explicit interfaces and constructor injection.

## 7. Bootstrap and configuration

Create:

- `AppEnvironment` enum;
- typed immutable `AppConfig`;
- one entry point for each environment;
- shared bootstrap function;
- config JSON examples under `config/`;
- safe global error hooks through `AppLogger`.

`AppConfig` fields:

- app name;
- environment;
- base URL;
- connect timeout;
- receive timeout;
- network logging enabled.

Acceptance criteria:

- invalid required configuration fails with a clear message;
- production never enables verbose network logging merely because a config file contains `true`;
- config docs explicitly warn that Dart defines are not secret storage;
- application startup does not visibly flash the wrong saved theme when avoidable.

## 8. Dependency injection

Register dependencies manually with GetIt.

Required lifetimes:

- singleton/lazy singleton: config, logger, storage abstractions, settings repository, token storage, session storage, `UserSession`, Dio clients, ApiClient, repositories;
- factory: BLoCs/Cubits.

Acceptance criteria:

- DI setup is split into readable modules/functions;
- no widget directly constructs Dio, SharedPreferences, or FlutterSecureStorage;
- tests can build features with fakes without initializing real plugins;
- `UserSession` is globally resolvable but normally constructor-injected.

## 9. Design system

### 9.1 Color system

Implement:

- primitive `AppPalette`;
- immutable `AppColors extends ThemeExtension<AppColors>`;
- explicit Light and Dark semantic mappings;
- `copyWith` and `lerp`;
- `context.colors` extension.

The semantic set must cover at least:

- brand primary/secondary;
- background primary/secondary;
- surface primary/secondary/elevated;
- text primary/secondary/tertiary/inverse/disabled;
- icon primary/secondary/inverse/disabled;
- border primary/secondary/focused;
- success/warning/error/info;
- disabled/pressed/overlay states.

### 9.2 Typography and layout tokens

Implement:

- `AppFonts` names and safe fallback behavior;
- an application typography builder or extension aligned to display/headline/title/body/label roles;
- `AppSpacing`;
- `AppRadius`;
- `AppIconSize`;
- convenient context accessors.

Do not commit/download font files. If licensed files already exist, wire them. Otherwise the app must compile with a system fallback and `assets/fonts/README.md` must document exact expected locations and `pubspec.yaml` steps.

### 9.3 Theme

Implement Material 3 Light and Dark `ThemeData` including at least:

- scaffold/background;
- AppBar;
- text selection/input decoration;
- filled, outlined, and text buttons;
- dialogs and bottom sheets;
- snackbar;
- switch/checkbox/radio;
- navigation bar/list tiles/dividers where used;
- status/navigation bar icon brightness appropriate to the mode.

### 9.4 Designer handoff

Create `docs/DESIGN_SYSTEM.md` with:

- Figma token name → Dart property mapping;
- Light/Dark HEX table using the starter defaults;
- typography table including family, size, weight, line height, letter spacing;
- spacing, radius, and icon-size tables;
- instructions that designers must use Figma Variables and matching semantic names;
- a short rebranding checklist.

Acceptance criteria:

- feature widgets contain no raw color literals;
- shared layout values use tokens rather than repeated magic numbers;
- a developer can change the brand by editing documented token mappings, not screens.

## 10. Localization

Configure Easy Localization with:

- `assets/translations/en.json`;
- `assets/translations/ru.json`;
- English and Russian supported locales;
- fallback locale;
- persisted selected locale through settings;
- hierarchical stable keys;
- interpolation/plural example in documentation or demo.

Acceptance criteria:

- home, settings, search, common errors, and session showcase strings are localized;
- locale changes immediately without restart;
- adding another locale is documented;
- feature UI does not contain user-facing English/Russian literals.

## 11. Settings feature

Implement a functional Settings screen and `SettingsBloc`.

State includes:

- initialization/readiness;
- `ThemeMode`;
- selected locale.

Actions include:

- load/restore;
- set Light/Dark/System;
- set Russian/English;
- reset defaults.

Persist values through a repository/abstraction backed by SharedPreferences.

The screen must include:

- theme selector;
- language selector;
- app version/build number;
- reset action;
- reusable app components/tokens;
- localized labels.

Acceptance criteria:

- values survive a repository recreation;
- invalid persisted values fall back safely;
- rapid changes do not produce stale persistence;
- BLoC tests cover load, change, reset, and failure/fallback behavior.

## 12. UserSession

Implement `UserSession` as a GetIt lazy singleton backed by `BehaviorSubject.seeded` or an equivalent replaying RxDart stream.

Required types:

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

Required models/state:

- `User` with a small realistic identity model;
- `UserSubscription` with status, optional product ID, expiry, will-renew, and source/platform fields;
- immutable `UserSessionState`;
- derived `isAuthenticated`;
- derived `hasPremiumAccess` for trial, active, and grace period.

Required `UserSession` API behavior:

- read-only `Stream<UserSessionState>`;
- synchronous `current` getter;
- convenience `user`, `isAuthenticated`, `hasPremiumAccess` getters;
- initialize/restore;
- set authenticated session;
- update user;
- update subscription;
- logout/invalidate;
- deterministic dispose.

Storage:

- tokens in secure storage abstraction;
- non-sensitive session snapshot in preference abstraction;
- logout clears both;
- tests use memory fakes.

Acceptance criteria:

- new stream subscribers receive the latest state immediately;
- auth and subscription can change independently;
- `free` and `expired` do not grant premium;
- `trial`, `active`, and `gracePeriod` grant premium;
- no `Subject` is exposed;
- no token exists in `User` or non-secure storage;
- initialization has an explicit state and avoids accidental guest redirects before completion.

## 13. Networking

### 13.1 Result and failures

Implement a typed sealed `Result<T>` and typed `AppFailure` hierarchy covering:

- network/connection;
- timeout;
- cancelled;
- unauthorized;
- forbidden;
- not found;
- conflict;
- validation with optional field errors;
- rate limited;
- server;
- decoding;
- unknown.

Provide user-safe localized error mapping at the presentation boundary.

### 13.2 ApiClient

Implement a reusable Dio-backed client supporting:

- GET, POST, PUT, PATCH, DELETE;
- JSON parser callback/generic result mapping;
- query, headers, and body;
- multipart/form data;
- download/upload progress;
- cancellation;
- per-request authorization opt-out;
- configurable timeouts;
- sanitized debug logging;
- status/Dio exception mapping.

The public API should be concise enough for a data source to use without accessing raw Dio for normal calls.

### 13.3 Tokens and refresh

Implement:

- `TokenPair`;
- `TokenStorage` abstraction;
- FlutterSecureStorage implementation;
- memory fake for tests;
- authorization interceptor;
- separate refresh client/service;
- single-flight refresh coordination;
- retry original request once;
- terminal failure callback into `UserSession`.

Acceptance criteria:

- two or more concurrent 401 responses start exactly one refresh operation;
- all waiting requests receive the successful refreshed token path;
- a request is retried no more than once;
- refresh endpoint requests cannot recursively refresh;
- terminal refresh failure clears tokens and invalidates the session;
- headers/tokens/password fields are redacted in logs;
- POST and other non-idempotent operations are not generally retried except the single original retry after a confirmed auth refresh; no general transient retry policy is enabled;
- unit tests use fake adapters/services and no live backend.

## 14. Routing

Configure GoRouter with named routes for:

- home;
- settings;
- reactive search;
- a simple sign-in placeholder/session showcase if needed;
- not-found/error page.

Implement a stream-to-Listenable refresh adapter or equivalent so routing reacts to `UserSession` without reconstructing the router.

Acceptance criteria:

- initialization does not redirect prematurely;
- an authenticated-only sample route redirects guests appropriately;
- authenticated state can leave the sign-in placeholder;
- redirects do not loop;
- path/query parameter example exists and is typed/validated at the boundary;
- router behavior has representative tests.

## 15. RxDart example feature

Implement a functional search screen using an in-memory default data source so no backend is required.

Required behavior:

- seeded or controlled query input;
- trim/normalize query;
- debounce approximately 300–500 ms;
- ignore equal consecutive queries;
- switch to the newest asynchronous result;
- stale slow results never replace newer results;
- loading, empty, populated, and failure UI;
- retry action;
- BLoC owns presentation state;
- repository owns the RxDart query pipeline;
- subject remains private and is closed.

Also provide a non-executing remote-data-source example showing how the same repository boundary could use `ApiClient`.

Acceptance criteria:

- deterministic tests prove debounce/distinct/switch-latest behavior;
- tests do not wait unnecessarily long or use a real network;
- navigating away disposes screen-specific resources correctly.

## 16. Home/session showcase

Create a polished but simple home screen demonstrating:

- current environment;
- current theme/locale;
- current authentication state;
- current subscription state;
- derived premium-access value;
- navigation to settings and search.

In development only, allow simulation of:

- guest;
- authenticated free user;
- trial user;
- active subscriber;
- expired subscriber;
- logout.

Simulation controls must not appear in production builds and must use public session methods rather than mutating state.

## 17. Core UI components

Implement only the useful v0.1 subset:

- `AppScaffold`;
- `AppButton` with primary, secondary/outlined, and destructive intent;
- `AppTextField`;
- `AppLoader`;
- `AppErrorView`;
- `AppEmptyView`;
- `AppSnackBar` helper/presenter;
- reusable selection/list tile used by settings.

Requirements:

- use design tokens;
- support disabled/loading states where applicable;
- preserve semantics and adequate tap targets;
- avoid forcing every Material property through a custom wrapper.

## 18. Rename tool

Create `tool/rename_project.dart` with:

```bash
dart run tool/rename_project.dart \
  --app-name "My App" \
  --package-name my_app \
  --bundle-id com.company.myapp
```

Required behavior:

- validates human name is non-empty;
- validates Dart `snake_case` package name;
- validates reverse-domain bundle ID;
- updates `pubspec.yaml` package name;
- updates `package:flutter_starter/...` imports;
- updates Android namespace/application ID and display label;
- updates iOS bundle identifier references and display name;
- replaces documented starter placeholders;
- skips `.git`, `.dart_tool`, `build`, Pods, generated artifacts, and binary files;
- supports `--dry-run`;
- prints a summary of changed files;
- returns non-zero with a useful error for invalid input;
- uses Dart file APIs and works on macOS/Linux.

Add focused tests for argument validation and representative text transformations. If full native-file integration testing is impractical, separate pure transformation logic from filesystem traversal and test it thoroughly.

## 19. Documentation

Create/update:

- `README.md`;
- `docs/ARCHITECTURE.md`;
- `docs/DESIGN_SYSTEM.md`;
- `docs/NETWORKING.md`;
- `docs/SESSION.md`;
- `assets/fonts/README.md`.

README must provide copyable commands for setup, environment run, tests, fonts, rename, adding a feature, route, dependency, token, and translation.

Documentation must describe actual implemented APIs and paths. Remove aspirational examples that do not match code, or clearly label future work.

## 20. CI and repository hygiene

Add a baseline GitHub Actions workflow for pull requests and primary-branch pushes that:

- checks out the repository;
- installs the project-compatible stable Flutter SDK;
- runs `flutter pub get`;
- verifies formatting;
- runs `flutter analyze`;
- runs `flutter test`;
- caches only when the workflow remains understandable and correct.

Add/update `.gitignore` so it excludes build outputs, local environment overrides, IDE noise where appropriate, signing artifacts, and commercial font binaries if the project owner chooses not to track licensed copies.

Do not add deployment, Firebase, store signing, or release publishing in v0.1.

## 21. Required tests

At minimum:

1. AppConfig validation.
2. Settings restore/change/reset and invalid-value fallback.
3. UserSession initial, authenticated, user update, subscription update, logout, and replay behavior.
4. Premium access for every subscription status.
5. TokenStorage fake behavior.
6. API status/exception to failure mapping.
7. Sanitized log redaction helper.
8. Concurrent 401 single-flight refresh success.
9. Refresh terminal failure invalidates session.
10. Reactive search debounce, distinct, and switch-latest behavior.
11. Light/Dark `AppColors` availability and essential component theme smoke test.
12. Locale/theme settings widget behavior.
13. Router auth redirect behavior.
14. Rename input validation and transformations.
15. Basic app smoke test with injected fakes.

## 22. Verification commands

Run and pass:

```bash
dart format --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
```

If code generation is used:

```bash
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
```

When toolchains are available, additionally run:

```bash
flutter build apk --debug -t lib/main_development.dart \
  --dart-define-from-file=config/development.json

flutter build ios --simulator --no-codesign -t lib/main_development.dart \
  --dart-define-from-file=config/development.json
```

Do not weaken analyzer rules or delete meaningful tests simply to make checks pass.

## 23. Out of scope for v0.1

- Firebase and service configuration files;
- analytics/crash-reporting SDKs;
- remote push or local notifications;
- real in-app purchases/receipt validation;
- native flavors/icons beyond Dart entry points/configuration;
- database/offline sync;
- WebSocket reconnect implementation;
- background execution;
- gallery/media access;
- production login backend;
- generated feature CLI;
- release/store CI/CD.

Interfaces should permit these later, but v0.1 must not include unused dependencies for them.

## 24. Final acceptance checklist

- [ ] Fresh clone can run without a backend and without commercial font files.
- [ ] Light, Dark, and System themes work and persist.
- [ ] English and Russian work and persist.
- [ ] Designer token documentation exactly matches Dart token fields.
- [ ] `UserSession` is global, reactive, replaying, secure-storage-aware, and distinguishes auth from subscription.
- [ ] Trial/active/grace-period access is derived correctly.
- [ ] RxDart search example proves debounce and switch-to-latest behavior.
- [ ] Dio client supports required methods, cancellation, progress, typed failures, sanitized logs, and per-request auth behavior.
- [ ] Concurrent 401 responses cause one token refresh.
- [ ] GoRouter reacts safely to session changes.
- [ ] Settings and example screens use localized strings and semantic tokens.
- [ ] Rename tool updates Dart, Android, and iOS identities and has a dry run.
- [ ] No secrets or unlicensed font binaries are committed.
- [ ] Formatting, analysis, and tests pass.
- [ ] Documentation matches the delivered implementation.
