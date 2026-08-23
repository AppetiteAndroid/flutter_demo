# Codex implementation prompt — Flutter Production Starter v0.1

Implement the complete v0.1 milestone of this Flutter starter repository.

Before editing anything, read these files in order:

1. `AGENTS.md`
2. `FEATURE_V0.1.md`
3. `FULL_SPEC.md`

Treat them as follows:

- `AGENTS.md` contains permanent engineering and verification rules.
- `FEATURE_V0.1.md` defines the exact required scope and acceptance criteria for this task.
- `FULL_SPEC.md` provides long-term context. Do not implement v0.2+ items unless v0.1 explicitly requires them.

## Goal

Produce a runnable, tested Flutter Android/iOS starter that can be cloned, renamed, rebranded through semantic design tokens, configured for an API, and used immediately as a reference architecture.

The finished v0.1 must include working implementations—not only folders or snippets—for:

- feature-first architecture;
- bootstrap and dev/staging/production configuration;
- manual GetIt dependency injection;
- Material 3 Light/Dark/System themes;
- semantic design tokens and designer handoff documentation;
- licensing-safe Gilroy and Cera Round integration points;
- Easy Localization with English and Russian;
- persisted `SettingsBloc`;
- RxDart reactive conventions and a functional debounce/switch-latest search example;
- global replaying `UserSession` with separate authentication and subscription/entitlement state;
- Dio ApiClient, secure token storage, typed failures, redacted logs, and concurrency-safe single-flight refresh;
- GoRouter integration driven by session changes;
- the v0.1 shared UI components;
- a Dart project-renaming tool with dry run;
- required tests, documentation, and baseline GitHub Actions.

## Execution instructions

1. Inspect the current repository, Git status, installed Flutter/Dart versions, and any existing files. Preserve unrelated user work.
2. If the repository is empty, initialize the neutral Flutter project specified in `FEATURE_V0.1.md`. If it already contains a Flutter project, adapt it rather than recreating it blindly.
3. Make a concise implementation plan mapped to the sections of `FEATURE_V0.1.md`.
4. Implement the full milestone. Do not stop after the initial scaffold and do not ask for design colors or backend details—the specification deliberately provides safe defaults and a no-backend demo path.
5. Use current stable, mutually compatible dependency versions resolved in the actual environment. Do not add unused packages.
6. Keep `UserSession` globally resolvable with GetIt but constructor-inject it into normal consumers. Never expose its Subject.
7. Keep authentication and subscription state separate. Derive premium access; do not persist a simple subscription boolean.
8. Make the RxDart example deterministic and runnable without a real API. Still provide an actual non-executing remote data-source example using the ApiClient boundary.
9. Implement refresh as single-flight and test concurrent 401 behavior. Never log tokens and never introduce a general retry policy for non-idempotent calls.
10. Do not download or fabricate Gilroy/Cera Round files. If licensed files are absent, keep compilation working through system fallback and document installation.
11. Do not add secrets, Firebase files, signing material, deployment, notifications, payments, database, or other v0.2+ dependencies.
12. Add tests while implementing rather than postponing all testing to the end.
13. Keep documentation synchronized with the actual source paths, public APIs, and commands.

## Required verification

At the end, run every applicable command required by `AGENTS.md` and `FEATURE_V0.1.md`, including at minimum:

```bash
dart format --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
```

If native toolchains are present, also attempt the specified Android debug and iOS simulator builds. Do not claim a command passed unless it was actually run successfully. Fix failures caused by your changes. If an environmental limitation remains, report it precisely without weakening tests or analyzer rules.

## Self-review before finishing

Review the final diff and explicitly check:

- every v0.1 acceptance item is implemented or has a documented genuine blocker;
- no raw feature colors or user-facing unlocalized strings remain;
- all Subjects/subscriptions have correct encapsulation and disposal;
- no tokens, passwords, secrets, authorization headers, or sensitive bodies can appear in logs;
- token refresh cannot recurse, duplicate concurrently, or retry the same request indefinitely;
- the app starts without a backend and without commercial font binaries;
- DI registrations and lifecycle/disposal are correct;
- tests do not call a live network or depend on platform secure storage;
- README/docs match the implemented project;
- no unrelated user changes were overwritten.

## Final response

Return a concise implementation report containing:

1. what was implemented;
2. important architecture decisions;
3. verification commands and their actual results;
4. any remaining limitation or follow-up explicitly outside v0.1.

Do not return a proposed implementation instead of editing the repository. Continue until the v0.1 definition of done is met or a real external blocker makes further progress impossible.
