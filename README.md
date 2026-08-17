# Answer Capture for iOS

Native iPhone 12 port of the Android Answer Capture app. The deployment target is iOS 26.0 and the implementation uses Swift 6 and Apple system frameworks.

## Repository layout

- `AnswerCapture.xcodeproj`: iOS application target.
- `AnswerCaptureApp`: SwiftUI application and feature screens.
- `Sources/AnswerCaptureCore`: reusable camera, image, OCR, storage, networking, remote-camera, and Slate logic.
- `Tests/AnswerCaptureCoreTests`: deterministic unit and contract tests.
- `docs`: API, Android parity, Slate protocol, and device-test records.

## Build on macOS

1. Install a stable Xcode that contains the iOS 26 SDK.
2. Open `AnswerCapture.xcodeproj`.
3. Select the `AnswerCapture` target, choose your personal Development Team, and replace the example bundle identifier if required.
4. Connect the iPhone 12, trust the Mac, select the device, and run.

Signing identities, team identifiers, tokens, and provisioning profiles are intentionally not committed.

Command-line build on a configured Mac:

```sh
xcodebuild \
  -project AnswerCapture.xcodeproj \
  -scheme AnswerCapture \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run core tests with an available iOS Simulator destination. First use `xcodebuild -list` in Xcode if the generated Swift Package scheme name differs on the installed Xcode version:

```sh
xcodebuild \
  -scheme AnswerCaptureCore \
  -destination 'platform=iOS Simulator,name=iPhone 12' \
  test
```

### Build without a local Mac

The repository includes `.github/workflows/ios-build.yml`. Push this directory to a GitHub repository, then run **Actions → iOS build → Run workflow**. The workflow requires a GitHub macOS runner with Xcode containing the iOS 26 SDK, builds the project without signing, packages `AnswerCapture-unsigned.ipa`, and uploads it as an artifact.

The unsigned IPA is a build artifact, not a directly installable app. Use SideStore, AltStore, or Sideloadly to sign it for the target iPhone. A normal App Store/development-signed IPA requires Apple signing credentials and should be configured only through GitHub Actions secrets; never commit certificates, provisioning profiles, Team IDs, or tokens.

## Installation and signing

For a free Apple Account, archive/export or build the app with a personal development team, then install the resulting IPA through SideStore or AltStore. Seven-day signing renewal is handled by that external tool; this app does not contain signing or renewal logic. TrollStore and jailbreaking are not required or supported.

## Configuration

- Default viewer URL: `http://192.168.0.10:8785`.
- The viewer token is stored in Keychain and must not appear in logs.
- Local HTTP is permitted only through `NSAllowsLocalNetworking`; arbitrary network loads remain disabled.
- Captures are saved under Application Support by default. A Files-selected folder is accessed through a security-scoped bookmark.
- Failed image-import and remote-capture requests are retried at launch, manually from Home, and every 30 seconds while the app is active. Pending data is never silently evicted at the 200-item/500 MB limit.

## Known MVP limits

- Bamboo Slate UUIDs, protocol frames, parsers, gestures, and payloads are implemented, but real Core Bluetooth registration/authentication/download writes remain disabled until packet byte order and deletion semantics are confirmed on the target Slate.
- Foreground remote capture is implemented; iOS background execution is not promised.
- An iPhone 12 is required to calibrate the Core Motion threshold and validate paper-line quality.
- The checked-in Xcode project was assembled on Windows and must be opened, built, and tested once on a Mac before signing.

## Verification boundary

Windows can review source, contracts, and deterministic fixtures, but it cannot build an iOS app. Xcode build/test, camera behavior, Local Network permission, Bamboo Slate BLE, signing, IPA installation, and endurance checks must be completed on a Mac and iPhone 12 using `docs/device-test-checklist.md`.
