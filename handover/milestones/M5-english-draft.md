# M5: English draft

Goal: an English draft of any Bangla paper, made on the phone, with names spelled as the user wants, terms rendered as the user chooses, and numbers, dates and units converted by rule.

Read first: `01-product.md` (English draft, Reference data), `02-architecture.md` (English draft), `design/screens.md` section 05.

## Steps

1. **Rules first** (no model needed), each a pure function with tests:
   - Numerals: Bangla digits to Latin.
   - Dates: Bangla calendar to Gregorian (rules in `01-product.md`), Bangla month names, `তারিখ`, and dates written in Gregorian with Bangla digits.
   - Units: land units with the converted value in brackets.
   - Terms: seed `terms` from an editable asset (`assets/data/terms.json`) built from the table in `01-product.md`.
   - Names: `names` table, name book screen, "As in passport" and "As in NID" sources, suggestions marked "Suggested, check".
   - Transliteration for unknown names: a rule-based Bangla to Latin transliterator tuned for common Bangladeshi name spellings (মোঃ → MD, আব্দুর → Abdur, রহমান → Rahman). Seed a list of at least 300 common name parts with their usual English spelling.
2. **Model files**: get Mozilla's Firefox Translations Bangla to English model (model, vocabulary, lexical shortlist) and record source, licence (MPL-2.0) and SHA-256.
3. **Integration A, WebView and WebAssembly**: a hidden WebView loads the Bergamot WebAssembly build and the model from app assets, with a JavaScript channel for requests and replies. No network permission. Translate line by line with placeholders for names and terms (see `02`). Keep the WebView alive while the English tab is open; release it after.
4. **Gate for integration A** on 40 synthetic land-record and certificate lines with reference English written into the fixtures: the draft keeps every number, date and name placeholder intact (100%), and median time per page is 8 s or less on `rosid_test`. Record a chrF score against the references for information (no threshold).
5. If A fails its gate, try **integration B** (native through FFI) with the same gate.
6. **English tab**: Bangla and English line by line, DRAFT stamp, info banner, "Spelling from your name book" and "New name. Check the spelling" marks, Names, Terms and Edit actions.
7. **Help with a term** sheet: explanation and the three choices; the choice applies to all land papers.
8. **Name book** screen with People and Places.
9. **Edit** the English line by line; edits are kept when the draft is remade, unless the Bangla line changed.
10. **Draft everywhere**: the stamp and the banner appear on every screen and in every export that shows English draft text (M6 enforces it in files).

## Done when (Level B)

- [ ] Rule tests pass, including at least ten verified Bangla calendar dates (record the published source used in the test file).
- [ ] Integration A or B passes its gate, or the fallback is shipped and recorded.
- [ ] Screens English draft, Help with a term, Name book, and English draft (dark) match the design.
- [ ] End-to-end flow 4 passes up to export.
- [ ] Release APK still has no network permission (WebView must not add it).
- [ ] arm64 APK size under 110 MB with the model included.
- [ ] STATUS updated with the integration that shipped and its numbers, pushed.

## Fallbacks

- Neither integration passes: ship "English for key details only". The English tab shows key details, names, terms, numbers, dates and units in English by rule, with a short line explaining that full sentences are not translated in this version. Remove "Get an English draft" wording that promises full translation from the landing page and README. Record it.
- The model does not fit the size limit: same fallback.
