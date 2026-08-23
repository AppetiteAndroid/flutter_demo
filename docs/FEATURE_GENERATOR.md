# Feature generator

Preview with `dart run tool/create_feature.dart --name profile --state bloc
--with-domain --with-route --dry-run`. State may be `bloc`, `cubit`, or `none`.
The generator reads the current pubspec package name, creates only selected
layers plus a compiling widget test, refuses conflicts, and overwrites only
with explicit `--force`. Route/DI files are not edited; a checklist is emitted.
