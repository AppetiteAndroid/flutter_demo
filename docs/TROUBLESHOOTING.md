# Troubleshooting

- **Config validation fails:** use matching flavor, entrypoint and JSON;
  `ENVIRONMENT` and `NATIVE_FLAVOR` must agree.
- **Generated Drift differs:** run `dart run build_runner build`; current
  build_runner accepts but ignores legacy `--delete-conflicting-outputs`.
- **Fonts missing:** expected. System fallback compiles; add only licensed files.
- **No backend/socket:** development uses fakes; `.invalid` endpoints are
  intentionally unreachable until replaced.
- **iOS flavor not found:** open `Runner.xcworkspace`, verify shared schemes,
  then run `make build-ios-dev`; simulator builds need no signing team.
- **iOS cannot load Flutter.framework:** preserve
  `LD_RUNPATH_SEARCH_PATHS=$(inherited) @executable_path/Frameworks` in shared
  Flutter xcconfig.
- **Android notification absent:** Android 13+ permission is user-triggered.
- **Rename fails:** use valid inputs and `--dry-run`; verification always uses a
  temporary copy and never mutates the source tree.
- **CI generated drift:** regenerate and commit `app_database.g.dart`.
