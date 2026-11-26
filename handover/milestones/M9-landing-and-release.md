# M9: Landing page and release

Goal: Rosid 2.0.0 is built, checked, signed, published on GitHub Releases, and downloadable from the live landing page in both languages.

Read first: `04-repo-and-release.md`, `05-landing-page.md`, `03-verification.md` (Release level).

## Steps

1. **Freeze**: no new features. Fix only what the release gates find.
2. **Full run**: `tool/verify -Release -Evidence M9` on the final commit. All end-to-end flows, all gates. Random-input test on the release build.
3. **App screenshots** for the site: from the integration test run, in English and Bangla, for the four steps.
4. **Landing page** in `docs/` per `05-landing-page.md`: both languages, self-hosted fonts, paper pair in HTML, paper SVGs, release slip, install steps, closing band, footer, 404 page, Open Graph images.
5. **Site checks** from `05-landing-page.md`. Screenshots at 390 and 1440 wide in `evidence/M9/site/` next to the design pictures.
6. **Signing**: follow `04-repo-and-release.md`. Record the certificate fingerprint.
7. **Build** split APKs, rename, checksums, symbols zip.
8. **Release notes** in both languages in `evidence/M9/release-notes.md`.
9. **Publish** as a draft, download, compare checksums, publish.
10. **Release values** into the site with the prepare script; commit; push; confirm the live page shows the version, the checksum, and a download link that returns the file (`curl -sIL` on the link shows 200 and the right size).
11. **Clean up**: remove `site/` and the old prepare script if replaced; remove ML Kit and Tesseract leftovers if unused; make sure README points to the landing page and the handover.
12. **Final STATUS**: every milestone's state, all measured numbers, decisions, "Not done, needs a person", "Not verified by machine". This is the owner's summary; write it so it can be read in two minutes.

## Done when (Release)

- [ ] All Release-level gates pass on the published APK files (not just a local build).
- [ ] `https://tanzir71.github.io/rosid/` (বাংলা) and `/en/` are live, show 2.0.0, and the download works.
- [ ] Release v2.0.0 is published with both APKs, `SHA256SUMS.txt`, symbols, and notes in both languages.
- [ ] No GitHub Actions ran for any of this (check `gh run list` is empty or Actions are disabled).
- [ ] STATUS final and pushed.

## Fallbacks

- No sign-in for `gh`: everything is committed and pushed if `git push` works; the release is not published; the landing page keeps pointing to version 1 with the "Version 2 is on its way" line. Record it.
- A Release gate fails and cannot be fixed: do not publish. Record the gate, the measured value and what was tried.
