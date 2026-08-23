# Branding source assets

The starter icon is an original geometric `T`. Android adaptive-icon XML uses
the committed vector and flavor colors: amber development, cyan staging, and
brand violet production. iOS currently uses the committed starter-owned
AppIcon set. Replace source artwork with square PNG/SVG files owned by your
team, then run `make generate-icons` and `make generate-splash`. These targets
validate the committed native assets; projects may adopt a pinned generator,
but normal builds never download artwork. Light and dark splash backgrounds
are defined in Android resources and the iOS LaunchScreen asset catalog.
