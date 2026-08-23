# Deep links

`PlatformLinkSource -> AppLinkService -> AppLinkParser -> AppRouteIntent ->
RouteIntentCoordinator` handles cold and runtime links, suppresses duplicates,
and queues protected details until session restoration/sign-in. Supported paths
are `/`, `/settings`, `/search?q=...`, and `/account/<positive integer>`.

Local custom schemes are `flutterstarter-dev`, `flutterstarter-staging`, and
`flutterstarter`. HTTPS hosts in native files are templates only. Production
App/Universal Links require hosting `/.well-known/assetlinks.json` with the real
Android SHA-256 fingerprint and `/.well-known/apple-app-site-association` with
the real Team ID/bundle IDs. Verify with `adb shell am start -W -a
android.intent.action.VIEW -d ...` and `xcrun simctl openurl booted ...`.
