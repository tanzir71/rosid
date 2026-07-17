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

1. Push this repository to GitHub and enable Pages with **GitHub Actions** as
   the source.
2. Before provisioning signing secrets, add an enforced repository tag ruleset
   for `v*`. Restrict creation, update, and deletion of matching tags to trusted
   release maintainers. Release tags must point to a reviewed commit on `main`;
   do not tag an unreviewed commit or a contributor branch.
3. Create an `android-release` GitHub environment. Configure at least one
   required reviewer, prevent self-review and administrator bypass where those
   controls are available, and restrict deployment tags to the protected `v*`
   pattern. The release job is intentionally gated on this environment.
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
4. The `android-release` environment reviewer verifies the tag target, version,
   and workflow revision before approving the waiting job. Approval is what
   makes the environment-scoped signing secrets available to the job.
5. The release workflow verifies the checked-in `tessdata_best` English/Bangla
   files against their pinned SHA-256 values. It does not download OCR models.
   The workflow then runs tests, builds/signs `rosid.apk`, and audits the merged
   manifest. Before publishing, `apksigner` verifies the emitted APK and the
   workflow compares its normalized signer SHA-256 with the configured release
   keystore. A missing, invalid, multi-signer, or mismatched artifact fails the
   release.
6. After verification, the workflow publishes:

   - `rosid.apk`
   - APK SHA-256
   - signing certificate SHA-256

   Once the GitHub Release succeeds, the same tag workflow deploys `site/` to the
   `github-pages` environment. Pages deployments share the repository's `pages`
   concurrency group so overlapping site deployments are serialized/cancelled
   consistently.
7. Install the released asset on a clean Android 8+ device and complete
   [MANUAL_QA.md](MANUAL_QA.md) before announcing it.

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

## iOS/TestFlight

An Apple Developer account, signing team, macOS, and Xcode are prerequisites.
This workspace has none of those, so the native iOS compile/sign and TestFlight
steps remain externally blocked even though the profile logic and iOS project
configuration are present.

1. Open `ios/Runner.xcworkspace` in Xcode and select the correct team/bundle ID.
2. Verify the two checked-in traineddata files retain the hashes documented in
   `assets/tessdata/README.md` before `flutter build ipa`.
3. Run `flutter build ipa --release --dart-define=APP_PROFILE=ios`.
4. Upload the archive with Xcode Organizer, complete export-compliance answers,
   and create a public TestFlight link in App Store Connect.
5. Replace the disabled TestFlight slot in `site/index.html` and redeploy Pages.
6. Repeat before each TestFlight build's 90-day expiry.

Direct public iOS sideloading is intentionally not claimed: TestFlight is the
practical V1 distribution channel.
