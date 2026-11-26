# Screens

Every screen in the Figma file, in flow order. Each entry gives the Figma node, the picture in `screens/`, a suggested route, what the screen shows and what it does. Text in quotes is final copy. Sample data (names, places, amounts) is invented; build with real data.

Frames are 412 by 915. The status bar is part of the frame, not of the app.

## 00 Start here

Board `14:1600` on page Screens: the flow overview and the design principles in `README.md`.

## 01 First run (section `9:2`)

### First run / 1 Language
`9:3` · `screens/first-run-1-language.png` · `/welcome`

Shows: "WORKS OFFLINE" pill, the wordmark, a Bangla line and an English line saying what Rosid does, two large language choices ("বাংলা / অ্যাপ বাংলায় ব্যবহার করুন" and "English / Use the app in English"), the line "No account. No internet. Your papers stay on this phone.", primary button "Continue".
Does: sets app language immediately (the screen re-renders in the chosen language).

### First run / 2 What you need
`9:90` · `screens/first-run-2-what-you-need.png` · `/welcome/purpose`

Shows: title "What do you need Rosid for?", help "Pick any. This only sets your home shortcuts, and you can change it later.", six selectable rows with icon, title and line: Visa and abroad paperwork; Land and property papers; Receipts and spending; Study notes and handouts; Office and shop paperwork; Family records. "Continue".
Does: stores purposes. "Receipts and spending" turns Expenses on.

### First run / 3 Camera
`9:186` · `screens/first-run-3-camera.png` · `/welcome/camera`

Shows: "Allow the camera to scan", explanation, three assurance rows (no internet permission; app lock; back up to a file you keep), "Allow camera", "Not now, import photos instead".
Does: "Allow camera" triggers the Android permission dialog. Either way ends on Home.

## 02 Home (section `9:263`)

### Home
`9:264` · `screens/home.png` · `/`

Shows: top bar with wordmark "রসিদ" and "Offline" pill; "What are you scanning?" with four tiles (Document, ID card, Receipt, Translate; order follows purposes); "Pick up where you left off" card with the paper, its state ("3 words to check") and actions "Check words" and "Translate"; "Bundles" with "See all" and the first bundle's progress ("7 of 11 papers ready") and what is missing; "Recent" papers; the dock (Home, Library, Bundles, Expenses).
Does: tiles open the camera in that mode; Translate opens the camera and goes straight to the English tab after reading.

Variants: Home (বাংলা) `14:1641` · `screens/home-bn.png`; Home (dark) `14:2014` · `screens/home-dark.png`.

## 03 Scan (section `10:306`)

### Scan / Camera
`10:307` · `screens/scan-camera.png` · `/scan?mode=document`

Shows: full-bleed preview (`camera/scene`), "Auto capture" toggle at top, the paper outline in accent with corner handles, hint pill "Edges found. Hold steady", mode switch (Document, ID card, Receipt), Import, shutter, tray "Done, 2 pages".

### Scan / ID card, back side
`10:396` · `screens/scan-id-card-back.png` · `/scan?mode=id`

Shows: Front and Back step indicator (Front done with its thumbnail), card-shaped outline, "Turn the card over" and "Front and back will be placed together on one page, ready to print or send."

### Scan / Adjust page
`10:466` · `screens/scan-adjust-page.png` · `/scan/adjust`

Shows: "Page 2 of 3", the page with draggable corner and edge handles and a round magnifier, filter chips (Auto, Original, Grey, Black and white), rotate, delete, page thumbnails with add, "Hold and drag to reorder", "Retake", primary "Read text".

### Scan / Reading on this phone
`10:605` · `screens/scan-reading.png` · `/scan/reading`

Shows: "Reading your paper", the page with a scan line, a step list (done: "Page straightened and cleaned", "Bangla and English text found"; current: "Reading the text, Line 9 of 14"; next: "Finding names, dates and numbers"), the handwriting note when it applies ("Part of this page is handwritten. Handwriting is harder to read, so check those words on the next screen."), "This happens on your phone. Nothing is uploaded.", "Cancel".

## 04 Read and fix (section `11:435`)

### Read / Text
`11:436` · `screens/read-text.png` · `/paper/:id?tab=text`

Shows: title and kind ("Land record, 1 page, scanned today"), reader tabs (Scan, Text, English), banner "3 words need a look" with "Check them", "Key details" (Khatian no., Plot (dag) no., Owner, Area with "12.50 decimals, about 5,445 sq ft"), the text on a paper surface in Tiro Bangla with uncertain words highlighted, bottom actions Export, Copy, Listen, Edit.

Variant: Read / Text (dark) `14:2090` · `screens/read-text-dark.png` (paper stays light).

### Read / Check words
`11:548` · `screens/read-check-words.png` · `/paper/:id/check`

Shows: "Check words", "Word 1 of 3", "From your scan" with the enlarged crop, "Rosid read this as" with the reading in a check-state field, "Or pick another reading" with three choices, the note "Rosid remembers names and places you correct, and reads them right next time.", "Skip" and "Looks right".

### Read / Scan, tap a line
`11:629` · `screens/read-scan-tap-line.png` · `/paper/:id?tab=scan`

Shows: the scan with the tapped line boxed, a bottom sheet "Area of land" with the line's text, "Page 1 of 1", "The same area in other units" (12.50 decimals, 5,445 sq ft, 0.125 acre, 7.56 katha), "Copy" and "Fix text".

## 05 Translate (section `11:727`)

### Translate / English draft
`11:728` · `screens/translate-english-draft.png` · `/paper/:id?tab=english`

Shows: info banner "This draft was made on your phone. Check names and numbers before you use it.", language legend (অ, A), each Bangla line followed by its English line on a paper surface, DRAFT stamp, marks under names ("Spelling from your name book" in good tone, "New name. Check the spelling" in warn tone), converted date and area in brackets, actions Export, Names, Terms, Edit.

Variant: Translate / English draft (dark) `14:2153` · `screens/translate-english-draft-dark.png`.

### Translate / Help with a term
`11:828` · `screens/translate-term-help.png` · sheet over the English tab

Shows: the term (খতিয়ান, Khatian), its explanation, "How should it appear in English?" with three radio choices and their descriptions, "Your choice is used for every land paper you translate.", "Use this".

### Translate / Name book
`11:907` · `screens/translate-name-book.png` · `/names`

Shows: "Names", the explanation, People (English spelling, source pill "As in passport", "As in NID" or "Suggested, check", Bangla below), Places, the note "Rosid suggests a spelling the first time it sees a name. You decide the final one.", add button.

## 06 Export (section `12:647`)

### Export / Options
`12:648` · `screens/export-options.png` · `/paper/:id/export`

Shows: "What goes in" chips (Scan, English draft, Bangla text), "File type" radios with descriptions (PDF, Word (.docx), Plain text (.txt), Pictures (.jpg)), "Options" (Page size A4; Keep the file under 2 MB, "Upload forms often set a limit"; Watermark with its text; Page for the translator to sign; Lock with a password), footer with file name and "3 pages, 1.4 MB", "Preview" and "Save to phone".

### Export / Preview for certification
`12:769` · `screens/export-preview-certification.png` · `/paper/:id/export/preview`

Shows: the English page laid out like the original, watermark, DRAFT TRANSLATION stamp, footer "Draft translation from Bangla", page strip (Scan, English, To sign), card "Next, get it certified" with "A translator or notary checks this draft, then signs and seals the last page. Most embassies and offices only accept a certified translation.", "Print" and "Save to phone".

### Export / ID card on one page
`12:857` · `screens/export-id-one-page.png` · `/paper/:id/export/id`

Shows: A4 preview with front and back, watermark "For visa application only" and "Copy made 26 Nov 2026", options Watermark (on), Cover a detail ("Hide a number or address before you share"), Black and white copy, "Print" and "Export".

### Export / Saved
`12:936` · `screens/export-saved.png` · `/paper/:id/export/saved`

Shows: SAVED stamp, "Saved to your phone", location and file name, size, actions Share ("WhatsApp, email, Bluetooth and more"), Print, Add to a bundle (shows the bundle name), Open the folder, "Done".

## 07 Library (section `12:1023`)

### Library
`12:1024` · `screens/library.png` · `/library`

Shows: search field "Search inside your papers", filter chips (All, Documents, IDs, Receipts, Land), month groups, paper rows with thumbnail, title, kind and date, pages or amount, pills ("3 words to check", "English", "Renew by 30 Jun"), dock.

### Library / Search inside papers
`12:1302` · `screens/library-search.png` · `/library?q=`

Shows: the query, "Found in 3 papers. Names in your name book match in both languages.", result cards with paper title, where it matched ("Page 1, Bangla text" or "English draft") and the matching lines with the hit highlighted.

## 08 Bundles (section `13:1076`)

### Bundles
`13:1077` · `screens/bundles.png` · `/bundles`

Shows: "Bundles", the explanation, bundle cards with progress bar, due date or missing item, "Start from a checklist" (Student visa, Visit visa, Land papers, Bank loan, Empty bundle, each with a line).

### Bundle / Checklist
`13:1236` · `screens/bundle-checklist.png` · `/bundles/:id`

Shows: title, summary "7 ready, 2 need work, 2 missing", due date, check rows: done (title and state), needs work (state in warn, action "Open" or "Check"), missing (action "Scan"); "Add"; primary "Export bundle".

Variant: Bundle / Checklist (বাংলা) `14:1879` · `screens/bundle-checklist-bn.png`.

### Bundle / Export
`13:1384` · `screens/bundle-export.png` · `/bundles/:id/export`

Shows: "How to pack it" radios (One PDF with a contents page; Separate files named 01-Passport.pdf and so on), "Order" with numbered ready papers and sizes, warning "The birth certificate translation is still a draft. Add the certified copy when you have it.", Keep each file under 2 MB, Watermark every page, footer with file name and size, "Save to phone".

## 09 Expenses (section `13:1491`)

### Expenses
`13:1492` · `screens/expenses.png` · `/expenses`

Shows: month, "Spent this month" total, change from last month, categories with bars and amounts, "Receipts this month" with "Export CSV", receipt rows, dock.

### Expenses / Check receipt
`13:1702` · `screens/expenses-check-receipt.png` · `/paper/:id/receipt`

Shows: Total with "6 items add up to the total" in good tone, "Tap a field to see where it was read on the receipt.", fields Shop, Date, VAT, "Paid with" chips (Cash, Card, bKash, Nagad), "Category" chips, items summary, "Save receipt".

## 10 Settings and safety (section `13:1837`)

### Settings
`13:1838` · `screens/settings.png` · `/settings`

Shows: groups "Language and reading" (App language, What you use Rosid for, Names, Word choices), "Safety" (App lock, Back up and move with "Last backup 12 Nov. 32 papers not backed up", Works offline with "No internet permission. Check under Android settings, Apps, Rosid"), "Expenses" (toggle, Currency), "This phone" (Storage, "Delete everything" in bad tone).

### Settings / Back up and move
`13:1971` · `screens/settings-backup.png` · `/settings/backup`

Shows: "Your papers live only on this phone" and the explanation, last backup and not-backed-up count, "Remind me every month" toggle, the password warning, "Make a backup file", "Bring papers from a backup file".

### Safety / Cover a detail
`13:2036` · `screens/safety-cover-detail.png` · `/paper/:id/export/cover`

Shows: "Drag over anything you want to hide.", the page with a black bar over a number, tools Black bar, Blur, Undo, the note "The covered part is removed from the copy you export. Your saved scan stays whole.", "Done".

## 11 বাংলা and dark variants (section `14:1640`)

Listed with their base screens above: Home (বাংলা), Bundle / Checklist (বাংলা), Home (dark), Read / Text (dark), Translate / English draft (dark).

## States not drawn

Build these from the same components and note them in STATUS: empty Library, empty Bundles, empty Expenses month, no camera permission on the camera screen, reading failed, export failed, restore failed, wrong PIN, lock screen.
