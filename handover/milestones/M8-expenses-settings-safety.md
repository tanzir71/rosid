# M8: Expenses, settings and safety

Goal: receipts become a simple month view; the app can be locked; everything can be backed up to one locked file and restored.

Read first: `01-product.md` (Expenses, Settings and safety), `02-architecture.md` (Safety), `design/screens.md` sections 09 and 10.

## Steps

1. **Expenses** tab (only when on): month switcher, total, change from last month, spending by category as bars, receipts this month, Export CSV.
2. **Check receipt**: total with the "items add up" note (or "items add up to ৳x, not the total" in warn colour), shop, date, VAT, paid with, category, items. Tapping a field shows its source on the receipt (from the detail's source line box).
3. **Categories** editable in Settings; currency fixed to taka in 2.0.
4. **App lock**: fingerprint through `local_auth`, PIN fallback (salted hash with a slow key derivation), lock on start and after 60 seconds in the background, lock screen in both languages. Hide paper content in the recent-apps preview while locked (`FLAG_SECURE` only while locked, so screenshots of unlocked screens still work for the user).
5. **Back up and move** screen: last backup, papers not backed up, monthly reminder toggle (in-app reminder on Home, no notification), password warning, Make a backup file, Bring papers from a backup file.
6. **Backup format** as in `02`. Restore validates the header, decrypts to a temporary folder, checks the database opens, then swaps in one step. A wrong password says so; a damaged file says so; nothing is changed on failure.
7. **Settings** complete: language, purposes, names, word choices, app lock, back up, works offline line, expenses, currency, storage, delete everything.

## Done when (Level B)

- [ ] Backup round trip test on the host: back up, wipe, restore, every table and file identical (hashes).
- [ ] Wrong password and truncated file tests: restore fails cleanly, existing data untouched.
- [ ] PIN lock test: correct PIN unlocks, wrong PIN does not, background timeout locks.
- [ ] Receipt check: "items add up" logic tested on fixtures with and without a match.
- [ ] End-to-end flows 8, 9 and 10 pass.
- [ ] Screens 09 and 10 match the design.
- [ ] STATUS updated, pushed; fingerprint hardware listed under "Not verified by machine".

## Fallbacks

- `local_auth` cannot be exercised on the emulator: test the PIN path end to end and the fingerprint path with a fake authenticator in widget tests; record it.
