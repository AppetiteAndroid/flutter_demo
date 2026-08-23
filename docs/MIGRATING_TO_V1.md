# Migrating pre-release templates to v1.0

1. Set version `1.0.0+1` and pin Flutter 3.47.1, or deliberately repeat the
   complete native/dependency audit on another stable SDK.
2. Keep `cupertino_icons` when Flutter's adaptive UI path is present; it is an
   asset dependency even without a direct application import.
3. Use `ProductionAppLogger` or an equally restrictive sanitized adapter.
4. Dispose link, notification and feature-flag services with process services.
5. Preserve iOS flavor runtime search paths and simulator active architecture.
6. Adopt rename inputs `--deep-link-scheme`/`--domain` and Android path move.
7. Add localized auth/environment/subscription labels and locale-aware dates.
8. Run every v1 release tool and resolve findings.

No domain/session/result contract, offline schema or sync/realtime wire model
was renamed. v0.1–v0.3 application code remains source compatible.

The rename verifier intentionally retains old-name matcher strings inside the
rename tool/unit test and immutable `FEATURE_V*.md` acceptance history. Active
source imports, package metadata, native identifiers, configs and onboarding
documentation are not allowlisted.
