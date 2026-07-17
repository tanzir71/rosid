# Releasing Rosid

The Windows workspace has successfully built a debug APK and an unsigned,
minified R8 release APK. The strict merged release-manifest audit also passed.
A signed release has not been built because the release keystore and passwords
are external secrets and were not provided; the tag workflow is the repeatable
signed-build path once the protected release environment and its secrets are
configured.

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

- debug: 254,530,293 bytes, SHA-256
  `19A128607123662ACDF9A6166B3C76F8AD79CDA0E7B14CDEDD731DFD39BC14CE`;
- minified release: 150,077,194 bytes, SHA-256
  `DA858408D6AC3CC82D647ECD485B35A35BB6312BAD12C319339F7D95F9680A0C`.

The release value was reproduced by two clean ordinary-entrypoint R8 builds.
An APK emitted by the integration-test runner is deliberately excluded from
these artifact records.

These hashes identify this local verification run, not a distributable release.
The release APK intentionally fails `apksigner verify` until signing inputs are
provided.

The local Gradle build initially encountered a `PKIX path building failed`
error because Avast HTTPS inspection's root certificate was not trusted by the
JDK. Validation succeeded using a temporary JDK truststore that explicitly
trusted that root. Do not disable TLS verification. Do not commit a local
truststore or its password; machines with TLS interception should use their own
administrator-approved temporary trust configuration.

## One-time repository setup

1. The canonical public repository is
   `https://github.com/tanzir-lameh/rosid`. Enable Pages with **GitHub Actions**
   as the source.
2. Before provisioning signing secrets, add an enforced repository tag ruleset
   for `v*`. Restrict creation, update, and deletion of matching tags to trusted
   release maintainers. Release tags must point to a reviewed commit on `main`;
   do not tag an unreviewed commit or a contributor branch.
3. Create an `android-release` GitHub environment and restrict deployment tags
   to the protected `v*` pattern. Add a required reviewer when the repository
   has a second trusted maintainer; GitHub cannot use the sole maintainer as an
   independent reviewer.
4. Create a release keystore on a secure machine:

   ```sh
   keytool -genkeypair -v -keystore rosid-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias rosid
   ```

5. Base64-encode it and add these four secrets to the **`android-release`
   environment**, not as repository-wide Actions secrets:

   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`

6. Keep the original keystore and passwords in a secure, backed-up location.
   Losing them prevents users from upgrading an existing sideloaded install.

## Signed Android release

1. Update `version:` in `pubspec.yaml`, append the changelog to `PROGRESS.md`,
   and merge the reviewed release commit to `main`.
2. Run the appropriate local check command above on a provisioned machine.
3. A trusted release maintainer creates and pushes a protected semantic tag,
   such as `v1.0.0`, pointing at that reviewed `main` commit.
4. Verify the tag target, version, and workflow revision. If the environment has
   a required reviewer, that reviewer approves the waiting Android job before
   its scoped signing secrets become available.
5. The release workflow verifies the checked-in `tessdata_best` English/Bangla
   files against their pinned SHA-256 values. It does not download OCR models.
   The workflow then runs tests, builds/signs `rosid.apk`, and audits the merged
   manifest. Before publishing, `apksigner` verifies the emitted APK and the
   workflow compares its normalized signer SHA-256 with the configured release
   keystore. A missing, invalid, multi-signer, or mismatched artifact fails the
   release.
6. In parallel, a GitHub-hosted macOS runner compiles the iOS target without
   code signing and packages it as an explicitly unsigned IPA. After both jobs
   succeed, the workflow publishes:

   - `rosid.apk`
   - APK SHA-256
   - signing certificate SHA-256
   - `rosid-ios-unsigned.ipa` and its SHA-256
   - an unsigned-iOS warning and machine-readable release metadata

   Once the GitHub Release succeeds, the same tag workflow deploys `site/` to the
   `github-pages` environment. Pages deployments share the repository's `pages`
   concurrency group so overlapping site deployments are serialized/cancelled
   consistently.
7. Physical-device QA is owner-deferred for the initial V1 early-access
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
commit `android/key.properties`, the keystore, or passwords. Until those signing
inputs are supplied, the unsigned build and merged-manifest audit are the
furthest reproducible local release gates.

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
