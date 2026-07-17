# Rosid V1 manual QA

Run this checklist on a provisioned Android device with the release APK. Repeat
the profile section with `--dart-define=APP_PROFILE=ios` when an iOS runner is
not available.

## Airplane-mode receipt flow

1. Install and launch Rosid, then enable airplane mode before first use.
2. Scan the English printed fixture; crop, enhance, verify total/date, and save.
3. Search for the merchant and an OCR-only phrase; both must find the receipt.
4. Export the current month to CSV and inspect the file in a local spreadsheet app.
5. Repeat with a Bangla receipt using Bangla numerals, `৳`, and `মোট`.
6. Confirm no network permission appears in Android Settings for Rosid.

## Document and handwriting flow

1. Scan three pages into one document and verify page order.
2. Scan a handwritten note, correct the low-confidence OCR, add tags, and save.
3. Search for corrected body text, pin the document, and share it as one PDF.

## iOS profile flow

1. Launch with `APP_PROFILE=ios`; home must be a documents grid with no expense UI.
2. Capture a document; receipt mode must be absent.
3. Enable expense tracking in Settings; dashboard, receipt mode, categories, and CSV export must appear.
4. Disable it again; receipt-only routes and controls must disappear.

## Destructive/privacy checks

1. Delete one detail record and confirm its images disappear from app-private storage.
2. Use Delete all data and confirm history/dashboard/search are empty.
3. Relaunch in airplane mode and confirm the app remains functional.
