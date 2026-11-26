# Landing-page research

Research date: 2026-07-18

This note records the competitive patterns used for Rosid's direct-download
website. It focuses on live product and distribution pages, not screenshots or
second-hand design roundups.

## Patterns reviewed

| Product | Useful pattern | Rosid decision |
|---|---|---|
| [Signal direct APK](https://signal.org/android/apk/) | Treats an APK as a security-sensitive download and publishes the signing-certificate fingerprint. | Put the APK hash, certificate hash, release notes, and safe-install steps beside the download. |
| [NewPipe](https://newpipe.net/) | Keeps version, Android requirement, release information, and alternate update routes close together. | Use a single release card instead of scattering metadata across the page. |
| [Organic Maps](https://organicmaps.app/) | Leads with a plain category promise and concrete negatives: no ads, tracking, registration, or data collection. | Lead with the receipt outcome, then support it with “No account · No cloud · No ads · No scan limits.” |
| [LocalSend](https://localsend.org/) | Presents open-source, offline behavior as a normal product benefit rather than a technical footnote. | Keep the page approachable while making source and release provenance visible. |
| [Genius Scan](https://help.geniusscan.com/) | Explains the scanner as a short outcome chain: capture, enhance, organize, export. | Structure the main story as Scan → Review → Track, using real Rosid screens. |
| [Smart Receipts](https://smart-receipts.com/docs) | Sells practical recordkeeping and export rather than OCR alone. | Position OCR as the input to editable expenses and useful CSV/PDF records. |
| [OSS Document Scanner](https://github.com/ossappscollective/OSS-DocumentScanner) | Keeps screenshots, source, package identity, and direct binaries visibly connected. | Show the package ID, release archive, source, issue tracker, and verification values. |

## Distribution research

- GitHub's stable
  [`/releases/latest/download/<asset>` links](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)
  require a consistent asset name. Rosid therefore always publishes
  `rosid.apk` and `rosid-ios-unsigned.ipa`.
- GitHub documents release and asset integrity checks in its
  [release integrity guidance](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity).
  Rosid publishes individual SHA-256 files and machine-readable release
  metadata.
- Google's current
  [sideloading guidance](https://support.google.com/pixelphone/answer/7391672)
  says users should keep Play Protect on and grant installation permission only
  to a trusted source. The page tells users to enable their browser temporarily
  and turn that permission off after installation.
- Apple documents that a free Personal Team is for personal testing, supports
  up to three devices, and uses provisioning profiles that expire after seven
  days. See the
  [developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/).
  The site therefore labels the hosted IPA as unsigned and advanced-only; it
  never presents it as a one-tap public iPhone install.

## Chosen visual direction

- Warm paper background, deep ink green, pale mint fields, and a restrained lime
  accent, matching the app rather than copying store chrome.
- Large outcome-led bilingual typography and generous whitespace.
- Real app captures in layered phone panels; no stock photography or fake
  testimonial content.
- One primary Android action, with iPhone constraints explained before its
  advanced download.
- A dark “proof, not promises” section for offline permission and release
  integrity evidence.
- No external fonts, frameworks, trackers, analytics, or cookies.

## Copy guardrails

- Printed Bangla and English OCR is the V1 claim. Handwriting remains clearly
  labeled best effort until the measured V2 gates pass.
- “Offline” means the Android distributable has no Internet permission; the
  claim is linked to the checked-in audit.
- No TestFlight, App Store, or one-tap iPhone promise is shown without Apple
  distribution signing.
- The early-access note remains until the owner completes broad physical-device
  QA.
