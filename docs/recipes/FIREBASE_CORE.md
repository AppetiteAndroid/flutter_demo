# Firebase Core recipe

Optional: run `dart pub global activate flutterfire_cli`, then `flutterfire
configure` separately for every native flavor. Store each downloaded
`google-services.json`/`GoogleService-Info.plist` only according to your private
credential policy; none is required by this starter. Add `firebase_core`, call
`Firebase.initializeApp` before DI, and replace no interfaces yet. Verify each
flavor in debug and test bootstrap behind a fake initializer. Review Google
data processing/privacy terms. Roll back by removing initialization, package,
Gradle/Xcode configuration and service files.
