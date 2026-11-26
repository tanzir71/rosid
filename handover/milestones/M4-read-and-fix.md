# M4: Read and fix

Goal: the user can see what was read, trust the parts that are right, and fix the parts that are not, quickly.

Read first: `01-product.md` (Read and fix, Finding details, Reference data), `design/screens.md` section 04.

## Steps

1. **Paper screen** with the three reader tabs: Scan, Text, English (English shows an empty state until M5).
2. **Text view**: the paper's text in Tiro Bangla on a paper surface, with uncertain words highlighted. The banner counts words to check and opens Check words.
3. **Kind of paper**: keyword classifier; the kind shows under the title and can be changed.
4. **Key details** card: rules per kind, starting with land records and receipts. Each detail keeps its source line.
5. **Check words**: one word at a time, the enlarged crop of the photo around the word (from the line box), the reading, up to three alternatives, Skip and Looks right, editing by tapping the reading. Progress "Word n of m".
6. **Remembered corrections**: saving a correction stores it in `corrections`; for names and places it also offers to add the word to the name book (M5 uses it).
7. **Tap a line** on the Scan tab: highlight the box, bottom sheet with the line's text, Copy, Fix text. When the line has a land area, show the unit conversions (decimals, square feet, acres, katha with "about").
8. **Units and numerals**: pure functions with tests for Bangla to Latin numerals and the land unit table in `01-product.md`.
9. **Edit** the full text, with the original kept.
10. **Copy** and **Listen** (Listen hidden if no Bangla voice is installed or if `flutter_tts` would need network; see `02`).
11. Library and Home show "n words to check" on papers that have them.

## Done when (Level B)

- [ ] Screens Read / Text, Check words, Scan tap a line, and Read / Text (dark) match the design; comparisons committed.
- [ ] Key details correct on 90% or more of land-record fixtures for khatian number, plot number and area.
- [ ] Unit conversion tests: 12.50 decimals gives 5,445 sq ft, 0.125 acre, about 7.56 katha; plus at least ten more cases.
- [ ] End-to-end flow 2 passes fully.
- [ ] Correcting a word, then scanning a fixture with the same misread word, offers the remembered form first (test).
- [ ] STATUS updated, pushed.

## Fallbacks

- Next-best candidates are not available from the recogniser: build alternatives from remembered words and a bundled Bangla word list with a small edit distance; record it.
