# Installing Rosid on a personal iPhone

Rosid does not currently have Apple distribution signing. The GitHub Release
therefore contains an **unsigned** `rosid-ios-unsigned.ipa`, not an App Store or
TestFlight build. It cannot be installed by tapping the file on an iPhone.

Apple allows a free Apple Account to provision apps for personal testing, but
the limits are strict: provisioning expires after 7 days, up to 3 personal
devices can be registered, and up to 3 self-signed apps can be active on a
device. See Apple's current
[developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/).

## Before proceeding

- Only download the IPA from the project's official
  [GitHub Releases](https://github.com/tanzir-lameh/rosid/releases).
- Compare the downloaded file's SHA-256 with
  `rosid-ios-unsigned.ipa.sha256` from the same release.
- Self-signing is an advanced, user-managed installation route. It may stop
  working when Apple changes its provisioning rules.
- Never send an Apple Account password to the Rosid project. Rosid does not
  operate a signing service and cannot recover an account or provisioning
  profile.

## Option A: build and run with Xcode

This is the most transparent route and requires a Mac with the Flutter SDK,
Xcode, and CocoaPods.

1. Clone the tagged release from GitHub.
2. Run `flutter pub get` from the repository root.
3. Run `cd ios && pod install && cd ..` to install the native plugin pods from
   the committed `Podfile.lock`.
4. Open `ios/Runner.xcworkspace` in Xcode.
5. In **Signing & Capabilities**, choose your Apple Account's **Personal Team**.
6. If Xcode says the bundle identifier is already registered, use a unique
   personal identifier.
7. Connect your iPhone, select it as the run destination, and run the app.
8. Rebuild and reinstall when the 7-day provisioning profile expires.

## Option B: self-sign the hosted IPA

An IPA sideloading tool can sign the hosted package with the user's own Apple
Account. One established option is
[AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore),
which documents the same 7-day expiry and 3-app limit for free accounts.

1. Install the signing tool only from its official website.
2. Download `rosid-ios-unsigned.ipa` and its checksum from the same Rosid
   release.
3. Verify the file before giving it to the signing tool.
4. Follow the signing tool's instructions to sign and install the IPA with your
   own Apple Account.
5. Refresh or reinstall the app before its free provisioning expires.

Rosid does not audit or bundle third-party signing tools. Review their security
model before entering Apple Account credentials.

## Verify the IPA on macOS or Linux

```sh
shasum -a 256 rosid-ios-unsigned.ipa
cat rosid-ios-unsigned.ipa.sha256
```

The two SHA-256 values must match exactly. On Windows, use:

```powershell
Get-FileHash .\rosid-ios-unsigned.ipa -Algorithm SHA256
Get-Content .\rosid-ios-unsigned.ipa.sha256
```

The unsigned artifact proves which app bundle the Rosid release workflow built;
it does not replace the personal signature required for installation.
