# Architecture and technology decisions

Decisions are made here so you do not have to ask. Where a choice depends on a measurement, the rule for choosing is given. Versions were current on 26 November 2026; check each before depending on it and record what you used in `STATUS.md`.

## Principles

1. One pipeline for every paper: capture, clean the image, find lines, read lines, fix up text, find details, translate, export.
2. Every engine sits behind an interface, so it can be swapped after a benchmark without touching screens.
3. Measure before replacing. The benchmark in M3 is built first and the current engine's score is recorded as the baseline.
4. Heavy work never runs on the UI thread. Image and model work runs in a long-lived isolate or native code.
5. Rules before models. Numbers, dates, names, units and known terms are handled by code you can test. The translation model handles the rest.

## Toolchain

| Item | Decision | Fallback |
|---|---|---|
| Flutter | Move to 3.50.1. 3.50.0 has a bug that drops Android assets whose names start with a dot or sit in underscore folders, so do not stop at 3.50.0 | If 3.50.1 is not available, use the newest stable and add a check that every bundled model and font is inside the built APK |
| Material | Keep using Material from the Flutter SDK as version 1 does. If the Flutter version you move to has started moving Material into a separate package, follow the official migration only as far as the build requires | |
| State, routing, storage | Keep Riverpod, go_router, drift. Upgrade only within compatible ranges | |

## Packages

| Purpose | Package | Notes |
|---|---|---|
| Model runtime | `flutter_onnxruntime` (1.9.0 seen, wraps ONNX Runtime 1.28.0) | Needs the ProGuard rule `-keep class ai.onnxruntime.** { *; }` with R8 on. If it fails on Android, compare the other maintained ONNX Runtime bindings on pub.dev and record the choice |
| Image work | `opencv_dart` (2.3.2 seen, built on `dartcv4`, Apache-2.0) | Replaces the pure-Dart code in `lib/ocr/preprocess/` for heavy steps |
| Bangla line reading | `flutter_tesseract_ocr` (already present) | Kept only as a line recogniser, see "Reading text" |
| Icons | `flutter_svg` or compile the SVGs in `design/icons/` to a vector format at build time | No icon fonts from the network |
| Save to a chosen place | A Storage Access Framework package (`file_saver`, `flutter_file_dialog` or `file_selector`) | Pick one that needs no storage permission; verify on the emulator |
| Printing | `printing` | Uses the Android print service |
| Biometric lock | `local_auth` plus `flutter_secure_storage` for the PIN hash | |
| Encryption | `cryptography` | Argon2id for the key, AES-256-GCM for the file |
| Zip and docx | `archive` | Word files are zip files of XML; write them directly |
| Read aloud | `flutter_tts` | Check that it adds no network permission. If it does, drop "Listen" and record it |

Before adding any package: read its Android manifest and Gradle file. Reject it if it adds `INTERNET`, Google Play Services, Firebase or analytics. The offline audit must stay green.

Remove when their replacement passes its gate: the ML Kit dependency in `android/app/build.gradle.kts` and its method channel, the `image`-based heavy steps, `lib/ocr/engines/tflite_bn_stub.dart`.

## Capturing

- Use `camera`'s image stream. On Android copy the Y plane, shrink to about 320 px on the long side, send it to the image isolate.
- In the isolate: blur, Canny edges, find contours, approximate to four points, keep convex shapes covering more than 20% of the frame. Smooth the corners over a few frames.
- Auto capture when the corners have moved less than 2% of the frame diagonal for about 600 ms and the quality checks pass.
- Quality checks on the small frame: blur (variance of the Laplacian, threshold tuned on fixtures), glare (share of near-white pixels inside the outline), low light (mean brightness).
- Take the still at `ResolutionPreset.high` or above.
- **Fake capture source**: a debug-only source, selected with `--dart-define=ROSID_FAKE_CAMERA=true`, that feeds fixture pictures through the same code path as the camera. It must not exist in release builds. All end-to-end tests use it.

## Cleaning the image

In order: perspective warp to the outline, even out lighting (estimate the background with a large blur or morphological close and divide by it), CLAHE (clip 2.0, 8 by 8 tiles), light denoise, deskew. Keep a colour-corrected version and a grey version. Produce a black-and-white version only for the export filter. Recognisers get the grey version.

## Reading text

```
grey page  ->  line detector  ->  line crops  ->  script router  ->  Latin recogniser | Bangla recogniser  ->  lines with boxes and confidence
```

| Part | Decision |
|---|---|
| Line detector | PP-OCRv5 mobile detection model (about 4.7 MB, Apache-2.0), exported to ONNX on your machine with PaddleOCR's own exporter. Commit the `.onnx` file and its SHA-256 |
| Detector settings | Long side at most 960, both sides multiples of 32. Threshold 0.3, box threshold 0.6, unclip ratio 1.5. Contours and minimum-area boxes with OpenCV |
| Line crops | Perspective crop per box, rotate if height is more than 1.5 times width, resize to 48 px height |
| Latin recogniser | PP-OCRv5 English mobile recognition model (if PaddleOCR has published a newer mobile English recogniser by the time you build, benchmark it too and keep the better one). CTC greedy decode with the model's dictionary. Confidence is the mean character probability |
| Bangla recogniser | Decided by benchmark, see below |
| Script router | Per line. Bangla lines have a head line (matra): look for a strong horizontal band in the top third. When unsure, run both recognisers and keep the more confident result |
| Output | For every line: text, four-point box on the page, confidence, script. This feeds highlighting, tap a line and check words |

### Choosing the Bangla recogniser

There is no small, openly licensed Bangla recognition model from PaddleOCR, ML Kit or Apple. The two candidates:

- **A. Tesseract `ben`, one line at a time**: grey crop, page segmentation mode 7, text height scaled to 20 to 30 px. Try both `tessdata_fast` and `tessdata_best`.
- **B. EasyOCR Bengali** (Apache-2.0), exported to 8-bit ONNX on your machine (about 54 MB). Slower.

Rule: run both on the M3 benchmark. Ship the one with the lower Bangla character error, unless it breaks the time or size limit in `03-verification.md`, in which case ship the other. Ship `tessdata_fast` unless `tessdata_best` is more than 2 points better. Record the numbers.

Remove ML Kit only if the Latin recogniser's English error is no worse than ML Kit's on the benchmark. Otherwise keep ML Kit for Latin lines on Android.

### Handwriting

No new model. The same pipeline reads it. A page is treated as partly handwritten when many lines have low confidence and uneven stroke width; the app then shows the handwriting note and sends the user to check words.

### After reading

- Normalise Unicode (NFC) and keep the original text.
- Apply the user's remembered corrections: for a low-confidence word within a small edit distance of a remembered name or place, offer the remembered form as the first alternative.
- Other readings for check words: the recogniser's next-best candidates if available, otherwise near matches from the remembered words and a small Bangla word list.

## Finding details

- Classify the paper from keywords in its text: land record, deed, birth certificate, national ID, licence, bill, receipt, letter, notes. Store the kind; the user can change it.
- For each kind, a small set of rules pulls the key details. Start with land records (khatian number, plot number, mouza, J.L. number, owner, father, area) and receipts (the existing parser, extended for VAT invoices, BIN numbers, bKash, Nagad and Rocket markers, and common supermarket layouts).
- Every detail keeps the line it came from, so the screen can show where it was read.

## English draft

**Engine**: Mozilla's Firefox Translations Bangla to English model (about 17 MB plus vocabulary and shortlist files, MPL-2.0), run by the Bergamot translator. Download the model on your machine from Mozilla's published model collection, verify and record its SHA-256, and bundle it as an asset.

**Integration, in order of preference:**

1. **Hidden WebView running Bergamot's WebAssembly build.** Load the engine and model from app assets. Talk to it over a JavaScript channel. No native build work. Confirm that a WebView loading only local assets works with no network permission.
2. **Native Bergamot through FFI**, built with the NDK. Only if the WebView route fails its gate.

Do not use a runtime under the GPL (for example `slimt`): the repository has no licence yet and GPL code would decide it.

**Around the model** (all testable without it):

1. Split the paper into lines or sentences.
2. Replace names found in the name book with placeholder tokens, translate, then put the English spellings back.
3. Replace known terms according to the user's term choice.
4. Convert numerals, dates and land areas by rule and append the converted value in brackets.
5. Mark every name that was not in the name book as "new name, check the spelling" and add it to the name book as a suggestion.

**Gate and fallback**: see M5. If no integration works, ship "English for key details only" (labels, names, numbers, dates, units by rule) and hide free-text translation. Say so in STATUS and on the landing page.

## Export

| Output | How |
|---|---|
| PDF of the scan | Page images, downscaled and JPEG-compressed |
| Searchable PDF | Add an invisible text layer for Latin text only. The Dart `pdf` package does not shape Bangla, so Bangla text is not placed as text |
| English draft PDF | English is real text. Any Bangla shown (side by side, names) is rendered to an image with Flutter's own text layout, then placed |
| Translator's page | A page with lines for name, signature, date and seal |
| Word (.docx) | Write WordprocessingML directly and zip it. Word shapes Bangla itself, so text stays editable in both languages |
| Size limit | Lower JPEG quality in steps, then resolution, until the file fits. If it cannot fit at readable quality, say so instead of producing an unreadable file |
| Watermark | Diagonal text drawn on each page at low opacity |
| Cover a detail | Burn the black box or blur into the exported page image. Never keep the covered pixels in the file |
| Password | Only with a permissively licensed pure-Dart option you have verified. Otherwise leave the option out and record it |

Exports are written to the app's temporary folder, handed to the save dialog, share sheet or print service, then deleted, as version 1 already does.

## Data

Add a migration to schema version 3. Keep every existing row.

| Table | New or changed | Holds |
|---|---|---|
| `scans` | add `kind`, `language`, `checkCount`, `renewBy` | Kind of paper, words still to check, renewal date |
| `scan_pages` | add `filter`, `quadJson`, `rotation`, `side` | Per-page adjustments; `side` for ID cards |
| `text_lines` | new | Page, order, text, box, confidence, script, corrected flag |
| `details` | new | Scan, key, value, source line |
| `translations` | new | Scan, line, English text, flags, edited flag |
| `names` | new | Bangla, English, person or place, where the spelling came from, confirmed flag |
| `terms` | new | Bangla, transliteration, English, explanation, chosen form |
| `corrections` | new | Wrong reading, right reading, count |
| `bundles`, `bundle_items` | new | Title, purpose, due date; item title, order, expected kind, linked scan |
| Search index | extend | Bangla text, English draft, name book spellings |

Settings to add: purposes, expenses on or off, app lock, backup reminder, term defaults.

## Safety

- **App lock**: `local_auth` for fingerprint, a PIN as fallback. Store only a salted hash of the PIN. Lock on start and after the app has been in the background.
- **Backup file**: `VACUUM INTO` a temporary database copy, zip it with the images, encrypt with a key from the user's password (Argon2id, then AES-256-GCM). The file starts with a short header: format name, version, salt, parameters. Restore checks the version, decrypts to a temporary folder, and swaps the data in one step.
- Android backup stays disabled, as in version 1.

## Size

Build with `--split-per-abi`, without x86 in release, with `--obfuscate --split-debug-info` and `--tree-shake-icons`. Subset the bundled fonts to Bangla, Latin, digits and punctuation.

Budget for the arm64 APK: 90 MB target, 110 MB limit. If the EasyOCR model wins the Bangla benchmark but breaks the limit, ship Tesseract.

## Fonts

Bundle Anek Bangla (interface) and Tiro Bangla (document text), both under the SIL Open Font License, from the Google Fonts repository. Set line heights from `design/tokens.json`; Bangla needs them.

## Third-party notices

Keep a `NOTICE.md` listing every bundled model, font and library with its licence: PaddleOCR models (Apache-2.0), Tesseract data (Apache-2.0), EasyOCR model if used (Apache-2.0), Firefox Translations model and Bergamot (MPL-2.0), OpenCV (Apache-2.0), ONNX Runtime (MIT), fonts (OFL). Verify each licence at its source when you add it.

## Check these yourself before relying on them

- Exact current versions of every package named above.
- That Tesseract's native libraries pass the 16 KB page-size check (see `03-verification.md`).
- Where Mozilla publishes the Bangla to English model files and the WebAssembly build, and their checksums.
- That a WebView with local assets needs no network permission, and that WebAssembly SIMD is available on the emulator's WebView.
- Whether `flutter_tts` or any chosen package pulls in a network permission.
