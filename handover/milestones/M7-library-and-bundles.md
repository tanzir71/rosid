# M7: Library and bundles

Goal: every paper can be found again in either language, and papers for one purpose can be collected against a checklist and exported together.

Read first: `01-product.md` (Library, Bundles), `design/screens.md` sections 07 and 08.

## Steps

1. **Library**: grouped by month, filter chips (All, Documents, IDs, Receipts, Land), paper rows with kind, date, page count, amount for receipts, "n words to check" and "Renew by" pills.
2. **Search inside papers**: extend the FTS5 index with Bangla text, English draft text and name book spellings. A query in one script also searches the name book counterparts in the other. Results show the paper, where it matched (page and Bangla text, or English draft), and the matching lines with the hit highlighted.
3. Bangla search needs care: normalise to NFC, strip zero-width joiners for matching, and treat common spelling variants (য় and য়, ড় and ড়) as equal. Unit tests for each.
4. **Renew by** date on a paper (set from the paper screen); shown in Library and on Home when within 30 days.
5. **Bundles list** with progress and the next missing item; "Start from a checklist" templates (Student visa, Visit visa, Land papers, Bank loan, Empty bundle). Templates live in `assets/data/checklists.json`, each with the line "Check the official list for your application."
6. **Bundle checklist**: items with status (ready, needs work, missing) and the next action (Open, Check, Scan, Add); due date; add, remove, reorder items; link an existing paper or scan a new one into an item.
7. **Bundle export**: one PDF with a contents page and page numbers, or separate numbered files; per-file size limit; watermark every page; warning when a translation is still a draft.

## Done when (Level B)

- [ ] Search tests: Bangla word finds Bangla text; English spelling of a name finds the Bangla paper through the name book; English draft text is searchable; variants match.
- [ ] Search over 500 generated papers returns in 150 ms or less on `rosid_test`.
- [ ] Bundle export test: contents page lists items in checklist order with correct page numbers.
- [ ] End-to-end flows 6 and 7 pass.
- [ ] Screens 07, 08 and Bundle Checklist (বাংলা) match the design.
- [ ] STATUS updated, pushed.
