# Rosid (রসিদ)

Rosid 2.0 is an offline Android app that scans any Bangla or English paper, reads it, lets you fix uncertain words, makes an English draft, and packs papers into one file for an application. It requests no internet permission, uses no analytics or accounts, and keeps every model and font inside the APK.

See [handover/README.md](handover/README.md) for the version 2 specification and [handover/STATUS.md](handover/STATUS.md) for current build and verification status. Downloads and checksums are published on the [Rosid landing page](https://tanzir71.github.io/rosid/) and on GitHub Releases.

## Local verification

All checks run locally on the developer machine via `tool/verify` (there are no GitHub Actions workflows):

```powershell
flutter pub get
.\tool\verify.ps1                 # Level A: generate, format, analyse, test, offline audit
.\tool\verify.ps1 -Emulator       # Level B: adds headless emulator checks
.\tool\verify.ps1 -Release        # Release: adds split APK build, size, alignment, manifest and monkey checks
```

Equivalent Bash script: `tool/verify.sh` (`--emulator`, `--release`, `--evidence <milestone>`).

## Version 1 history and notes

Version 1.0.0 was an early-access receipt and document scanner. Its historical notes live in [notes/](notes/):

- [notes/ARCHITECTURE.md](notes/ARCHITECTURE.md)
- [notes/RELEASING.md](notes/RELEASING.md)
- [notes/MANUAL_QA.md](notes/MANUAL_QA.md)
- [notes/WEBSITE_RESEARCH.md](notes/WEBSITE_RESEARCH.md)
- [PROGRESS.md](PROGRESS.md) and [TASKS.md](TASKS.md)
