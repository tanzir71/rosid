# Verification without a person and without GitHub Actions

"Working" is proved on your machine, by scripts you commit, with evidence you commit. Nobody else will run anything.

## The three levels

| Level | What runs | Needs |
|---|---|---|
| **A** | Code generation, format check, static analysis, unit tests, widget tests, golden tests, benchmark on fixtures, offline audit of the manifest and dependencies | Flutter SDK only |
| **B** | Level A, plus end-to-end tests on a headless Android emulator using the fake capture source | Android SDK, an x86_64 system image, hardware acceleration |
| **Release** | Level B, plus a signed release build per ABI, size budget, 16 KB page alignment, release-manifest audit, random-input test on the release build | Release keystore (see `04-repo-and-release.md`) |

Every milestone file says which level its "Done when" list needs. If the machine cannot run Level B (no acceleration available), run Level A, mark Level B "not run" with the reason in STATUS, and continue. Do not mark the milestone "done"; mark it "done with gaps".

## `tool/verify.ps1` and `tool/verify.sh`

Create both in M0 by extending `tool/check.ps1` and `tool/check.sh`. Same switches on both:

| Switch | Adds |
|---|---|
| none | Level A |
| `-Emulator` / `--emulator` | Level B |
| `-Release` / `--release` | Release level |
| `-Evidence M3` / `--evidence M3` | Writes a log and a summary to `evidence/M3/` |

Rules for the script:

- Exit non-zero on the first failing step. Print which step failed.
- Never prompt. Never open a window that needs a click.
- Start the emulator itself if one is not running, with `-no-window -no-audio -no-boot-anim -camera-back none -camera-front none`, and wait for `sys.boot_completed`.
- Install with `adb install -r -g` so runtime permissions are granted without a dialog.
- Shut down only an emulator it started.
- Write `evidence/M<n>/summary.md` with: date, commit, Flutter version, each step with pass, fail or not run, timings, and the measured numbers below.

## Emulator setup (once, on your machine)

```text
sdkmanager "platform-tools" "emulator" "platforms;android-35" "system-images;android-35;google_apis;x86_64"
avdmanager create avd -n rosid_test -k "system-images;android-35;google_apis;x86_64" -d pixel_6
```

Also create `rosid_low` with 2 GB of memory (`hw.ramSize=2048` in its `config.ini`) for the memory check. Use a Google APIs image, not a Play Store image. If API 35 images are unavailable, use the newest available and record which.

## Test data

Nothing in the test data may come from a real person.

| Set | Where | How it is made |
|---|---|---|
| Synthetic papers | `test/fixtures/synthetic/` | A committed generator script renders papers from templates with several openly licensed Bangla fonts (for example Tiro Bangla, Noto Serif Bengali, Noto Sans Bengali, Hind Siliguri), so the set is not tuned to one typeface: land records, certificates, letters, receipts, bills. Each picture has a ground-truth `.json` with the full text and key details. At least 120 papers. |
| Photo-like copies | same folder, generated | The same papers with perspective tilt, uneven light, shadow, blur, JPEG noise and a background. Fixed random seed so results repeat. |
| Old fixtures | `assets/fixtures/`, `test/fixtures/receipts/` | The version 1 pictures and receipt text fixtures stay. |
| Handwriting sample | `test/fixtures/handwriting/` | Only if you find openly licensed Bangla handwriting images with a licence that allows redistribution. Record the source. Otherwise leave out and note it. |

The generator and its seed are committed. The generated images may be committed if the set stays under 60 MB; otherwise commit the generator and regenerate in `verify`.

## Benchmark

A Dart command-line tool, `tool/ocr_bench.dart`, runs the text pipeline on the fixture set on the host (no emulator) where the engine allows it, otherwise on the emulator through an integration test. It writes `evidence/M<n>/ocr-bench.json` and a short table in the summary:

- Character error rate and word error rate, by script and by fixture kind.
- Key-detail accuracy: exact match of total, date and shop for receipts; khatian number, plot number and area for land records.
- Median and 90th-percentile time per page.

Run it in M3 before changing anything, to set the baseline. Run it again after every change to reading.

## Gates

| Gate | Threshold | Level |
|---|---|---|
| Static analysis | No errors, no warnings | A |
| Tests | All pass | A |
| Printed English character error, synthetic set | 5% or less | A or B |
| Printed Bangla character error, synthetic set | At least 30% lower than the baseline measured at the start of M3 | A or B |
| Receipt total read exactly | 85% or more of receipt fixtures | A or B |
| Time for one page | Median 4 s or less on `rosid_test` | B |
| Cold start to home screen | 3 s or less on `rosid_test` (measured with `adb shell am start -W`) | B |
| Peak memory while reading a page | 600 MB or less on `rosid_low` (from `dumpsys meminfo`) | B |
| End-to-end flows | All pass (list below) | B |
| Random input | 5,000 `adb shell monkey` events on the release build with fixed seed, no crash, no "not responding" | Release |
| Network permission | None in the merged release manifest (`aapt2 dump permissions` on the built APK) | Release |
| Network libraries | No Firebase, Play Services, analytics or ad SDK classes in the APK (`apkanalyzer dex packages` search) | Release |
| APK size | arm64 APK at most 110 MB | Release |
| 16 KB page alignment | Every `.so` in the APK aligned for 16 KB pages (`zipalign -c -P 16 -v 4` and a check of `LOAD` segment alignment with `llvm-readelf`) | Release |
| Signed | `apksigner verify --print-certs` succeeds; certificate fingerprint recorded | Release |

If a gate fails and cannot be fixed within the milestone, follow the fallback in the milestone file and write the measured value in STATUS.

## End-to-end flows (Level B)

Written as Flutter integration tests in `integration_test/`, run with the fake capture source on `rosid_test`. Each saves screenshots at key steps to `evidence/M<n>/screens/`.

1. First run: choose English, choose two purposes, skip the camera, land on home.
2. Scan a two-page land record from fixtures, adjust page 2, read, see key details, check one word, save.
3. Scan an ID card front and back, export the one-page PDF.
4. Open the land record, make an English draft, set a name spelling, change a term choice, export PDF with the translator's page.
5. Export as Word and as text. Unzip the `.docx` and check that `word/document.xml` contains the Bangla text and the English draft.
6. Library: search a Bangla word, then the English spelling of the same name; both find the paper.
7. Make a bundle from the student visa checklist, attach two papers, export one PDF under 2 MB.
8. Expenses on: scan a receipt, total matches the fixture, month total updates, export CSV.
9. App lock on with a PIN, background the app, return, unlock.
10. Back up to a file with a password, delete everything, restore, the papers are back.
11. Switch to বাংলা and to dark theme; repeat flow 2 quickly.

For the save dialog and share sheet: test up to the point where the system UI opens, and check the file Rosid wrote to its temporary folder. Record "the system picker itself was not exercised" under "Not verified by machine".

## Screen comparison with the design

For each screen in `design/screens.md`, write a golden test that renders the Flutter screen at 412 by 915 logical pixels with the same sample content, and save it next to the design picture in `evidence/M<n>/compare/`. Golden files are the regression check from then on. Matching the design pixel for pixel is not required; matching layout, hierarchy, colours, type and copy is.

## Things a machine cannot prove

List them in STATUS under "Not verified by machine". Expected entries: a real camera lens and autofocus, real paper under real light, real fingerprint hardware, the system file picker and share targets, printing to a real printer, a real Bangla voice for read aloud, install on a physical phone from a browser download.

Do not write instructions for the owner to check these. They are recorded so nobody believes they were checked.
