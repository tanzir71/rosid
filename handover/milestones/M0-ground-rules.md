# M0: Ground rules and baseline

Goal: a public repository with no workflows, Pages served from `main`, the new toolchain, a local verification script, and a recorded baseline. No app behaviour changes.

Read first: `00-current-state.md`, `03-verification.md`, `04-repo-and-release.md`.

## Steps

1. **Check access** as described in `04-repo-and-release.md`. Record what works in STATUS.
2. **Commit the handover** as it is: `AGENTS.md`, `GEMINI.md`, `.agents/`, `handover/`, `design/`. Message: `M0: add handover and design`.
3. **Line endings**: add `.gitattributes`, renormalise, commit.
4. **Remove workflows**: delete `.github/workflows/*` (and `dependabot.yml` if present). Commit `M0: remove GitHub Actions workflows`.
5. **Secret scan** of all history. If clean, **make the repository public** and set description and homepage. If not clean, skip this step and record.
6. **Pages from `docs/`**: move everything in `docs/` to `notes/`, fix links, add `docs/.nojekyll` and a placeholder `docs/index.html` (both languages, see `05-landing-page.md`), switch Pages to `main` `/docs`, push, confirm it serves. Then turn Actions off for the repository.
7. **Rulesets**: confirm direct pushes to `main` work. Adjust only if a rule blocks them (see `04`).
8. **Toolchain**: move to Flutter 3.50.1 (or newest stable, see `02`). Update `pubspec.yaml` constraints, run `flutter pub upgrade --major-versions` only for packages that need it, regenerate code, fix analysis issues. All 185 tests must still pass; a test changes only if a dependency change forced it, and the commit says which.
9. **`tool/verify.ps1` and `tool/verify.sh`** with Level A and Level B as specified. Level B in M0 only installs the debug build on `rosid_test`, starts it, waits for the home screen and takes a screenshot.
10. **Fake capture source** behind `ROSID_FAKE_CAMERA`. Not used by screens yet; a unit test proves a fixture frame comes out of it, and a test proves it is absent from release builds (for example a `kReleaseMode` assert and a check of the release APK's Dart symbols list for the class name).
11. **Baseline**: build the current release APK once (universal, as version 1 did) and record its size; run `tool/verify -Emulator -Evidence M0`; record cold start time.
12. **README**: replace the first paragraph with a short description of version 2 and a link to `handover/README.md`. Remove iPhone download mentions. Keep version 1 history further down or in `notes/`.
13. Update STATUS, push.

## Done when (Level B)

- [ ] `.github/workflows/` does not exist on `main`.
- [ ] Repository is public, or STATUS says exactly why not.
- [ ] `https://tanzir71.github.io/rosid/` serves the placeholder from `docs/` with no Actions run.
- [ ] Flutter version recorded; `flutter analyze` clean; all tests pass.
- [ ] `tool/verify.ps1` and `tool/verify.sh` exist and Level A passes; Level B installs and screenshots the app.
- [ ] `evidence/M0/summary.md` holds the baseline: test count, APK size, cold start.
- [ ] STATUS updated and pushed.

## Fallbacks

- Emulator cannot run on this machine: mark Level B "not run" with the reason, continue with Level A, mark M0 "done with gaps". Try again at the start of each later milestone.
- Flutter 3.50.1 breaks a dependency with no fix: stay on the newest version that works, record the blocker.
