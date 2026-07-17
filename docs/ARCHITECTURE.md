# Rosid architecture

Rosid is an offline Flutter application. `AppProfile` is the only platform
branch point; feature code watches the effective expense setting instead of
checking `Platform.isIOS`.

The capture pipeline is:

`camera/gallery → private file store → crop/perspective/deskew → color + binary images → ML Kit Latin → optional Tesseract ben+eng → block merge → normalization/parser → editable review → Drift/FTS5`.

Images and SQLite live under the application documents directory. Exports are
created with unique names under the app-private temporary directory, handed to
the operating-system share sheet, and deleted after completion. Startup,
record deletion, and delete-all also sweep stale exports and share-cache copies.
There is no
HTTP client, analytics SDK, crash reporter, account, remote model download, or
Android internet permission.

The English and Bangla Tesseract models are pinned, checked-in application
assets. On first use, the installer copies them atomically into app-private
storage and verifies their expected lengths. CI verifies the checked-in files'
SHA-256 values; neither the build nor the application downloads language data.

Three real PNG fixtures (English receipt, mixed Bangla receipt, and handwritten
note) feed a generated-byte native integration harness. Its Android-emulator
airplane-mode run covers the ML Kit-only path, the mixed ML Kit + Tesseract path,
and the editable handwriting review path; all three fixtures passed. This is a
native OCR subset, not a substitute for the remaining physical-device camera,
memory, export, and share-sheet checklist.

Android Tesseract output uses hOCR for real block geometry and confidence. The
upstream plugin does not expose its hOCR method on iOS, so the iOS adapter uses
the plain-text channel, derives one full-width box per line, and assigns a
conservative 0.4 confidence. That keeps the iOS path functional and visibly
reviewable without inventing native certainty.

Document PDF export is capped at 20 pages. Source files are loaded and
downscaled one at a time on a worker isolate to a maximum 1600-pixel edge,
then embedded as bounded JPEGs. The export never retains every full-resolution
source image in memory at once.

The About screen reads the installed version and build number from platform
package metadata. Its releases link is a static GitHub URL; displaying either
value does not make a network request.

Android cloud backup and device-transfer extraction are disabled for every app
data domain. This keeps scans, OCR text, settings, and the database out of the
platform backup transport as well as out of Rosid's own network surface.

Raw scans, processed pages, and thumbnails share one lifecycle: discard,
record deletion, and delete-all remove the associated app-private artifacts.
Temporary CSV/PDF exports are scoped against path traversal and cleaned after
sharing or on the next lifecycle sweep. History/detail caches are
invalidated after mutations so deleted or edited records are not reused.

`TfliteBanglaHandwritingEngine` is deliberately registered but disabled in V1;
it is the stable integration seam for the mandatory V2 model work.
