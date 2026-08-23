# v1.0 QA matrix

States are `PASS`, `NOT RUN` or `EXTERNAL`. Automated rows use fakes and no live
service. Manual results are dated 2026-08-23.

| Platform/scenario | State | Evidence/limitation |
|---|---|---|
| Android API 36.1 development startup, gesture navigation | PASS | APK installed; `MainActivity` rendered |
| Android near-minimum API | NOT RUN | no near-minimum AVD installed |
| Android three-button navigation | NOT RUN | installed AVD uses gestures |
| Android development debug / production release build | PASS | native build commands |
| Android notification permission pre/post 13 | PASS | service/widget tests; API 36 denial-safe UI |
| iOS 26.3 development simulator startup | PASS | app installed and rendered |
| iOS near-minimum simulator | NOT RUN | only current runtime installed |
| iOS development/production schemes compile | PASS | simulator builds, no signing |
| Light/Dark and large text | PASS | widget/accessibility tests |
| Permission denial | PASS | memory service and denial-safe tests |
| Link/notification cold/runtime parser paths | PASS | typed routing tests/template inspection |
| Database migration/restart and account isolation | PASS | fixture/reopen and rapid-switch tests |
| Offline/reconnect/realtime lifecycle | PASS | deterministic fake lifecycle tests |
| Production simulation controls | PASS | helper/widget/build configuration tests |
| Real App/Universal Links | EXTERNAL | owned domain, association files and signing required |
| Real FCM/APNs delivery | EXTERNAL | no Firebase credentials by design |
| Store signing/release | EXTERNAL | owner accounts/assets required |
| Guaranteed background scheduling | EXTERNAL | OS policy; recipes avoid guarantees |

Owner release QA must revisit every `NOT RUN` row on the product's actual
minimum OS/device matrix and record runtime/build identifiers.
