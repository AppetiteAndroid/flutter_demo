# Localization

English and Russian JSON assets use identical hierarchical leaf keys. Static UI
strings call `.tr()`; dynamic domain content stays data. Example timestamps use
the backend-free locale-aware formatter in `core/localization`; applications
with broader date/number/plural requirements should adopt `intl` deliberately.

To add a locale:

1. Copy `assets/translations/en.json` to `<language>.json` and translate values.
2. Preserve placeholders exactly.
3. Add the locale to bootstrap and any language selection UI.
4. Add persistence/startup and long-text widget coverage.
5. Run `dart run tool/validate_translations.dart` and `flutter test`.

Missing keys remain visible as their key in development, making omissions
diagnosable without leaking sensitive runtime values.
