# Verification summary: M8

- **Date**: 2026-11-27 06:12:27 +06:00
- **Commit**: `f622d5d`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 2.01 |
| Code generation (build_runner) | pass | 5.66 |
| Generate OCR fixture bundle | pass | 4.45 |
| Format check | pass | 3.26 |
| Static analysis | pass | 6.8 |
| Unit and widget tests | pass | 49.23 |
| Offline audit (source) | pass | 0.23 |
| Build debug APK | pass | 34.63 |
| Start emulator and install debug APK | pass | 51.44 |
| Cold start launch and screenshot | pass | 20.43 |
| Integration tests (6 flow file(s)) | pass | 389.53 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:42 +278: All tests passed! |
| Cold start (ms) | 9935 |
| Integration flows | 6 file(s) passed |

## M8 verification notes

- **Expenses & Check receipt**: Monthly spending view (`/expenses`), month switcher, delta vs previous month, category horizontal bars, CSV export (with VAT & Paid with columns), editable receipt categories (`/settings/categories`), and Check receipt (`/paper/:id/receipt`) with items-add-up math (exact, tax-inclusive, and mismatch warning) plus tap-a-field source highlighting on the receipt preview.
- **App lock**: Fingerprint via `local_auth: 3.0.2` (`FlutterFragmentActivity` in `MainActivity.kt`) + salted Argon2id fallback PIN (`PinHasher` via pure-Dart `cryptography: 2.9.0`), lock on startup and after 60 s in background, `FLAG_SECURE` toggled ONLY while locked (`app.rosid.rosid/security`), bilingual lock screen. Real fingerprint hardware is listed under "Not verified by machine" in `handover/STATUS.md`; fake authenticator exercised in widget tests and PIN path verified end to end in Flow 9.
- **Encrypted backup & atomic restore**: `BackupService` exports a consistent `VACUUM INTO` SQLite snapshot + private `scans`/`processed`/`thumbnails` files + manifest ZIP encrypted with Argon2id + AES-256-GCM under header `ROSIDBK2` v2. Restore verifies header/version/MAC/ZIP/SQLite `PRAGMA integrity_check` in a temp staging folder before swapping DB and files atomically in one step. Host round-trip SHA-256 hash check, wrong-password failure, and truncated/corrupt file failure all passed with existing data untouched.
- **Visual comparisons**: 4 side-by-side comparisons against Figma committed in `evidence/M8/compare/` (`expenses.png`, `expenses-check-receipt.png`, `settings-backup.png`, `settings.png`).
- **Flows 8–11**: Verified end to end on `rosid_test` in `integration_test/flow_8_11_expenses_safety_test.dart` (alongside Flows 1–7).


