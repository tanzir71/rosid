# Releasing Rosid

The Windows workspace has successfully built a debug APK and an unsigned,
minified R8 release APK. The strict merged release-manifest audit also passed.
A release keystore is backed up outside the repository, and all four signing
secrets are scoped to the `android-release` environment. The enforced `v*` tag
ruleset, immutable-release setting, environment tag policies, and GitHub Actions
Pages source are configured. V1.0.0 subsequently completed the protected signed
Android build, unsigned iOS compile/package, immutable GitHub Release, and public
Pages deployment.

## Local verification

Run the complete source gate from PowerShell:

```powershell
.\tool\check.ps1
```

Include a debug APK build on a provisioned Windows Android toolchain with:

```powershell
.\tool\check.ps1 -RunBuild
```

The equivalent Bash commands are:

```bash
./tool/check.sh
ROSID_RUN_BUILD=1 ./tool/check.sh
```

Both scripts generate localization and Drift code, regenerate the checked-in
OCR fixture byte bundle, check formatting, analyze, run tests, and audit the
offline source policy. The build-enabled form additionally creates the debug
APK.

Flutter debug builds intentionally declare `INTERNET` for the debugger/VM
service, so the debug gate rechecks the source policy rather than treating a
debug merged manifest as distributable. The release commands below are the only
ones that accept a strict merged-manifest result.

To reproduce the unsigned R8 release build and require a real merged manifest:

```powershell
flutter --no-version-check build apk --release
.\tool\audit_offline.ps1 -RequireMerged
```

or from Bash:

```bash
flutter --no-version-check build apk --release
./tool/audit_offline.sh --require-merged
```

The verified merged manifest contained only `android.permission.CAMERA` and
AndroidX's app-scoped signature compatibility permission. It contained no
network permission.

The final unsigned local artifacts were:

- debug: 254,529,846 bytes, SHA-256
  `463BD471886671FA3D349E35B5FD7B52C87C12B37A3994563FDFC3092991F340`;
- minified release: 150,028,058 bytes, SHA-256
  `0B4B90069BF01391080FBFB6C0FBB1EA6A591A26B5744B22F91DEF72DCF4B0FA`.

These post-routing-change artifacts use the Android-only native ML Kit channel.
The shrunk release contains `MainActivity`, and its merged manifest passed the
strict allowlist. An APK emitted by the integration-test runner is deliberately
excluded from these artifact records.

These hashes identify this local verification run, not a distributable release.
The release APK intentionally fails `apksigner verify` until signing inputs are
provided.

The local Gradle build initially encountered a `PKIX path building failed`
error because Avast HTTPS inspection's root certificate was not trusted by the
JDK. Validation succeeded using a temporary JDK truststore that explicitly
trusted that root. Do not disable TLS verification. Do not commit a local
truststore or its password; machines with TLS interception should use their own
administrator-approved temporary trust configuration.

## Published V1.0.0 evidence

- Release: `https://github.com/tanzir71/rosid/releases/tag/v1.0.0`
- Landing page: `https://tanzir71.github.io/rosid/`
- Release commit: `602ca4eda36cf7895809c4d308665392aae80db2`, preserved by
  both `v1.0.0` and `release/v1`
- Successful release workflow: `29625460054`
- Signed APK: 150,056,622 bytes, SHA-256
  `2CBE4774FA3B0E9D4CD7869E74DE234B885BFFFDBA489BE3F0DDD813F21C4183`
- APK signing certificate SHA-256:
  `3980AC0407EDC1AD2E46BE86A07A266910B2EF6634A42997CAB7C1BBD3EC29F7`
- Explicitly unsigned IPA: 58,555,375 bytes, SHA-256
  `2D90BA2C8F863F641B9A4A410770E3842958627EE1F131EB1FB311541C05621C`

GitHub reports the Release immutable, and the public Pages smoke test matches
its version, checksums, certificate fingerprint, and versioned download URLs.
This is artifact/publication evidence, not a substitute for the owner-deferred
physical-device script in `MANUAL_QA.md`.

## One-time repository setup

1. The canonical public repository is
   `https://github.com/tanzir71/rosid`. Enable Pages with **GitHub Actions**
   as the source.
2. Enable repository-level immutable releases. This makes each published
   release, its assets, and its associated tag read-only after publication.
3. Before provisioning signing secrets, add an enforced repository tag ruleset
   for `v*`. Restrict creation, update, and deletion of matching tags to trusted
   release maintainers. Release tags must point to a reviewed commit on `main`;
   do not tag an unreviewed commit or a contributor branch.
4. Create an `android-release` GitHub environment and restrict deployment tags
   to the protected `v*` pattern. Add a required reviewer when the repository
   has a second trusted maintainer; GitHub cannot use the sole maintainer as an
   independent reviewer.
5. Create a release keystore on a secure machine:

   ```sh
   keytool -genkeypair -v -keystore rosid-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias rosid
   ```

6. Base64-encode it and add these four secrets to the **`android-release`
   environment**, not as repository-wide Actions secrets:

   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`

7. Keep the original keystore and passwords in a secure, backed-up location.
   Losing them prevents users from upgrading an existing sideloaded install.

As of 2026-07-18, these one-time steps are complete: immutable releases are
enabled, the keystore backup and four environment secrets exist, the `v*` tag
ruleset is enforced, the `android-release` environment accepts only `v*` tags,
the `github-pages` environment accepts both `main` and `v*`, and Pages uses
GitHub Actions. The sole maintainer cannot provide an independent environment
review, so no required reviewer is configured yet. Release run `29625460054`
verified the complete protected publication path.

## Signed Android release

1. Update `version:` in `pubspec.yaml`, append the changelog to `PROGRESS.md`,
   and merge the reviewed release commit to `main`.
2. Run the appropriate local check command above on a provisioned machine.
3. Before creating the first release tag, run **Refresh iOS dependency lock**
   (`.github/workflows/ios-lock.yml`) on the intended `main` revision and wait
   for it to succeed. Download the `ios-podfile-lock` workflow artifact, place
   its `Podfile.lock` at `ios/Podfile.lock`, inspect the resolved dependencies,
   commit the lockfile to `main`, and rerun the checks. Do not tag a revision
   without the committed lockfile. The first helper run (`29621736516`) exposed
   ML Kit telemetry/network support pods and is superseded. Replacement run
   `29623751861` produced the committed Tesseract-only lock artifact (SHA-256
   `A008BF3142D4527512E42AC8D92CA5C8B48EAEB8EAC1BEF441058780BFCC3A33`).
   Every replacement lock must pass `tool/audit_ios_privacy.py`, which forbids
   those package and pod names before upload and again before the unsigned
   compile.
4. A trusted release maintainer creates and pushes a protected semantic tag,
   such as `v1.0.0`, pointing at that reviewed `main` commit.
5. Verify the tag target, version, and workflow revision. If the environment has
   a required reviewer, that reviewer approves the waiting Android job before
   its scoped signing secrets become available.
6. The release workflow verifies the checked-in `tessdata_best` English/Bangla
   files against their pinned SHA-256 values. It does not download OCR models.
   The workflow then runs tests, builds/signs `rosid.apk`, and audits the merged
   manifest. Before publishing, `apksigner` verifies the emitted APK and the
   workflow compares its normalized signer SHA-256 with the configured release
   keystore. A missing, invalid, multi-signer, or mismatched artifact fails the
   release.
7. In parallel, a GitHub-hosted macOS runner compiles the iOS target without
   code signing and packages it as an explicitly unsigned IPA. After both jobs
   succeed, the workflow publishes:

   - `rosid.apk`
   - APK SHA-256
   - signing certificate SHA-256
   - `rosid-ios-unsigned.ipa` and its SHA-256
   - an unsigned-iOS warning and machine-readable release metadata

   Publication fails unless GitHub reports the release as immutable. Once that
   check succeeds, the same tag workflow deploys `site/` to the `github-pages`
   environment. Pages deployments share the repository's `pages` concurrency
   group so overlapping site deployments are serialized/cancelled consistently.
8. Physical-device QA is owner-deferred for the initial V1 early-access
   release. Complete [MANUAL_QA.md](MANUAL_QA.md) before removing that label.

The model files are already checked in. To build manually after creating
`android/key.properties` that points to the protected release keystore:

```bash
flutter pub get
./tool/check.sh
flutter build apk --release
./tool/audit_offline.sh --require-merged
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

On Windows, use `.\tool\check.ps1` and
`.\tool\audit_offline.ps1 -RequireMerged` in the equivalent sequence. Never
commit `android/key.properties`, the keystore, or passwords. The configured
environment secrets are available only to the protected tag job; a successful
workflow signer check is still required before treating the APK as released.

## Unsigned iPhone package

No paid Apple Developer Program membership is available. The release workflow
therefore builds `Runner.app` with `--no-codesign`, verifies that it has no code
signature, and packages `rosid-ios-unsigned.ipa`. This proves the iOS target
compiles on the hosted macOS toolchain, but it is not a normal public install.

Users who already understand personal self-signing can sign the IPA with their
own Apple Account. Free provisioning normally expires after 7 days and must be
renewed. The landing page describes that friction before the download and links
to [IOS_SELF_SIGNING.md](IOS_SELF_SIGNING.md).

Do not call this artifact an App Store, TestFlight, ad-hoc, enterprise, or
notarized web-distribution build. All of those routes require Apple-controlled
signing, membership, eligibility, or review that this project does not have.
