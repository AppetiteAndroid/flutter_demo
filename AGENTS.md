# Repository Agent Guide

## Purpose

This repository is a reusable, production-oriented Flutter starter for Android and iOS. A developer must be able to clone it, rename the application, replace design tokens, configure API endpoints, and immediately start building features.

## Sources of truth

Read these files before making changes:

1. `AGENTS.md` — permanent repository rules.
2. The active `FEATURE_V*.md` requested by the user — acceptance criteria for the current implementation milestone.
3. Earlier `FEATURE_V*.md` files — behavior that must remain working.
4. `FULL_SPEC.md` — long-term architecture and roadmap.

The active feature file controls scope. Do not implement later roadmap items merely because they appear in `FULL_SPEC.md` or a later feature file. A milestone assumes earlier milestones are complete; if they are not, report the failed prerequisite and repair only what is necessary for the active milestone.

## Working process

1. Inspect the repository and existing user changes before editing.
2. Make a short implementation plan for multi-step work.
3. Preserve unrelated changes and never replace working code without a reason.
4. Prefer the smallest implementation that fully satisfies the current acceptance criteria.
5. Keep the project runnable after every coherent change.
6. Before finishing, review the diff for architecture violations, secrets, sensitive logging, missing disposal, and untested error paths.

Do not stop after scaffolding or provide sample snippets in place of requested implementation.

## Supported platforms

- Android and iOS are first-class targets.
- Use the stable Flutter and Dart SDK available in the environment.
- Do not add web, desktop, Firebase, notifications, payments, or a database unless a feature document explicitly requests them.

## Architecture

- Organize product code feature-first under `lib/features/`.
- Put application composition, bootstrap, dependency injection, configuration, and routing under `lib/app/`.
- Put reusable, feature-independent code under `lib/core/`.
- Within a feature, use `data/`, `domain/`, and `presentation/` only when they add value. Small features may omit `domain/` and use `data/` plus `presentation/`.
- UI depends on abstractions or BLoCs, not directly on Dio, storage plugins, or concrete data sources.
- Repositories coordinate data sources and expose domain-friendly results or streams.
- Use constructor injection. Resolve dependencies with GetIt at composition boundaries. Direct service-locator calls are allowed in bootstrap/router integration, but avoid scattered `getIt<T>()` calls inside widgets and business logic.
- Do not create use-case classes that only forward one repository method without adding policy or orchestration.

## State and RxDart

- Use `flutter_bloc` for screen and feature state.
- Use RxDart for long-lived reactive sources, stream composition, search debounce, WebSockets, local-data observation, settings, and session state.
- Never expose a `Subject`; expose `Stream<T>` and explicit mutation methods.
- Use `BehaviorSubject` only when new subscribers require the latest value.
- Close every subject and cancel every manual subscription.
- Prefer `emit.forEach`/`emit.onEach` in BLoCs when appropriate so subscription lifecycle is managed by BLoC.
- Do not create subjects directly in UI widgets for business state.

## User session

- `UserSession` is a GetIt lazy singleton and a global reactive source.
- Keep authentication state separate from entitlement/subscription state.
- Do not reduce subscription access to a persisted boolean. Model at least unknown, free, trial, active, grace period, and expired states.
- Tokens belong in secure storage, never in the `User` model or SharedPreferences.
- `UserSession` may expose synchronous snapshots such as `current`, `user`, `isAuthenticated`, and `hasPremiumAccess`, plus a read-only stream.
- Prefer injecting `UserSession` into consumers even though it is globally resolvable.
- A terminal refresh-token failure must clear secure tokens, move the session to guest, and allow routing to react.

## Networking

- Use Dio behind an `ApiClient`/data-source boundary.
- Configure base URL, timeouts, and logging from compile-time app configuration.
- Never log authorization headers, cookies, refresh tokens, passwords, or sensitive request bodies.
- Refresh tokens with a single-flight mechanism so concurrent 401 responses do not start concurrent refresh requests.
- Retry an original request at most once after a successful refresh.
- Do not automatically retry non-idempotent requests such as POST unless the call explicitly opts in and has idempotency protection.
- Map transport and HTTP errors to typed application failures.
- Keep an unauthenticated Dio client available for login/refresh endpoints where needed.

## Design system

- Do not hardcode colors, text styles, radii, spacing, or common icon sizes in feature UI.
- Use semantic design tokens, not visual names such as `white`, `black`, or `greyButton`.
- Keep primitive palette values separate from semantic Light/Dark mappings.
- Flutter token names and Figma variable names must correspond predictably.
- Implement semantic colors through a typed `ThemeExtension` and access them through `BuildContext` extensions.
- Build reusable components from tokens. Do not create wrappers that add no behavior, consistency, or accessibility value.
- Keep Material 3 enabled and ensure Light, Dark, and System modes work.

## Fonts and assets

- Gilroy and Cera Round are commercial fonts. Never download, fabricate, or commit unlicensed font binaries.
- If licensed font files already exist in the repository, wire them using the documented filenames and weights.
- If they do not exist, keep the project compiling with system fallback fonts and provide exact installation instructions under `assets/fonts/`.
- All user-facing strings belong in localization files.

## Code quality

- Follow `flutter_lints` and repository analyzer settings.
- Prefer immutable state and models.
- Use sealed classes/enums where they make states exhaustive.
- Avoid `dynamic` at application boundaries; validate decoded JSON.
- Keep files focused and names explicit.
- Add comments for non-obvious concurrency, lifecycle, or platform behavior, not for self-explanatory code.
- Do not edit generated files manually.
- Never commit secrets, real API keys, signing files, service-account files, or production tokens.

## Testing

Add or update tests for behavior introduced by a change. All existing milestone tests must remain passing. At minimum, the foundation coverage includes:

- settings persistence and theme/locale changes;
- `UserSession` state transitions and replay of the latest state;
- premium-access derivation;
- refresh single-flight behavior and terminal refresh failure;
- representative API error mapping;
- RxDart debounce/switch-to-latest behavior;
- theme token availability in Light and Dark modes;
- basic application smoke/widget behavior.

Avoid tests that depend on a real network, real clock, or installed secure-storage platform implementation.

## Required verification

Run all commands that are available in the environment:

```bash
dart format --set-exit-if-changed .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

If code generation is not used by the final implementation, omit the build-runner command and remove unused code-generation dependencies.

When native toolchains are available, also verify at least one Android debug build and an iOS simulator build without signing. If an environment limitation prevents a command, report the exact limitation; do not claim it passed.

## Definition of done

A task is complete only when:

- requested behavior is implemented rather than described;
- the project remains runnable;
- relevant tests are present and passing;
- formatting and analysis pass;
- no secret or licensed binary was introduced;
- documentation matches the actual commands and file structure;
- the final response summarizes changes, verification, and any genuine remaining limitation.
