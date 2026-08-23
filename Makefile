.PHONY: setup run-dev run-staging run-prod codegen format analyze test test-v03 test-v1 validate-translations audit-dependencies scan-secrets verify-fresh verify-rename release-check build-android-dev build-android-prod build-ios-dev generate-icons generate-splash rename create-feature
setup:
	flutter pub get
run-dev:
	flutter run --flavor development -t lib/main_development.dart --dart-define-from-file=config/development.json
run-staging:
	flutter run --flavor staging -t lib/main_staging.dart --dart-define-from-file=config/staging.json
run-prod:
	flutter run --flavor production -t lib/main_production.dart --dart-define-from-file=config/production.json
codegen:
	dart run build_runner build --delete-conflicting-outputs
format:
	dart format --set-exit-if-changed .
analyze:
	flutter analyze
test:
	flutter test
test-v03:
	flutter test test/v03_database_repository_test.dart test/v03_sync_engine_test.dart test/v03_realtime_test.dart test/v03_connectivity_lifecycle_background_test.dart test/v03_widgets_test.dart
test-v1:
	flutter test test/v1_release_test.dart
validate-translations:
	dart run tool/validate_translations.dart
audit-dependencies:
	dart run tool/check_dependencies.dart
scan-secrets:
	dart run tool/scan_secrets.dart
verify-fresh:
	dart run tool/verify_template.dart --mode fresh
verify-rename:
	dart run tool/verify_template.dart --mode rename
release-check: codegen format analyze test validate-translations audit-dependencies scan-secrets
	dart run tool/validate_release.dart
build-android-dev:
	flutter build apk --debug --flavor development -t lib/main_development.dart --dart-define-from-file=config/development.json
build-android-prod:
	flutter build apk --release --flavor production -t lib/main_production.dart --dart-define-from-file=config/production.json
build-ios-dev:
	flutter build ios --simulator --no-codesign --flavor development -t lib/main_development.dart --dart-define-from-file=config/development.json
generate-icons:
	dart run tool/validate_branding.dart
generate-splash:
	dart run tool/validate_branding.dart
rename:
	@echo 'Run dart run tool/rename_project.dart with --app-name, --package-name and --bundle-id'
create-feature:
	@echo 'Run dart run tool/create_feature.dart --name <name> --dry-run'
