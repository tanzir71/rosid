# Rosid (রসিদ)

Rosid is a fully offline Flutter scanner for Bangla and English receipts and
documents. Android defaults to receipt scanning and expense tracking; iOS
defaults to a documents-first experience. `AppProfile` keeps those variants in
one codebase.

## Local development

```sh
flutter pub get
FLUTTER_BIN="$(command -v flutter)" tool/check.sh
```

On Windows PowerShell, use the equivalent native entrypoint:

```powershell
flutter pub get
.\tool\check.ps1
```

The lightweight check runs localization/code generation, formatting, analysis,
tests, and the offline audit. Set `ROSID_RUN_BUILD=1` (or pass `-RunBuild` to the
PowerShell script) to include a debug APK on a machine with Android tooling and
sufficient disk.

After producing a release APK, run `tool/audit_offline.sh --require-merged` or
`.\tool\audit_offline.ps1 -RequireMerged`; release/tag audits fail if the merged
manifest cannot be located or contains a permission outside the privacy policy.

Release builds must include `eng.traineddata` and `ben.traineddata` in
`assets/tessdata/`; the tag workflow verifies the checked-in files against their
pinned SHA-256 values before building.

See [PROGRESS.md](PROGRESS.md), [TASKS.md](TASKS.md), and
[docs/RELEASING.md](docs/RELEASING.md).
