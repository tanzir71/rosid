# What Rosid 2.0 is

Rosid is an offline scanner for any Bangla or English paper. It scans the paper, reads it, lets the user fix what was misread, makes an English draft, and packs papers into one file for an application.

## Who it is for

- A family preparing a visa or admission file. Today they go to a photocopy shop for scans and to a translator for every Bangla paper, then rename and shrink files by hand for an upload form.
- A land owner with deeds and khatian in legal Bangla, who needs to know what a paper says and what its area is in other units.
- Anyone keeping records: ID copies, certificates, licences, bills and receipts.

Phones are mid-range Android, often 3 to 4 GB of memory. Bangla comes first, English is equal.

## The features

Each line is a behaviour the app must have. Screen names refer to `design/screens.md`.

### First run
- Choose the app language: বাংলা or English.
- Choose what Rosid is for (any of six purposes). This sets the home shortcuts and whether Expenses is on. It replaces the version 1 split between Android and iPhone defaults.
- A screen explains the camera permission before Android asks. "Not now" leads to importing pictures.

### Home
- Four ways to start: Document, ID card, Receipt, Translate.
- "Pick up where you left off": the most recent paper that still has words to check or no English draft.
- Bundles in progress, with what is missing.
- Recent papers.

### Scan
- Live edge detection on the preview. The outline follows the paper.
- Auto capture when the paper is steady and the picture is sharp. It can be switched off. A manual shutter always works.
- One short hint at a time: hold steady, move closer, too dark, glare.
- Several pages into one paper. A tray shows the count.
- Import pictures from the phone.
- **ID card mode**: front, then back. Both are placed on one A4 page.
- **Adjust page**: drag corners and edges, with a magnifier at the finger. Filters: Auto, Original, Grey, Black and white. Rotate, delete, reorder, add a page, retake.
- A progress screen names each step while the page is read, and says it happens on the phone.

### Read and fix
- Three views of a paper: Scan, Text, English.
- **Key details** found for the kind of paper (for a land record: khatian number, plot number, owner, area).
- Words the reader was unsure of are highlighted. A banner counts them.
- **Check words**: one uncertain word at a time, shown with the enlarged piece of the photo, the reading, and other readings to pick from.
- Corrected names and places are remembered and applied next time.
- **Tap a line** on the scan to see its text. For an area, show the same area in decimals, square feet, acres and katha.
- Copy, edit, and listen (read aloud with the phone's own voice, when a Bangla voice is installed).

### English draft
- Bangla and English shown line by line.
- **Names**: a name book holds the English spelling of each person and place. Spellings marked "as in passport" are always used. New names get a suggested spelling and a prompt to check.
- **Terms**: legal and land words have a short explanation and a choice of how they appear in English: both ("Khatian (record of rights)"), English only, or the Bangla word only.
- Bangla numerals become Latin numerals. Bangla calendar dates get the Gregorian date beside them. Land areas get a second unit beside them.
- The draft carries a DRAFT stamp everywhere it appears.

### Export
- Choose what goes in: scan, English draft, Bangla text.
- File types: PDF, Word (.docx), plain text, pictures (.jpg). Receipts also export as CSV.
- Options: page size, keep the file under a chosen size, watermark with purpose and date, a page for the translator to sign, password (only if it can be built with a permissively licensed library; otherwise the option is not shown).
- **Preview for certification**: the English page laid out like the original, the stamp, and guidance that a translator or notary must certify it.
- **Cover a detail**: black out or blur part of a page in the exported copy. The saved scan is not changed.
- Save to a place the user chooses, share, print.

### Library
- Every paper, grouped by month, filterable by kind.
- **Search inside papers** in Bangla and English, with the matching piece of text shown. A name in the name book matches in both languages.
- A paper can carry a date to renew by. It is shown in the app. No system notifications in 2.0.

### Bundles
- A bundle is a named list of papers for one purpose, with an optional due date.
- Start from a checklist (student visa, visit visa, land papers, bank loan) or an empty one.
- Each item is ready, needs work, or missing, with the next action beside it.
- Export a bundle as one PDF with a contents page, or as separate numbered files, with a size limit per file.

### Expenses
- Off unless the user chose "Receipts and spending" or turns it on in Settings.
- Month view: total, change from last month, spending by category, receipts.
- **Check receipt**: total, shop, date, VAT, how it was paid, category, items. A note says whether the items add up to the total. Tapping a field shows where it was read on the receipt.

### Settings and safety
- Language, purposes, names, word choices.
- **App lock** with fingerprint or PIN.
- **Back up and move**: one password-locked file with everything, saved wherever the user chooses. Restore from such a file. A monthly reminder inside the app.
- Storage used. Delete everything.
- A plain statement that the app has no internet permission, and how to check.

## What Rosid must be honest about

These are product rules, not copy suggestions.

1. **A draft is not a certified translation.** Every English draft is marked as a draft on screen and in every export. The app never calls a translation certified, official or accepted.
2. **Handwriting is best effort.** When part of a page looks handwritten, say so and send the user to check words.
3. **Unsure means marked.** Low-confidence text is always highlighted. Never hide uncertainty to look better.
4. **Conversions are calculated.** Converted dates and areas appear beside the original, never instead of it.
5. **Checklists are starting points.** Templates carry the line "Check the official list for your application."

## Not in 2.0

- iPhone build.
- Cloud sync, accounts, sharing between phones except through the backup file.
- Training a handwriting model.
- Automatic stitching of long receipts.
- Importing PDF files (pictures only).
- System notifications.
- English to Bangla translation.
- Currency conversion.

## Reference data to seed

### Terms (starting list, user can edit)

| Bangla | Default English | Explanation |
|---|---|---|
| খতিয়ান | Khatian (record of rights) | Government record of who owns a piece of land, with plot numbers and area |
| পর্চা | Porcha (copy of the khatian) | Certified copy of a khatian |
| দাগ নং | Plot (Dag) No. | Number of a plot on the survey map |
| মৌজা | Mouza | Revenue village, the unit of land survey |
| জে.এল. নং | J.L. No. | Jurisdiction list number of a mouza |
| নামজারি | Mutation (namjari) | Change of the owner's name in the land record |
| দলিল | Deed | Registered document of a land transaction |
| দাখিলা | Land tax receipt (dakhila) | Receipt for land development tax |
| ভূমি উন্নয়ন কর | Land development tax | Yearly tax on land |
| তফসিল | Schedule | Description of the property in a deed |
| ওয়ারিশ সনদ | Succession (warish) certificate | Certificate listing a person's heirs |
| জন্ম নিবন্ধন সনদ | Birth registration certificate | |
| জাতীয় পরিচয়পত্র | National ID card | |
| নিকাহনামা, কাবিননামা | Marriage certificate (nikahnama) | |
| ট্রেড লাইসেন্স | Trade licence | |
| উপজেলা, জেলা, ইউনিয়ন | Upazila, District, Union | Administrative areas; keep as names |
| পিতা, মাতা, স্বামী | Father, Mother, Husband | |
| মৃত | Late | Before a name |
| সাং | Village | Short for "resident of" in old records |

This list is a starting point written for this handover. Keep it in an editable asset, not in code.

### Land units

| Unit | Value | Fixed? |
|---|---|---|
| শতাংশ, শতক (decimal) | 1/100 acre = 435.6 sq ft | Yes |
| একর (acre) | 100 decimals = 43,560 sq ft | Yes |
| কাঠা (katha) | 720 sq ft = 1.65 decimals | Standard value; differs by district |
| বিঘা (bigha) | 20 katha = 33 decimals | Standard value; differs by district |

Show katha and bigha with the word "about". A region setting is a later feature.

### Bangla calendar

Bangladesh's revised calendar (in use since 2019): 1 Boishakh is 14 April. Boishakh to Ashwin have 31 days, Kartik to Magh 30, Falgun 29 (30 in a Gregorian leap year), Choitro 30. Earlier documents used earlier rules that can differ by a day.

Implement the conversion as a pure function with tests against at least ten date pairs you verify from a published calendar while building. For dates before 2019 show the result with "about". If you cannot verify the rules, show the original date only.
