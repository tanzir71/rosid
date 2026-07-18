# Rosid V1 manual QA

The native OCR fixture subset below is verified. Run the remaining checklist on
a clean physical Android device with the eventual signed release APK. Repeat the
profile section with `--dart-define=APP_PROFILE=ios` on Android when an iOS
runner is unavailable. The recorded emulator subset does not by itself complete
the full section 13 physical-device or native iOS acceptance gate. The owner has
deferred those real-device checks until after the initial early-access release.

## Recorded Android validation (2026-07-17)

- Debug and unsigned minified/R8 release APK builds succeeded.
- With the emulator in airplane mode, the native integration harness passed 3/3:
  English receipt through ML Kit; mixed English/Bangla receipt through ML Kit +
  Tesseract; and handwritten text through the editable document-review path.
- The strict merged release-manifest audit passed. The built manifest contained
  only `android.permission.CAMERA` and AndroidX's app-scoped signature
  compatibility permission; it contained no networking permission.
- Five emulator captures were recorded under `site/screenshots/`. The landing
  page displays optimized WebP derivatives of `dashboard.png`,
  `crop-enhance.png`, `receipt-review.png`, and `settings.png`; `enhanced.png`
  remains as an additional retained source capture.
- The optimized rebuilt page scored 100 for Performance, Accessibility, Best
  Practices, and SEO in Lighthouse 13.4 mobile mode. See the compact
  [recorded metrics](audits/lighthouse-v1.json).

## Airplane-mode receipt flow

1. Install Rosid, enable airplane mode, and only then launch it for the first time.
2. Scan the English printed fixture; crop, enhance, verify total/date, and save.
3. Search for the merchant and an OCR-only phrase; both must find the receipt.
4. Export the current month to CSV and inspect the file in a local spreadsheet app.
5. Repeat with a Bangla receipt using Bangla numerals, `৳`, and `মোট`.
6. From the release build tree, run
   `.\tool\audit_offline.ps1 -RequireMerged` in PowerShell or
   `./tool/audit_offline.sh --require-merged` in Bash. Confirm the merged
   manifest has no permission outside the allowlist. The verified build had only
   camera and AndroidX's app-scoped signature permission; the audit also permits
   `READ_MEDIA_IMAGES` if a future gallery dependency requires it.

## Document and handwriting flow

1. Scan three pages into one document and verify page order.
2. Scan a handwritten note, correct the low-confidence OCR, add tags, and save.
3. Search for corrected body text, pin the document, and share it as one PDF.
4. Export a 20-page document on a memory-constrained device and verify the PDF
   opens with every page in order.

PDF export is intentionally limited to 20 pages. The automated export test
verifies that a larger document is rejected before any page file is read.

## About and update channel

1. Open Settings and confirm About shows the installed version and build number.
2. Confirm the displayed update location is
   `https://github.com/tanzir-lameh/rosid/releases/latest` in both UI languages.
3. Repeat in airplane mode; Settings must render without a network request.

## iOS profile flow

1. Launch with `APP_PROFILE=ios`; home must be a documents grid with no expense UI.
2. Capture a document; receipt mode must be absent.
3. Enable expense tracking in Settings; dashboard, receipt mode, categories, and CSV export must appear.
4. Disable it again; receipt-only routes and controls must disappear.

## Destructive/privacy checks

1. Delete one detail record and confirm its images disappear from app-private storage.
2. Create and share a CSV or PDF export; after the share sheet closes, confirm
   the app-private temporary export is gone. Interrupt one export if the device
   permits, relaunch, then confirm startup/delete-all removes stale export and
   share-cache copies together with all raw, processed, and thumbnail files.
   History, dashboard, and search must be empty after delete-all.
3. Relaunch in airplane mode and confirm the app remains functional.

## Remaining distribution checks

1. After the tag workflow produces it, install and verify the signed Android
   GitHub Release asset. This physical-device check is owner-deferred for the
   initial early-access publication; the signed build itself is still pending.
2. Verify that Pages links to `rosid.apk` and the explicitly unsigned
   `rosid-ios-unsigned.ipa`, and that the displayed file hashes match the latest
   GitHub Release metadata.
3. If testing iPhone self-signing, follow `IOS_SELF_SIGNING.md` and verify that
   the 7-day free-provisioning limitation is shown before download.
4. Smoke-test the public Pages URL on mobile after deployment, confirm the
   published page matches the intended release, and run Lighthouse against the
   rebuilt page. Record the new result rather than carrying forward the prior
   design's accessibility score.
