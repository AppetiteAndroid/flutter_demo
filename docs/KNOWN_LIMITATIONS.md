# Known limitations

- No real API/server, Firebase files, push delivery or socket service is bundled.
- App/Universal Links require owned domains, association files and signing IDs.
- Background execution is best-effort and requires platform owner setup.
- Drift is not encrypted by default; backup/protection policy is owner-defined.
- Cached subscription state is not purchase validation.
- Commercial Gilroy/Cera Round binaries are intentionally absent.
- Store signing, privacy disclosures and telemetry vendors are owner concerns.
- Flutter 3.47.1 reports a future built-in-Kotlin migration warning from
  `package_info_plus`; current Android builds pass and the major package upgrade
  is deferred to a tested minor release.
- No near-minimum Android/iOS runtime or Android three-button AVD was available;
  those manual QA rows are `NOT RUN`.
- Source license and real security contact require an owner decision before
  public template enablement/tagging.
