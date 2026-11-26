# M1: Design system and app shell

Goal: the app looks and navigates like the design. First run works. Both languages and both themes work. Data model is ready for version 2.

Read first: `01-product.md` (First run, Home, Settings), `02-architecture.md` (Data, Fonts), `design/README.md`, `design/screens.md` sections 00 to 02 and 11.

## Steps

1. **Fonts**: bundle Anek Bangla (Regular, Medium, SemiBold, Bold) and Tiro Bangla (Regular), subset. Add `NOTICE.md`.
2. **Tokens in code**: generate `lib/core/theme/tokens.g.dart` from `design/tokens.json` with a small script in `tool/`, so the JSON stays the source. Colours as light and dark sets, sizes, text styles (keep line heights), shadows.
3. **Theme**: replace the leaf-green theme in `lib/core/theme/app_theme.dart` with a `ThemeData` built from the tokens, light and dark. A `RosidColors` theme extension carries the tokens Material has no slot for (paper, stamp, highlighter, good, warn, bad). Paper surfaces always use the light paper colours, also in dark theme.
4. **Icons**: bring in `design/icons/*.svg` as a Rosid icon set (stroke icons, `currentColor`). One widget, `RosidIcon(RosidIcons.scan)`.
5. **Components** matching the Figma component set: Button (primary, tonal, outline, ghost), Chip, Pill (neutral, accent, good, warn, bad), Stamp, Field (default, check), Toggle, Radio, Paper thumbnail (letter, land, certificate, id, receipt, notes), Nav dock, Top bar, Paper row, Check row (done, check, missing), Reader tabs. Each gets a widget test and a golden.
6. **Shell and routes**: bottom dock with Home, Library, Bundles, Expenses (Expenses hidden when off). New routes for every screen in `design/screens.md`; screens not built yet show their real layout with an empty state, not a placeholder text.
7. **First run**: Language, What you need, Camera explanation. Store choices. Retire `AppProfile` as the switch for home behaviour; keep the file only if other code still needs platform facts.
8. **Home** with real data where it exists (recent scans), empty states where not.
9. **Settings** shell with language, purposes, theme following the system, storage, delete everything (existing logic).
10. **Language**: every visible string in ARB files, English and Bangla. Bangla wording from the Bangla design frames; for screens that only exist in English in the design, translate in the same plain register (use the Bangla terms already used in the Bangla frames: কাগজ, কাগজপত্র, ফাইল, খরচ, শব্দ দেখুন, ইংরেজি খসড়া, স্ক্যান). Numbers shown in Bangla numerals when the app language is Bangla.
11. **Schema version 3** migration (all tables in `02-architecture.md`), with a migration test from a version 2 database fixture containing receipts, documents and tags.
12. **Errors**: replace raw exception text in the interface with plain messages that say what happened and what to do.

## Done when (Level B)

- [ ] Goldens for every component, light and dark, English and Bangla.
- [ ] Screens First run 1 to 3, Home, Home (বাংলা), Home (dark), Settings render and match the design pictures in layout, type and colour; comparison images in `evidence/M1/compare/`.
- [ ] End-to-end flow 1 passes.
- [ ] Migration test passes; existing data from version 1 shows in Library.
- [ ] No hard-coded user-visible strings outside ARB files (add a test that scans `lib/` for string literals in `Text(` calls).
- [ ] STATUS updated, pushed.

## Fallbacks

- A component cannot match the design exactly in Flutter: build the closest version and note the difference in STATUS.
