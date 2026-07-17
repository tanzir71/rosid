# Releasing Rosid

Local signed builds were intentionally not run in the disk-constrained Codex
workspace. The tag workflow performs the repeatable Android build on GitHub.

## One-time repository setup

1. Push this repository to GitHub and enable Pages with **GitHub Actions** as the source.
2. Create a release keystore on a secure machine:

   ```sh
   keytool -genkeypair -v -keystore rosid-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias rosid
   ```

3. Base64-encode it and add these Actions secrets:

   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`

4. Keep the original keystore and passwords in a secure, backed-up location.
   Losing them prevents users from upgrading an existing sideloaded install.

## Android release

1. Update `version:` in `pubspec.yaml` and append the changelog to `PROGRESS.md`.
2. Run `FLUTTER_BIN=/path/to/flutter tool/check.sh` on a provisioned machine.
3. Push a semantic tag such as `v1.0.0`.
4. The release workflow downloads pinned `tessdata_best` English/Bangla models,
   runs tests, builds/signs `rosid.apk`, audits the manifest, and publishes:

   - `rosid.apk`
   - APK SHA-256
   - signing certificate SHA-256

5. Install the released asset on a clean Android 8+ device and complete
   [MANUAL_QA.md](MANUAL_QA.md) before announcing it.

To build manually after adding `assets/tessdata/eng.traineddata`,
`assets/tessdata/ben.traineddata`, and `android/key.properties`:

```sh
flutter pub get
tool/check.sh
flutter build apk --release
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

## iOS/TestFlight

An Apple Developer account and signing team are human prerequisites.

1. Open `ios/Runner.xcworkspace` in Xcode and select the correct team/bundle ID.
2. Ensure the two traineddata files are present before `flutter build ipa`.
3. Run `flutter build ipa --release --dart-define=APP_PROFILE=ios`.
4. Upload the archive with Xcode Organizer, complete export-compliance answers,
   and create a public TestFlight link in App Store Connect.
5. Replace the disabled TestFlight slot in `site/index.html` and redeploy Pages.
6. Repeat before each TestFlight build's 90-day expiry.

Direct public iOS sideloading is intentionally not claimed: TestFlight is the
practical V1 distribution channel.
