# M6: Export

Goal: every paper leaves the app in the form the user needs: a PDF that looks like the paper, an editable Word file, plain text, pictures, under a size limit, with the right marks on it.

Read first: `01-product.md` (Export), `02-architecture.md` (Export), `design/screens.md` section 06 and Cover a detail in section 10.

## Steps

1. **Export screen**: What goes in (Scan, English draft, Bangla text), File type, Options, a file name and size estimate at the bottom, Preview and Save to phone.
2. **PDF of the scan** with page size choice (A4, Letter, as scanned).
3. **English draft PDF** laid out like the original: the English text in the same order and rough position as the Bangla lines, DRAFT TRANSLATION stamp, a footer "Draft translation from Bangla". Bangla text, where shown, rendered as images (see `02`).
4. **Translator's page**: name, signature, date and seal lines.
5. **Preview for certification** screen with pages Scan, English, To sign; the "Next, get it certified" guidance.
6. **Word (.docx)** writer: paragraphs, a simple two-column table for side-by-side, on Bangla runs set the complex-script font (`<w:rFonts w:cs="Nirmala UI"/>`, which ships with Windows) and the language (`<w:lang w:bidi="bn-BD"/>`); do not embed fonts. The DRAFT label in the header of every page that has English draft text.
7. **Plain text** and **pictures (.jpg)**; **CSV** for receipts (keep version 1 format, add VAT and payment method columns).
8. **Size limit** loop as in `02`; the screen shows the result size before saving.
9. **Watermark** with purpose and date, on every page.
10. **ID card on one page** screen: preview, watermark toggle, Cover a detail, black-and-white copy, Print, Export.
11. **Cover a detail**: black bar and blur, undo, done. Applied only to exported copies.
12. **Password**: only if a permissively licensed pure-Dart PDF encryption option exists and opens in a standard PDF reader in a test you can run. Otherwise hide the option and record it.
13. **Save to phone** through the system save dialog, **Share**, **Print**; **Saved** screen with Share, Print, Add to a bundle, Open the folder (if Android allows opening the chosen folder; otherwise hide it).

## Done when (Level B)

- [ ] PDF tests: page count, page size, presence of the DRAFT text on every English page (extract text from the PDF in the test), watermark present when chosen, absent when not.
- [ ] Cover a detail test: the covered area in the exported page image has no pixels from the original (compare to the source crop).
- [ ] Size limit test: a 6-page scan exports under 2 MB, readable (minimum 150 DPI equivalent at A4) or the screen says it cannot.
- [ ] `.docx` opens with a zip reader, `document.xml` is valid XML and contains the Bangla and English text (flow 5). If LibreOffice is available on this machine, convert the file to PDF headlessly as an extra check; otherwise record "not run".
- [ ] End-to-end flows 3, 4 and 5 pass.
- [ ] Screens 06 and Cover a detail match the design.
- [ ] STATUS updated, pushed.

## Fallbacks

- Bangla in `.docx` shows boxes on a machine without a Bangla font: that is the reader's machine, not the file. Keep the text as text. Note in the export screen help: "Word needs a Bangla font to show Bangla text."
