# Dependency and license audit

Audited against Flutter 3.47.1 / Dart 3.13.1 on 2026-08-23. Package license
files are authoritative. `dart run tool/check_dependencies.dart` ensures every
direct entry is documented and used (or classified as SDK/tooling), and rejects
`dependency_overrides`.

| Package | Scope/use | Constraint | License | Source |
|---|---|---:|---|---|
| `flutter` | UI SDK | SDK | BSD-3-Clause | https://github.com/flutter/flutter |
| `cupertino_icons` | adaptive Cupertino icon font asset | ^1.0.9 | MIT | https://pub.dev/packages/cupertino_icons |
| `dio` | HTTP boundary | ^5.9.2 | MIT | https://pub.dev/packages/dio |
| `easy_localization` | JSON localization | ^3.0.8 | MIT | https://pub.dev/packages/easy_localization |
| `flutter_bloc` | presentation state | ^9.1.1 | MIT | https://pub.dev/packages/flutter_bloc |
| `flutter_secure_storage` | token storage | ^10.0.0 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage |
| `get_it` | composition | ^9.2.1 | MIT | https://pub.dev/packages/get_it |
| `go_router` | routing | ^17.3.0 | BSD-3-Clause | https://pub.dev/packages/go_router |
| `package_info_plus` | settings version | ^9.0.1 | BSD-3-Clause | https://pub.dev/packages/package_info_plus |
| `rxdart` | reactive sources | ^0.28.0 | Apache-2.0 | https://pub.dev/packages/rxdart |
| `shared_preferences` | settings/snapshot | ^2.5.5 | BSD-3-Clause | https://pub.dev/packages/shared_preferences |
| `app_links` | platform links | ^7.0.0 | Apache-2.0 | https://pub.dev/packages/app_links |
| `connectivity_plus` | interface hints | ^7.3.1 | BSD-3-Clause | https://pub.dev/packages/connectivity_plus |
| `drift` | typed SQLite | ^2.34.3 | MIT | https://pub.dev/packages/drift |
| `drift_flutter` | Flutter database opener | ^0.3.1 | MIT | https://pub.dev/packages/drift_flutter |
| `flutter_local_notifications` | local notifications | ^21.0.0 | BSD-3-Clause | https://pub.dev/packages/flutter_local_notifications |
| `timezone` | notification timezone | ^0.11.1 | BSD-3-Clause | https://pub.dev/packages/timezone |
| `web_socket_channel` | WebSocket transport | ^3.0.3 | BSD-3-Clause | https://pub.dev/packages/web_socket_channel |
| `flutter_test` | widget/unit tests | SDK | BSD-3-Clause | https://github.com/flutter/flutter |
| `flutter_lints` | analyzer policy | ^6.0.0 | BSD-3-Clause | https://pub.dev/packages/flutter_lints |
| `build_runner` | Drift generation | ^2.15.3 | BSD-3-Clause | https://pub.dev/packages/build_runner |
| `drift_dev` | Drift generator | ^2.34.5 | MIT | https://pub.dev/packages/drift_dev |

`flutter pub outdated` reports major releases for `flutter_local_notifications`,
`flutter_secure_storage`, and `package_info_plus`. They are deferred because
they carry native/API migration risk; current lines support the pinned SDK and
pass native builds. Re-evaluate in a dedicated minor release with migration
tests. `cupertino_icons` is retained as an asset-only dependency: Flutter's
adaptive Cupertino path references its font even though application Dart files
do not import the package directly; removing it produces a release tree-shaker
missing-font warning.

Android uses Flutter's minimum SDK plus Java 17/desugaring. iOS uses the Flutter
deployment target. App icon/splash placeholders are repository-created template
artwork; Material Icons ship with Flutter. No commercial font binary is present.
The repository source license remains an explicit owner decision in `LICENSE`.

Flutter 3.47.1 currently warns that `package_info_plus` still applies the Kotlin
Gradle Plugin and must eventually migrate to built-in Kotlin. Current Android
debug/release builds pass; upgrade the package in a tested minor release before
a future Flutter version promotes that warning to an error.
