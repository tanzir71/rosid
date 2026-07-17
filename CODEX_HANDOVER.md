# CODEX HANDOVER — "Rosid" (রসিদ) Receipt Scanner

> Agent handover document. Codex: read this file top to bottom before writing any code.
> Work in an autonomous loop as defined in **§12 Build Loop Protocol**. Do not skip milestones.

---

## 1. Product Summary

A **fully offline** mobile app for scanning documents and receipts in **Bangla and English** — printed or handwritten. One codebase, **two platform profiles**:

| | **Android profile** | **iOS profile** |
|---|---|---|
| Primary audience | General Bangladeshi consumers | **Students & business executives** |
| Primary modality | **Receipt scanning + expense tracking** | **Document scanning** (notes, whiteboards, handouts, contracts, business cards as generic docs) |
| Receipt features | Front and center (dashboard, categories, export) | **Optional** — hidden behind a Settings toggle ("Enable expense tracking"); off by default. When off: no expense dashboard, no receipt mode toggle, no categories/export UI. |
| Home screen | Expense dashboard | Recent documents grid + search + scan FAB |

Both profiles share capture, preprocessing, OCR, search, and storage. The difference is UI composition and defaults — implemented as a single `AppProfile` config (see §4.1), **not** a fork.

**No network calls. Ever.** No analytics SDKs, no crash reporters, no cloud OCR, no remote model downloads at runtime. Everything (models, language data) ships in the app bundle or app-local storage.

## 2. Hard Constraints

| Constraint | Rule |
|---|---|
| Connectivity | App must work in airplane mode from first launch. CI check: no `INTERNET` permission in the Android release manifest. |
| Stack | Flutter (latest stable), Dart 3.x |
| Platform | **Android first** (minSdk 26, target latest), then **iOS** (iOS 15+) as a distinct profile pass (M9). All plugins must have iOS support or sit behind an abstraction. |
| Distribution | **Outside app stores.** Android: signed APK downloaded from a GitHub Pages landing page (sideload). iOS: TestFlight link from the same landing page (see §14 for why true iOS sideloading is not viable). GitHub Releases hosts the binaries. |
| Languages | UI in English + Bangla (l10n via `flutter_localizations` + ARB files). OCR for `en` + `bn`. |
| Storage | All data in app-private storage. SQLite via `drift`. Images in app documents dir. |
| Privacy | No permissions beyond CAMERA and (optional) READ_MEDIA_IMAGES for gallery import. |

## 3. Tech Stack & Key Packages

| Concern | Package | Notes |
|---|---|---|
| Camera | `camera` | Live preview + capture. Consider `camerawesome` only if `camera` proves insufficient. |
| English/Latin OCR | `google_mlkit_text_recognition` | On-device, bundled Latin model. Verify it runs offline (it does when using the bundled model). |
| Bangla OCR | `flutter_tesseract_ocr` (Tesseract 5) | Ship `ben.traineddata` + `eng.traineddata` (tessdata_best) in assets, copy to app dir on first launch. |
| Script detection | Custom: Unicode-range heuristic on ML Kit output + block-level classifier (see §6) | |
| Image preprocessing | `opencv_dart` (or `image` package fallback) | Deskew, crop, adaptive threshold. |
| DB | `drift` | Type-safe SQLite, testable on desktop VM. |
| State mgmt | `riverpod` (hooks optional) | |
| Routing | `go_router` | |
| Export | `csv` + `share_plus` | Local file share sheet only — not a network call. |
| Testing | `flutter_test`, `integration_test`, `mocktail` | |

If a package is discontinued/broken at build time, choose the nearest maintained equivalent, note it in `PROGRESS.md`, and continue.

## 4. App Modalities

Two scan modes, chosen at capture time (toggle on the capture screen):

1. **Receipt mode (default)** — full pipeline: preprocess → OCR → parse → editable structured record → save as expense.
2. **Document mode** — preprocess → OCR → save as a searchable document (title + full text + image). No parsing. Used for handwritten notes, letters, forms, prescriptions, etc.

Both share the capture, preprocessing, and OCR layers. Only the post-OCR path differs.

### 4.1 Platform profiles (`AppProfile`)

```dart
class AppProfile {
  final bool expenseTrackingDefault;   // Android: true, iOS: false
  final bool expenseTrackingLocked;    // false on both — user can toggle in Settings
  final ScanMode defaultScanMode;      // Android: receipt, iOS: document
  final HomeLayout homeLayout;         // Android: dashboard, iOS: documentsGrid
}
```

- Resolved once at startup from `Platform.isIOS` (overridable via `--dart-define=APP_PROFILE=` for testing both profiles on one device/emulator).
- Every receipt-only widget/route checks a single `expenseTrackingEnabled` provider (profile default ⊕ user setting). No `Platform.isIOS` checks scattered in feature code — **profile is the only branch point**.
- When expense tracking is enabled on iOS, the receipt experience is identical to Android's.
- iOS profile extras for the student/executive audience: quick multi-page document capture (batch scan → one document), share/export document as PDF (local render, share sheet), pinned documents on home.

## 5. Screens

1. **Home** — profile-dependent. *Dashboard layout (Android / expense-on):* this month's total, spend by category (simple bar/pie), recent receipts, FAB → scan. *Documents layout (iOS default):* recent documents grid, pinned docs, search bar, FAB → scan.
2. **Capture** — live camera with document-edge overlay, mode toggle (Receipt/Document — hidden when expense tracking is off), flash, gallery import, multi-page batch capture (document mode).
3. **Crop & Enhance** — auto-detected quad with draggable corners, rotate, enhancement preview (original vs processed).
4. **Review (Receipt)** — parsed fields (merchant, date, total, tax, payment method, category, line items) side-by-side with the image; every field tap-to-edit; low-confidence fields visually flagged (amber). Raw OCR text viewable in an expandable panel.
5. **Review (Document)** — title (auto-suggested from first line), editable full text, tags.
6. **History** — combined list, filter by type/category/date range, full-text search (searches OCR text too).
7. **Detail** — record + original image, edit, delete, share image.
8. **Export** — CSV of expenses for a date range via system share sheet.
9. **Settings** — UI language (en/bn), **expense tracking on/off**, default currency (৳ default), category management, delete-all-data.

## 6. OCR Pipeline (the core of this app)

```
image → preprocess → script detect → route to engine(s) → merge → normalize → (receipt mode: parse) → user review
```

### 6.1 Preprocessing (before any OCR)
- Document edge detection → perspective correction (quad warp).
- Deskew (text-line angle estimate).
- Grayscale → contrast normalization (CLAHE) → adaptive threshold (binarize). Keep both the color-corrected and binarized versions; Tesseract gets binarized, ML Kit gets color-corrected (ML Kit performs worse on binarized images).
- Upscale if min dimension < 1000px.

### 6.2 Engine routing
- Run **ML Kit (Latin)** first — it is fast and handles English printed + reasonable English handwriting.
- Classify recognized blocks: compute the fraction of characters in the Bangla Unicode range (U+0980–U+09FF) vs Latin. ML Kit will output garbage for Bangla; detect this via low confidence / high non-word ratio.
- If the image likely contains Bangla (garbage Latin output, or user's language hint, or explicit "Bangla" toggle on capture screen), run **Tesseract with `ben+eng`** on the binarized image.
- **Merge strategy**: prefer ML Kit for Latin-dominant blocks, Tesseract for Bangla-dominant blocks, using block bounding boxes to avoid duplication. When in doubt, keep both and let the parser/user decide.

### 6.3 Normalization (critical for Bangla receipts)
- Map Bangla numerals ০১২৩৪৫৬৭৮৯ → 0–9 for all numeric parsing (keep the original string for display).
- Normalize currency tokens: `৳`, `Tk`, `TK.`, `Taka`, `BDT`, `টাকা` → BDT.
- Normalize Bangla dates: Bangla month names (জানুয়ারি … ডিসেম্বর) and numerals in dates.
- Unicode NFC normalization on all Bangla text (conjunct/matra ordering varies by engine).

### 6.4 Handwriting — honest expectations
- English handwriting: ML Kit Latin does a passable job on neat print-style writing. Accept it.
- **Bangla handwriting: no production-grade fully-offline solution exists.** Tesseract `ben` is trained on printed text and will be poor on handwriting. Strategy:
  1. Run the pipeline anyway (best-effort).
  2. Surface confidence honestly: if mean confidence < threshold, show a banner: "Handwriting detected — please verify the text" and drop straight into the editable review screen.
  3. **Architecture requirement**: OCR engines sit behind a single interface so a TFLite handwriting model can be added later without touching callers:

```dart
abstract class OcrEngine {
  String get id;
  Set<ScriptHint> get supportedScripts;
  Future<OcrResult> recognize(PreprocessedImage image, {ScriptHint? hint});
}
// OcrResult = List<OcrBlock>(text, boundingBox, confidence, script)
```

  4. Create a stub `TfliteBanglaHandwritingEngine implements OcrEngine` that throws `UnimplementedError`, registered but disabled — the seam must exist and compile. **This stub becomes real in Version 2 — see §17, which is mandatory, not aspirational.**
- The **user correction UI is a first-class feature**, not a fallback. Every OCR result is editable before save.

### 6.5 Receipt parser (heuristics, post-normalization)
- **Total**: search bottom-up for keywords (`total`, `grand total`, `net`, `মোট`, `সর্বমোট`, `টোটাল`) with a money amount on the same/adjacent line; fallback = largest plausible amount. Validate against sum of line items when available.
- **Date**: regex for `dd/mm/yyyy`, `dd-mm-yy`, `yyyy-mm-dd`, `dd MMM yyyy`, Bangla-numeral variants; fallback = scan timestamp (flag as inferred).
- **Merchant**: top 1–3 lines, excluding phone/address-pattern lines; largest-font block wins if geometry is available.
- **Line items**: lines matching `name … qty? … amount` column structure; tolerate failure — items are optional, total is not.
- Every parsed field carries `(value, rawText, confidence, source)`. The parser must be a pure Dart function — **unit-testable with no device or Flutter dependency**.

## 7. Data Model (drift)

```
scans:      id, type(receipt|document), imagePath, thumbPath, ocrRawText,
            ocrEngine, ocrMeanConfidence, langHint, createdAt, updatedAt
receipts:   id, scanId(fk), merchant, dateOfPurchase, total, currency(default BDT),
            tax?, paymentMethod?, categoryId(fk), note?, fieldConfidenceJson
line_items: id, receiptId(fk), name, qty, unitPrice?, amount
documents:  id, scanId(fk), title, body(editable text), pinned(bool)
categories: id, nameEn, nameBn, icon, isDefault  // seed: Groceries/মুদি, Food/খাবার,
            Transport/যাতায়াত, Utilities/ইউটিলিটি, Health/স্বাস্থ্য, Shopping/কেনাকাটা, Other/অন্যান্য
tags:       id, name;  scan_tags: scanId, tagId
```
FTS5 virtual table over `ocrRawText`, `merchant`, `title`, `body` for search.

## 8. Project Structure

```
lib/
  core/            # theme, l10n, utils (bangla_numerals.dart, money.dart, dates.dart)
  data/            # drift db, tables, daos, repositories
  ocr/             # engines/ (mlkit_latin.dart, tesseract_bn.dart, tflite_bn_stub.dart),
                   # preprocess/, script_detect.dart, merge.dart, ocr_service.dart
  parsing/         # receipt_parser.dart (pure Dart), normalizers/
  features/        # capture/, review/, history/, dashboard/, documents/, export/, settings/
  app.dart, main.dart
test/              # mirrors lib/; fixtures/ (see §10)
```

## 9. Milestones (do them in order)

Each milestone ends with: `flutter analyze` clean, all tests green, app builds (`flutter build apk --debug`), commit, update `PROGRESS.md`.

- **M0 — Scaffold**: Flutter project, packages, drift schema + migrations, riverpod + go_router shell, l10n (en/bn ARBs), theme. Empty screens navigable. CI-style check script `tool/check.sh` (analyze + test + build).
- **M1 — Capture**: camera preview, capture, gallery import, mode toggle, save raw image to app dir, `scans` row created.
- **M2 — Preprocess**: edge detect + crop UI with draggable corners, deskew, enhance. Unit tests on fixture images (run preprocessing as pure functions where possible).
- **M3 — OCR core**: `OcrEngine` interface, ML Kit engine, Tesseract engine (assets shipped + first-launch copy verified), script detection, merge. Integration-tested on device/emulator against fixtures.
- **M4 — Normalization + Parser**: Bangla numeral/date/currency normalizers + receipt parser. **≥ 40 unit tests** against the fixture corpus (§10). This milestone is pure Dart — no device needed.
- **M5 — Review & Save**: both review screens, confidence flagging, editable everything, save to DB.
- **M6 — History, Search, Detail**: FTS5 search, filters, detail view, edit/delete.
- **M7 — Dashboard + Export + Settings**: monthly summary, category chart, CSV export via share sheet, settings (incl. Bangla UI verified).
- **M8 — Android hardening**: airplane-mode manual test script, manifest permission audit, large-image memory handling, DB migration test, ProGuard/R8 rules for ML Kit + Tesseract, signed release APK builds.
- **M9 — iOS profile**: `AppProfile` wiring (should already exist from M0; here it's verified end-to-end), documents-first home layout, expense toggle behavior, multi-page batch capture, document→PDF export, iOS build config (Podfile, Info.plist permissions with usage strings, Tesseract/ML Kit iOS pods), verify both OCR engines on iOS simulator + document behaviors via `--dart-define=APP_PROFILE=ios` on Android emulator if no macOS runner is available (record this limitation in `PROGRESS.md`).
- **M10 — Landing page + distribution** (see §15): GitHub Pages site, GitHub Releases pipeline for the signed APK, TestFlight link slot, install instructions.

## 10. Test Fixtures (create these in M0/M4)

`test/fixtures/receipts/` — plain-text files simulating OCR output (name = expectation encoded in a sibling `.json`):
- English printed supermarket receipt (line items + VAT + total)
- Bangla printed receipt (৳, Bangla numerals, `মোট`)
- Mixed Bangla/English (common in Dhaka: English items, Bangla header/total)
- Handwritten-style noisy text (misrecognized chars, broken lines)
- Edge cases: no date, multiple "total"-like lines, discount lines, Bangla month-name date

Parser accuracy gate for M4: correct **total** on ≥ 90% of printed fixtures, correct **date** on ≥ 80%. Log failures in `PROGRESS.md` rather than silently lowering the bar.

## 11. Non-Goals (V1)

No cloud sync, no accounts/auth, no multi-device, no currency conversion, no App Store / Play Store submission work, no in-app self-update mechanism (would require network — updates are manual downloads from the landing page), no tablet layout polish. **OCR model training is a V1 non-goal only — it is the entire point of V2 (§17).**

## 12. Build Loop Protocol (Codex operating instructions)

Maintain two files at repo root: `PROGRESS.md` (running log) and `TASKS.md` (checklist derived from §9, broken into ~1–2 hour tasks).

Loop:
1. Read `PROGRESS.md` + `TASKS.md`. Pick the **first unchecked task** of the lowest incomplete milestone.
2. Implement it. Small, focused changes.
3. Run `tool/check.sh` (analyze → test → debug build). Fix until green. Never proceed on red.
4. Commit: `M<n>: <task summary>`. Check the box in `TASKS.md`. Append to `PROGRESS.md`: what was done, decisions made, deviations from this doc, known issues.
5. If blocked > 3 attempts on the same failure: mark the task `[BLOCKED: reason]` in `TASKS.md`, log it, move to the next task that doesn't depend on it.
6. Repeat until all milestones complete, then do a final full pass of §13. **When §13 is fully green, do not stop: generate `TASKS_V2.md` from §17 and continue into the V2 guided loop.**

Note: if no macOS runner is available, M9's iOS-specific build steps get marked `[BLOCKED: no macOS runner]` — but all profile logic, layouts, and tests still run via the `--dart-define` profile override, so M9 is mostly completable anywhere.

Rules:
- This document is the spec. If reality contradicts it (broken package, API change), adapt, but **record every deviation** in `PROGRESS.md` under a `## Deviations` heading.
- Never add a network dependency, even "temporarily".
- Prefer pure-Dart, unit-testable code; device-dependent code stays thin.
- No TODOs without a matching entry in `TASKS.md`.

## 13. Definition of Done

- All M0–M10 boxes checked (or explicitly `[BLOCKED]` with rationale).
- `flutter analyze` clean; full test suite green; signed release APK builds; iOS target compiles (or `[BLOCKED: no macOS runner]` logged).
- Manual script passes: airplane mode ON → scan English printed receipt → correct total/date → save → search finds it → export CSV. Repeat with a Bangla printed receipt. Scan a handwritten note in Document mode → edit text → save → searchable.
- iOS-profile manual script (simulator or profile-override on Android): home shows documents grid, no expense UI anywhere; enable expense tracking in Settings → full receipt flow appears and works; multi-page doc → single PDF via share sheet.
- No `INTERNET` permission in the Android release manifest.
- Landing page live on GitHub Pages, serving the latest signed APK from GitHub Releases, with install instructions and a TestFlight placeholder.
- `PROGRESS.md` tells the complete story of the build, including deviations and known limitations (especially Bangla handwriting accuracy).

## 14. Distribution Plan (no app stores)

### Android — direct APK (fully in our control)
- Signed release APK (own keystore; document SHA-256 of the signing cert on the landing page so users can verify).
- Publish via **GitHub Releases**; the landing page always links `releases/latest`. Version name + changelog per release.
- Landing page carries sideload instructions ("allow installs from browser" flow) in English and Bangla.
- No in-app updater (offline constraint). The landing page is the update channel; the app's About screen shows the version and tells users where to check for updates.

### iOS — be honest about the constraint
True sideloading outside the App Store is **not generally possible on iOS**. Options, in order of practicality:

| Route | Reach | Notes |
|---|---|---|
| **TestFlight** (recommended) | Up to 10,000 external testers via public link | Builds expire after 90 days → needs periodic re-upload. Requires paid Apple Developer account. Landing page links the public TestFlight URL. |
| Unlisted App Store link | Unlimited, hidden from search | Still App Store review; use later if TestFlight churn becomes painful. |
| Ad Hoc OTA (`itms-services`) | 100 registered devices/year | Only for the developer's own devices/close circle. |
| EU Web Distribution | EU only | Irrelevant for a Bangladesh/global audience. |

**Plan**: ship via TestFlight public link on the landing page. Codex prepares the Xcode project so `flutter build ipa` works, but actual upload/signing is a human step — leave a `docs/RELEASING.md` with the exact commands and a checklist.

## 15. Landing Page (GitHub Pages) — M10

- **Stack**: static HTML/CSS/vanilla JS in `site/` at repo root, deployed by a GitHub Actions workflow to Pages. No frameworks, no build step beyond copying files. No trackers/analytics (brand consistency with the app's privacy stance).
- **Content**: hero (app name + one-liner in EN/BN with a language toggle), 3–5 device screenshots (generate from emulator during M10), feature grid *per audience* — receipts/expenses pitched to Android users, notes/documents pitched to iOS users — download section (big "Download APK" button → latest release; "Join on TestFlight" button → placeholder until link exists), sideload instructions (collapsible, EN/BN), privacy statement ("100% offline — your documents never leave your phone"), APK signature fingerprint, changelog link, GitHub repo link.
- **CI**: one workflow builds the signed APK on tag push → creates a GitHub Release → deploys `site/` to Pages. Secrets (keystore) documented in `docs/RELEASING.md`, injected via repo secrets.
- Acceptance: Lighthouse accessibility ≥ 90, page loads with JS disabled, works on mobile (that's where sideloaders will be).

## 16. Competitor Research (July 2026) — and what it means for this app

### Direct/adjacent competitors

| App | Positioning | Offline? | Bangla? | Takeaway for us |
|---|---|---|---|---|
| **Expensify** | Team expense reports, SmartScan OCR | No — cloud OCR (offline capture queues for later upload) | No | Receipt OCR is table stakes; their moat is cloud workflows we don't want. |
| **Smart Receipts** | Open-source, offline-first personal receipt log for individuals/sole proprietors | **Yes** | No | Closest philosophical competitor. Weak OCR and dated UX — our OCR pipeline + Bangla support is the differentiator. |
| **Zoho Expense / Wave** | SMB expense mgmt, free tiers (Zoho: 20 scans/mo free) | No | No | Scan-quota business models push privacy-minded users toward truly-local apps. |
| **CamScanner / iScanner** | General document scanning, heavy on subscriptions/upsell | Partially | No | Dominant in the student market but ad/subscription-laden and cloud-tied; privacy is our wedge for the iOS student/exec profile. |
| **SwiftScan, Genius Scan, Adobe Scan, Notebloc** | Document scanners; SwiftScan/Genius Scan emphasize local processing; Notebloc targets students (notebook background cleanup) | Mostly | No | Set the UX bar for capture/crop/enhance. Microsoft Lens (the former free default, popular with students) was **discontinued in 2026** — a real gap we can occupy. |
| **Bangla Scan / Image to Text OCR Bangla / Chitrolekha** | Bangla OCR utilities (image → text), some offline | Some | **Yes (printed)** | Prove demand for offline Bangla OCR, but they're raw text extractors — no receipt parsing, no expense tracking, no document management, weak UX. |

### Gaps we exploit
1. **No app combines Bangla OCR + receipt parsing + expense tracking, offline.** Bangla OCR apps stop at raw text; expense apps have no Bangla and require cloud.
2. **Microsoft Lens's retirement** left students/executives without the obvious free, clean scanner — the iOS profile's exact target.
3. **Privacy as a feature**: competitors either upload documents (Expensify, CamScanner) or meter scans (Zoho). "Never leaves your phone, no account, no quota" is a clear, marketable line for both audiences.
4. **Handwriting honesty**: nobody does offline Bangla handwriting well; our edit-first review UX turns an industry-wide weakness into a usable workflow instead of a false promise.

### What to copy shamelessly
- Genius Scan/SwiftScan's capture UX: auto edge detection, batch scanning, instant enhancement preview.
- Smart Receipts' export pragmatism: CSV that accountants can actually use.
- Notebloc's notebook-background cleanup (a preprocessing preset worth adding for the student profile in a later iteration).

## 17. VERSION 2 — TFLite Bangla Handwriting Model (MANDATORY)

**Gate**: V2 starts only after every item in §13 is done. Then this section becomes the active spec and Codex re-enters the build loop (§12) with a new `TASKS_V2.md`.

**Goal**: replace best-effort Tesseract handwriting with a real on-device handwritten-text-recognition (HTR) model behind the existing `TfliteBanglaHandwritingEngine` seam. Ship it in a V2 release of both profiles.

### 17.1 Operating mode — Codex guides the human

Model training cannot happen inside the app build loop: it needs dataset downloads (license agreements), a GPU (Colab/Kaggle/local), and judgment calls. So V2 runs as a **guided loop**:

1. Codex maintains `ml/V2_GUIDE.md` — a living, numbered checklist written *for Tanzir*, one step at a time: exact URLs, exact commands, what artifact to produce, and where to put it.
2. Codex writes and commits all code (training scripts, notebooks, conversion, evaluation) **before** asking Tanzir to run anything. Every human step is: "run this, put the output file here."
3. When Tanzir drops an artifact into the repo (dataset sample, checkpoint, `.tflite` file, eval results), Codex verifies it (shape checks, checksum, smoke-test inference) and advances the guide.
4. Codex never blocks silently — if waiting on a human step, it works on any V2 task that doesn't depend on it (integration code, eval harness, fixtures) and marks the guide step `[WAITING ON TANZIR]`.

### 17.2 Phases

**P0 — Design decisions (Codex proposes, Tanzir approves, recorded in `ml/DECISIONS.md`)**
- Architecture: default proposal = **line-level CRNN + CTC** (CNN backbone ≤ ~5M params), grapheme-aware charset (Bangla graphemes, not raw codepoints — conjuncts matter). Transformer decoders (TrOCR-style, or the grapheme-based decoder-only approach in GraDeT-HTR) are the fallback if CRNN plateaus, but size/latency budgets rule.
- Scope: Bangla handwriting first; English handwriting stays on ML Kit.
- Budgets (hard): model ≤ 20 MB post-quantization, ≤ 1.5 s per receipt line-batch on a 2022 mid-range Android phone, works offline obviously.

**P1 — Data assembly (NO manual data collection — Tanzir photographs and annotates nothing)**
- **Synthetic generation is the primary data source.** Codex builds `ml/datagen/`, a fully automated pipeline: receipt-domain text sampler (Bangla numerals, ৳, মোট/সর্বমোট, dates, item vocabulary, mixed Bangla/English lines) → synthesis tiers below → composited onto paper textures → degradation stack (ink bleed, blur, low-light noise, crumple/warp, shadows, thermal-paper fade) → passed through the app's own preprocessing (§6.1) so training matches inference. Target: ≥ 500k synthetic lines, config-driven and regenerable.

  **P1a — Known failure points of synthetic Bangla handwriting, and how the generator must counter each.** Naive font rendering fails because real Bangla handwriting diverges from fonts in specific, documented ways. The generator is not accepted until it covers this table:

  | # | Real-handwriting failure point | Why fonts get it wrong | Generator requirement |
  |---|---|---|---|
  | 1 | **Matra (headline) irregularity** — broken, wavy, partially missing, or drawn as one continuous stroke fusing a whole word; matra errors are a top documented cause of Bangla OCR segmentation failure | Fonts draw a perfect straight connected matra | Post-render stroke surgery: randomly break/thin/waver/omit the matra region; randomly extend one matra across word fragments |
  | 2 | **Conjuncts (যুক্তবর্ণ)** — writers use simplified, idiosyncratic, or decomposed forms unlike the printed ligature | Fonts render the canonical ligature only | Conjunct variant bank: per-conjunct alternatives (canonical, decomposed with hasanta, common simplified shapes); sample frequency-weighted, oversample rare graphemes to fight the documented class imbalance |
  | 3 | **Visually confusable pairs** — ই/ঈ, ব/র, ড/ড়, য/য়, ণ/ন, ছ/ঝ, ু/ূ; numerals ১/৯, ৪/৮, ০/৩-loop styles | Fonts keep pairs cleanly distinct | Targeted hard-negative synthesis: deform members of each confusion pair *toward* each other at controlled intensity so the model learns the discriminative sub-strokes; confusion pairs get their own eval slice |
  | 4 | **Vowel-sign (kar) placement drift** — ি/ে drawn far left of the consonant, ো split around it, ু/ূ/্র drifting below-right, upper-zone marks (ঁ, ref) colliding with the line above | Fonts place diacritics at fixed metrics | Randomized diacritic offset/scale/rotation per instance, including overlaps into adjacent zones and inter-line collisions in multi-line renders |
  | 5 | **Touching/overlapping characters and zone spanning** — descenders/ascenders invade neighbors; over/under-segmentation is a primary documented OCR error | Fonts never collide glyphs | Negative letter-spacing with glyph-overlap compositing; render **line-level** images (not isolated words) so the model trains on realistic crowding — matches our line-level CRNN, avoids segmentation altogether |
  | 6 | **Stroke dynamics** — variable ink width within a stroke, pen lifts, ballpoint skips, gel-pen blobs, pencil texture | Fonts have uniform outlines | Vector-level rendering (FreeType outlines → stroke re-synthesis) with pressure-profile simulation, per-writer pen model sampled per page |
  | 7 | **Writer-level consistency** — a real page has *one* style (slant, size, spacing rhythm); per-glyph random jitter produces an "impossible writer" | Random augmentation is i.i.d. per glyph | Hierarchical sampling: writer → page → line → glyph. Writer-level latent controls slant/size/spacing/pen; glyph noise is small residual on top |
  | 8 | **Style diversity ceiling** — only a handful of Bangla handwriting-style fonts exist; a model overfits to those few skeletons | Font bank is tiny | **Tier-3 generative synthesis (below)** + glyph-skeleton morphing (extract skeletons, apply thin-plate-spline deformations to invent new "writers") |
  | 9 | **Baseline/layout drift** — lines curve upward, inter-word gaps erratic, numbers squeezed into column ends on receipts | Fonts render straight metrics | Per-line baseline splines, non-uniform word gaps, receipt-layout templates (item-name left, amount right, cramped totals row) |
  | 10 | **Code-switching & numeral mixing** — Bangla words with embedded English brand names, Latin digits mixed with Bangla numerals in the same amount | Single-script rendering | Text sampler emits mixed-script lines with per-token script switching; both numeral systems in amounts |

  **Synthesis tiers** (all three required; ratios tuned empirically):
  - **Tier 1 — font render + degradation**: fast bulk volume; covers layout/photometric variation. Weakest realism; capped at ~40% of the mix.
  - **Tier 2 — stroke-level procedural synthesis**: the P1a table above (stroke surgery, skeleton morphing, writer hierarchy). This is the core of the generator.
  - **Tier 3 — learned generative synthesis**: train a style-conditioned handwriting generator (ScrabbleGAN-style GAN or glyph-conditional diffusion — both have published evidence of improving HTR when used as training data) **on the public datasets** (BN-HTRd, BanglaWriting). It then produces unlimited new lines of arbitrary receipt text in real human stroke styles. This is the main weapon against the font-diversity ceiling (#8), and stays within the no-manual-collection constraint.

  **Realism gate (before any HTR training)**: train a small real-vs-synthetic discriminator on line crops — if it separates them too easily (AUC > 0.85), the generator needs work; log per-tier AUC. Additionally: a model trained on synthetic-only must be evaluated on real public-dataset lines every iteration — the synthetic→real CER gap is *the* generator quality metric and must trend down across generator versions.
- **Public datasets, download-only (zero manual effort):** BN-HTRd (~788 pages, ~150 writers), BanglaWriting, and character-level sets (Ekush, BanglaLekha-Isolated) for pretraining. These require nothing from Tanzir beyond clicking a download link Codex provides; license terms logged in `ml/DECISIONS.md`.
- **Held-out test set = writer-disjoint split of the public datasets** (writers never seen in training) plus a frozen synthetic set. Real handwriting evaluation cannot come from synthetic data alone — this is the only honest way to measure generalization without collecting our own corpus.
- ⚠️ **Recorded risk**: if public datasets are also excluded and the model is trained *and* evaluated purely on synthetic data, reported accuracy will be inflated and real-world handwriting performance is unknown. Codex must state this in `PROGRESS.md` and the landing-page changelog rather than hide it.

**P2 — Training (Codex writes, Tanzir runs on GPU)**
- `ml/` Python project: reproducible (pinned deps, seed, config file), dataset loaders, line-segmentation using app-style preprocessing, CRNN+CTC training with curriculum: synthetic → public datasets → fine-tune on receipt-domain data.
- Codex prepares a single Colab/Kaggle-ready notebook per training run; Tanzir runs it and commits back `checkpoints/` metrics + best weights.
- Tracked metrics: CER/WER on each dataset + the writer-disjoint held-out set.
- Training curriculum: synthetic (bulk) → public real handwriting (generalization) → fine-tune on receipt-flavored synthetic.

**P3 — Conversion + on-device validation**
- Export → TFLite with post-training quantization (try float16 first, int8 if size demands; compare CER deltas).
- `ml/export/validate_tflite.py`: bit-for-bit comparison of TFLite vs trained-model outputs on 100 samples; latency benchmark script Tanzir runs on a real device via a tiny Flutter bench harness Codex builds.

**P4 — App integration (pure Codex, normal build loop)**
- Implement `TfliteBanglaHandwritingEngine` (via `tflite_flutter`): line detection → per-line inference → CTC decode (greedy + optional small beam) → `OcrResult` with real confidences.
- Routing upgrade in §6.2: a lightweight printed-vs-handwritten classifier (can be heuristic first: Tesseract confidence collapse + stroke-width variance) decides when the HTR engine runs.
- Model ships in assets; app size check added to `tool/check.sh`.

**P5 — Acceptance + release**
- Gates (measured on the writer-disjoint public-dataset held-out set): **CER ≤ 25% on Bangla handwriting** AND **at least 30% relative CER improvement over Tesseract-ben on the same set**. Amounts-only CER (digits + ৳) ≤ 12%, since totals matter most. If gates fail: log in `PROGRESS.md`, iterate P1–P3 (more/better synthetic data first, architecture second).
- Regression: printed-receipt fixtures from §10 must not get worse.
- Release V2 via the M10 pipeline; landing page gains a "reads handwritten Bangla" section + changelog; TestFlight re-upload step in `docs/RELEASING.md`.

### 17.3 V2 Definition of Done
- `TfliteBanglaHandwritingEngine` live and routed automatically; stub deleted.
- All P5 gates met and recorded with numbers in `PROGRESS.md`.
- `ml/` repo reproducible end-to-end from `V2_GUIDE.md` by a stranger.
- V2 APK on the landing page; app still passes the full V1 §13 manual script.
