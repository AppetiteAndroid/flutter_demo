# Contributing

Keep changes feature-first, constructor-injected and backend-free by default.
Do not commit credentials, signing material, private endpoints or commercial
font binaries. Optional vendor integrations belong in recipes until explicitly
promoted into the base template.

Before opening a pull request run:

```bash
make release-check
```

Changes to dependencies must update `docs/DEPENDENCIES.md`. Changes to native
identity must pass both fresh-copy and rename verification. Changes to UI must
include Light/Dark, localization and large-text coverage where relevant.
Generated Drift files are committed but never manually edited.

Use concise commit subjects. Maintainers review breaking public API changes
against `docs/PUBLIC_API.md` and record them in `CHANGELOG.md` and migration
notes.
