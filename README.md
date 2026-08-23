# Flutter Production Starter 1.0

A backend-free Android/iOS template demonstrating feature-first Flutter,
BLoC/RxDart, GetIt, GoRouter, Dio, secure session storage, semantic Material 3
themes, EN/RU localization, native flavors, typed links/notifications,
pagination, Drift offline-first sync, connectivity and realtime lifecycle.

The default development app uses deterministic in-memory/fake remotes. It does
not require Firebase, a backend, commercial fonts, signing credentials, or
private configuration. Firebase, production push, verified App/Universal Links,
store signing and scheduled background execution remain explicit recipes or
application-owner setup.

## Prerequisites

- Flutter 3.47.1 stable (Dart 3.13.1); see `.fvmrc` for the release pin.
- Android Studio/SDK for Android builds.
- macOS with Xcode for iOS builds.

## Clone, rename and run

```bash
git clone <your-template-url> example_notes
cd example_notes

dart run tool/rename_project.dart \
  --app-name "Example Notes" \
  --package-name example_notes \
  --bundle-id com.example.notes \
  --deep-link-scheme example-notes \
  --domain links.example.com \
  --dry-run

# Review the list, then repeat without --dry-run.
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor development \
  -t lib/main_development.dart \
  --dart-define-from-file=config/development.json
```

`--dart-define` values are compiled into the application and are not secrets.
Checked-in configs intentionally use `example.invalid`.

Canonical flavor commands are `make run-dev`, `make run-staging`, and
`make run-prod`. Native identifiers and external configuration are explained in
[FLAVORS](docs/FLAVORS.md), [DEEP_LINKS](docs/DEEP_LINKS.md), and
[NOTIFICATIONS](docs/NOTIFICATIONS.md).

## Verification

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test

dart run tool/validate_translations.dart
dart run tool/check_dependencies.dart
dart run tool/scan_secrets.dart
dart run tool/verify_template.dart --mode fresh
dart run tool/verify_template.dart --mode rename
```

Native commands:

```bash
make build-android-dev
make build-android-prod
make build-ios-dev
```

`dart run tool/verify_template.dart --mode rename --android` additionally
performs full Android builds in an isolated renamed copy. Use `--ios` on macOS.

## Extension points

- Feature: follow `lib/features/example_search` or `offline_tasks`; UI receives
  BLoCs/repositories through constructors.
- Route: add a named route in `lib/app/router/app_router.dart` and a validated
  typed intent when external input can open it.
- Dependency: register it in `lib/app/di/dependency_injection.dart`; keep GetIt
  at composition boundaries.
- Database table/sync operation: follow [DATABASE](docs/DATABASE.md),
  [MIGRATIONS](docs/MIGRATIONS.md), and [SYNC_ENGINE](docs/SYNC_ENGINE.md).
- Realtime message: add a typed model and strict parser branch described in
  [REALTIME](docs/REALTIME.md).
- Design: change primitive/semantic mappings documented in
  [DESIGN_SYSTEM](docs/DESIGN_SYSTEM.md). Commercial fonts are optional and
  never included by the template.
- Translation: add the same hierarchical keys to all JSON locale files and run
  `dart run tool/validate_translations.dart`.

Start with the [documentation index](docs/INDEX.md). Stable extension points are
listed in [PUBLIC_API](docs/PUBLIC_API.md); security responsibilities in
[SECURITY](docs/SECURITY.md); release limitations in
[KNOWN_LIMITATIONS](docs/KNOWN_LIMITATIONS.md).

## Release status

The code and release automation target `1.0.0`. The repository owner must choose
a source license, configure GitHub metadata/security contact, review the manual
QA rows, then authorize the `v1.0.0` tag. No tag or external setting is changed
by the template itself; see [RELEASE_CHECKLIST](docs/RELEASE_CHECKLIST.md).
