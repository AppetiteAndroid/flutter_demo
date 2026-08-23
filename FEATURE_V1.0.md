# Feature v1.0 — Stable Template Release

## 1. Goal

Promote the Flutter Production Starter from a feature-complete pre-release into a stable, repeatable GitHub Template release.

v1.0 is primarily a stabilization, audit, documentation, and verification milestone. Do not add major architecture or product integrations unless a blocking gap prevents the template from fulfilling its documented purpose.

## 2. Prerequisites

Before starting v1.0:

- `FEATURE_V0.1.md` is complete;
- `FEATURE_V0.2.md` is complete;
- `FEATURE_V0.3.md` is complete;
- all earlier checks pass on the primary branch;
- remaining known issues are listed and triaged.

If a prerequisite is incomplete, classify it as:

- blocking v1.0;
- safe documented limitation;
- post-v1.0 roadmap.

Do not hide incomplete acceptance items by deleting docs or tests.

## 3. v1.0 release principles

- A fresh clone works without private credentials, a backend, Firebase, licensed fonts, or signing assets.
- The simplest documented path is verified, not theoretical.
- Public names and extension points are consistent enough to support future minor releases.
- Example/debug behavior cannot leak into a production build.
- Every optional integration is clearly distinguished from base functionality.
- Platform limitations are stated honestly.
- The repository contains no user/project-specific identity or secret.
- Documentation describes current code, not future intentions.

## 4. Scope

v1.0 includes:

- public API/naming/architecture review;
- dependency, license, security, privacy, and secret audits;
- deterministic fresh-clone and rename verification;
- Android/iOS flavor build and manual QA matrix;
- accessibility, localization, performance, and lifecycle review;
- full test-suite reliability and coverage gap remediation;
- documentation consolidation and onboarding validation;
- CI hardening and release workflow;
- GitHub Template readiness;
- changelog, versioning, release notes, and v1.0.0 tag preparation;
- a post-v1.0 roadmap.

Out of scope:

- adding a real product backend;
- adding business-specific screens;
- bundling commercial fonts;
- shipping store credentials;
- promising universal links/push/background execution without external configuration;
- rewriting proven architecture solely for stylistic preference.

## 5. Public architecture and API review

Review every public/reusable type under `lib/app/` and `lib/core/`.

Check:

- names accurately describe responsibility;
- interfaces are neither plugin-shaped leaks nor unnecessary wrappers;
- ownership and disposal of long-lived objects are explicit;
- GetIt lifetimes are correct;
- constructor injection is used outside composition boundaries;
- BLoC/RxDart responsibilities remain distinct;
- no Subject or mutable collection escapes;
- Result/failure types are exhaustive and consistent;
- session authentication and entitlement remain separate;
- async methods have clear cancellation/idempotency semantics;
- database, sync, realtime, notification, and link streams have documented error/lifecycle behavior;
- generic helpers are demonstrably used and understandable;
- dead experiments/deprecated aliases are removed or migrated.

Breaking renames are allowed before v1.0 when they materially improve consistency. Apply them repository-wide with migration notes. Do not retain confusing duplicate APIs merely to avoid internal edits.

Create `docs/PUBLIC_API.md` describing intended stable extension points and what remains internal/subject to change.

## 6. Dependency audit

For every runtime and development dependency:

- confirm it is used;
- confirm it supports the project Flutter/Dart constraints;
- review latest compatible stable release and changelog/migration risk;
- confirm Android/iOS minimum requirements;
- record license and source;
- remove redundant packages;
- prefer SDK/Dart functionality where it is simpler and equally maintainable;
- ensure transitive native requirements are documented;
- ensure code-generation packages are pinned/compatible with generated output;
- ensure dependency overrides are absent or justified with an expiry issue.

Generate or maintain an auditable dependency/license report under `docs/DEPENDENCIES.md` or an automated equivalent.

Commercial font configuration is documented separately and no font binary is included without an explicit repository license decision.

## 7. Security and privacy audit

### 7.1 Secrets

Scan tracked files and Git-visible configuration for:

- API keys;
- Firebase service files from real projects;
- signing keys/profiles/certificates;
- `.env` secrets;
- tokens/passwords/cookies;
- private endpoints or user identifiers;
- sample values that accidentally look usable.

Update `.gitignore`, sample configs, and documentation. Add a CI secret-scanning step or documented repository security integration that does not require private credentials for normal PR checks.

### 7.2 Logging and telemetry

Verify:

- Dio/network logs redact sensitive headers/body keys;
- analytics properties reject PII/sensitive keys;
- crash context is sanitized;
- database/outbox payloads are not dumped into logs;
- WebSocket auth/message payloads are not logged unsafely;
- production logging level is restricted;
- debug simulation data is clearly synthetic;
- logout clears analytics/crash identity.

### 7.3 Storage and data isolation

Verify:

- tokens only use secure storage;
- session snapshots contain no tokens;
- user-scoped database rows cannot cross accounts;
- logout policy is implemented and documented;
- notification/deep-link payloads are treated as untrusted input;
- feature flags are not authorization;
- cached entitlement is not presented as server/store receipt validation;
- backup/data-protection implications are documented for application owners.

Create/update `docs/SECURITY.md` and `docs/PRIVACY_INTEGRATION_CHECKLIST.md`.

## 8. Fresh-clone verification

Automate a smoke process in a temporary directory or clean CI checkout:

1. Clone/copy only tracked template files.
2. Confirm no required local-only file is missing.
3. Run dependency resolution/code generation.
4. Run format/analyze/tests.
5. Build development Android and iOS simulator targets where runners permit.
6. Launch or smoke-test the app with no backend/Firebase/font files.

The process must not depend on the original developer's Flutter cache, IDE configuration, CocoaPods state, signing team, or globally installed custom script beyond documented prerequisites.

Acceptance criteria:

- setup commands in README are sufficient;
- sample config files are present;
- generated code policy is consistent;
- missing optional integrations degrade to documented no-op/fake behavior;
- no hidden manual edit is required before first run.

## 9. End-to-end rename verification

In a temporary copy, run:

```bash
dart run tool/rename_project.dart \
  --app-name "Example Notes" \
  --package-name example_notes \
  --bundle-id com.example.notes \
  --deep-link-scheme example-notes \
  --domain links.example.com
```

Then verify:

- no unintended `flutter_starter`, old app name, or old bundle ID remains in source/native project/config/docs intended for replacement;
- Dart imports resolve;
- all flavor IDs are derived correctly;
- Android manifest/resources/Gradle compile;
- iOS schemes/configs/project settings compile;
- custom URL scheme is updated;
- domain placeholders/templates update without fabricated association credentials;
- icon/splash configuration still runs;
- tests pass;
- Android development/production build;
- iOS development simulator build when available;
- a second rename dry run is predictable and does not corrupt identifiers.

The test works on a temporary fixture/copy and never renames the release working tree.

Document any intentionally retained generic `Flutter Starter` references.

## 10. Platform QA matrix

Create `docs/QA_MATRIX.md` and record actual results.

Minimum Android coverage:

- one supported minimum or near-minimum API emulator/device;
- one current API emulator/device;
- debug development flavor;
- production release-mode build without store signing;
- gesture and three-button navigation where available;
- notification permission pre/post Android 13 behavior;
- deep-link cold/background/foreground paths;
- database migration/restart;
- offline/reconnect/realtime lifecycle.

Minimum iOS coverage:

- one supported minimum or near-minimum simulator/device where toolchains permit;
- one current iOS simulator/device;
- development and production schemes;
- Light/Dark, text scaling, permission denial;
- custom scheme and universal-link template verification;
- notification cold/background/foreground paths;
- database migration/restart;
- offline/reconnect/realtime lifecycle;
- background-task limitations documented rather than assumed.

Real universal links, FCM/APNs delivery, store signing, and background scheduling may remain application-owner verification items when external accounts/domains are absent. Mark them clearly as not exercised, not as passed.

## 11. Accessibility and adaptive UI

Audit every template/example screen and reusable component for:

- meaningful semantics labels/roles;
- screen-reader navigation order;
- minimum touch targets;
- sufficient Light/Dark contrast;
- no information conveyed only by color;
- text scaling without clipping at large accessibility sizes;
- keyboard focus where applicable;
- reduced-motion behavior for decorative animation/shimmer;
- safe areas and Android navigation modes;
- small-phone and large-phone widths;
- landscape behavior where supported;
- dialogs/bottom sheets remain usable with keyboard and text scaling.

Add automated semantics/widget/golden tests where stable and supplement them with a documented VoiceOver/TalkBack checklist.

Do not freeze text scaling to make screenshots pass.

## 12. Localization audit

Verify:

- no user-facing literals remain outside localization assets except documented diagnostics;
- English and Russian contain the same key set;
- plural/interpolation syntax is valid;
- long Russian strings do not overflow;
- locale persistence/startup behavior remains correct;
- dates/numbers are formatted through locale-aware utilities where examples display them;
- missing keys have a safe development diagnostic;
- adding a new locale is documented and tested.

Add a CI/test utility that compares translation key sets and detects invalid JSON.

## 13. Performance and lifecycle audit

Profile representative debug/profile flows and document results rather than inventing numeric guarantees.

Review:

- app startup/bootstrap work;
- unnecessary rebuilds in session/settings/reactive examples;
- large list/pagination rendering;
- image cache behavior;
- database query indexes and stream fan-out;
- sync engine batching/loops;
- WebSocket timers/reconnect disposal;
- notification/deep-link duplicate handling;
- memory retention after navigating away;
- behavior during repeated background/foreground transitions.

Use DevTools/profile mode where available. Fix demonstrated template regressions. Create `docs/PERFORMANCE.md` with measurement method, representative observations, and application-owner profiling checklist.

Avoid arbitrary micro-optimizations that reduce clarity without measured benefit.

## 14. Test-suite hardening

Review the complete test suite for:

- deterministic timing through injected clocks/durations;
- no live network/domain/Firebase/plugin permission dependency;
- temporary database/file cleanup;
- no order dependence;
- no shared GetIt leakage between tests;
- no pending timers/streams/subscriptions;
- useful failure messages;
- representative negative/error paths;
- migration fixtures kept under version control;
- generated code consistency;
- acceptable CI duration.

Add a small integration/smoke suite covering:

1. bootstrap to home;
2. theme/locale persistence;
3. session sign-in simulation and protected routing;
4. deep-link/notification typed routing through fakes;
5. pagination behavior;
6. offline local mutation and later fake sync;
7. realtime fake transport reconnect/logout;
8. database reopen/migration fixture.

Measure and remove flakiness. Do not solve flakes with long unconditional delays.

## 15. CI hardening

Required CI behavior:

- format;
- analyze;
- unit/widget tests;
- integration/smoke tests that run reliably in CI;
- translation key validation;
- generated-code drift check;
- database migration tests;
- Android development and production builds;
- iOS simulator build on the selected policy/cadence;
- fresh-clone/setup verification;
- end-to-end rename fixture verification;
- dependency/license report check;
- secret scan;
- concurrency cancellation for obsolete branch runs;
- clear artifact names and retention policy.

Pin or otherwise make the release Flutter SDK version reproducible. Document how and when it is upgraded. Dependency update automation may be configured, but major upgrades must not auto-merge without tests/review.

CI must not require production secrets for normal pull requests.

## 16. Documentation and onboarding

Consolidate documentation so a developer can answer these questions quickly:

- What is included by default?
- What is only an optional recipe?
- How do I clone, rename, and run each flavor?
- How do I replace colors, typography, icons, splash, and licensed fonts?
- How do I add a translation, route, feature, BLoC, repository, database table, sync operation, or realtime message?
- How do session, tokens, subscription status, refresh, deep links, notifications, analytics, sync, and realtime connect?
- How do I test and debug the project?
- Which external steps are required for Firebase, universal links, push, signing, and store release?
- How do I remove an optional integration cleanly?

Required top-level documentation:

- `README.md` as the short onboarding entry point;
- `CHANGELOG.md`;
- `CONTRIBUTING.md`;
- `LICENSE` selected by the repository owner;
- `docs/INDEX.md` routing to detailed docs;
- `docs/ARCHITECTURE.md` with current module boundaries;
- `docs/PUBLIC_API.md`;
- `docs/SECURITY.md`;
- `docs/QA_MATRIX.md`;
- `docs/PERFORMANCE.md`;
- `docs/TROUBLESHOOTING.md`;
- `docs/MIGRATING_TO_V1.md`.

No documentation page should present an unimplemented API as current behavior. Move future ideas to a clearly marked post-v1 roadmap.

Validate onboarding by following README in a clean environment or asking a developer unfamiliar with the repository to follow it and record friction.

## 17. GitHub Template readiness

Prepare repository metadata and hygiene:

- concise description and topics;
- template repository setting checklist;
- issue templates for bug/feature/documentation;
- pull request template with verification checklist;
- code owners only if real owners are known;
- security policy/contact without fabricated addresses;
- contribution guide;
- appropriate open-source license chosen explicitly by the owner;
- generated/example assets have known licenses;
- no personal organization/user IDs in workflows;
- default branch workflow references are correct;
- release artifacts and tags are reproducible.

Do not invent the repository owner's license choice, security email, or organization. Add explicit placeholders/checklist items requiring the owner when necessary.

## 18. Versioning and release

Use semantic versioning for the template release.

Prepare:

- package/app template version `1.0.0` where appropriate;
- `CHANGELOG.md` summarizing v0.1, v0.2, v0.3, and v1.0;
- migration notes for breaking pre-release API/name changes;
- release checklist;
- Git tag/release command documentation;
- GitHub Release notes draft;
- known limitations;
- post-v1 roadmap.

Do not push tags, publish releases, enable template settings, or choose a license on behalf of the owner unless explicitly authorized. Prepare the repository and commands, then report the owner actions remaining.

## 19. Required tests and audits

At minimum complete and record:

1. Entire v0.1/v0.2/v0.3 automated test suite.
2. Translation key-set/JSON validation.
3. Secret scan.
4. Dependency/license audit.
5. Generated-code drift check.
6. Fresh-clone setup smoke.
7. Full temporary-copy rename verification.
8. Android development debug and production release-mode builds.
9. iOS development simulator build where available/CI.
10. App startup without backend, Firebase, commercial fonts, or signing.
11. Debug/simulation tools absent or inaccessible in production.
12. Session/user data isolation on rapid user switch.
13. Deep-link and notification untrusted-input tests.
14. Database migration fixture.
15. Sync/realtime deterministic lifecycle tests.
16. Accessibility semantics/text-scale widget tests.
17. Manual Android/iOS QA matrix with honest pass/not-run/fail states.
18. README onboarding followed from a clean environment.

## 20. Verification commands

Run all previous milestone verification. The final exact commands must be listed in README/CI, but include at minimum:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
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

Also run repository-specific commands for translation validation, fresh-clone verification, rename E2E, license report, and secret scanning.

Do not claim unavailable native/manual checks passed. Record them as not run with the exact reason and ensure CI or the release checklist owns the follow-up.

## 21. Release blockers

The following block v1.0:

- format/analyze/test failure;
- reproducible fresh-clone failure;
- rename tool corrupts or misses active identifiers;
- development Android build failure;
- iOS configuration known broken without a documented environment-only reason;
- committed real secret/credential/signing material;
- cross-user data leak;
- tokens/sensitive payloads in logs;
- infinite refresh/reconnect/sync retry loop;
- migration loses valid fixture data;
- production build exposes destructive development controls;
- README cannot produce a runnable app from a clean clone;
- dependency/license status is unknown for shipped code/assets.

Non-blocking limitations must be documented explicitly and must not contradict advertised features.

## 22. Final acceptance checklist

- [ ] Every v0.1, v0.2, and v0.3 acceptance item remains satisfied or is documented as a genuine external-only limitation.
- [ ] Fresh clone runs without private inputs.
- [ ] Temporary-copy rename passes tests and native builds.
- [ ] Public names/extension points are consistent and documented.
- [ ] No unused/redundant dependency or unjustified override remains.
- [ ] Dependency and asset licenses are known.
- [ ] Secret, logging, storage, session, and privacy audits pass.
- [ ] No cross-user data leakage is possible in tested flows.
- [ ] English/Russian keys match and large text remains usable.
- [ ] Core screens/components pass accessibility review.
- [ ] Performance/lifecycle checks reveal no unresolved template regression.
- [ ] Test suite is deterministic and CI is green.
- [ ] Android and available iOS builds/QA pass with honest results recorded.
- [ ] Documentation matches actual code and optional/external steps are clear.
- [ ] GitHub Template metadata/checklists are prepared without fabricated owner data.
- [ ] `CHANGELOG.md`, migration guide, release notes, known limitations, and post-v1 roadmap are ready.
- [ ] Owner-only remaining actions are listed explicitly.
- [ ] Repository is ready for an authorized `v1.0.0` tag and GitHub Template enablement.
