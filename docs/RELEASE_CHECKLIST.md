# v1.0.0 release checklist

- [ ] Replace the `LICENSE` owner-action placeholder with the selected license.
- [ ] Resolve or accept `NOT RUN` rows in `QA_MATRIX.md`.
- [ ] Run `make release-check` and temporary-copy native rename checks.
- [ ] Confirm generated-code diff and CI success on `main`.
- [ ] Review dependency/license and secret reports.
- [ ] Review changelog, migration, release notes and limitations.
- [ ] Configure GitHub metadata/security from `GITHUB_TEMPLATE.md`.
- [ ] Create authorized tag: `git tag -s v1.0.0 -m "Flutter Production Starter v1.0.0"`.
- [ ] Push only after authorization: `git push origin v1.0.0`.
- [ ] Review/publish the draft release and artifacts.

The release workflow runs `tool/validate_release.dart --strict` and refuses to
release while the license placeholder remains.
