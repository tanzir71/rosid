# Rosid architecture

Rosid is an offline Flutter application. `AppProfile` is the only platform
branch point; feature code watches the effective expense setting instead of
checking `Platform.isIOS`.

The capture pipeline is:

`camera/gallery → private file store → crop/perspective/deskew → color + binary images → ML Kit Latin → optional Tesseract ben+eng → block merge → normalization/parser → editable review → Drift/FTS5`.

Images and SQLite live under the application documents directory. Exports are
created locally and handed to the operating-system share sheet. There is no
HTTP client, analytics SDK, crash reporter, account, remote model download, or
Android internet permission.

`TfliteBanglaHandwritingEngine` is deliberately registered but disabled in V1;
it is the stable integration seam for the mandatory V2 model work.
