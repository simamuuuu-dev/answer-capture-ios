# Dependency decision: standard-framework-only baseline

## Decision

The MVP baseline uses Apple SDK frameworks only: SwiftUI, UIKit, AVFoundation, Core Motion, VisionKit, Vision, Core Image, Accelerate/vImage, Core Bluetooth, Foundation/URLSession, CryptoKit, Security/Keychain Services, UniformTypeIdentifiers, and XCTest/XCUITest. No external Swift Package Manager dependency is approved for the baseline.

## Rationale

- The specification explicitly requires standard-framework-only unless an external library is justified.
- Camera, document scanning, OCR, image processing, local networking, BLE, hashing, storage security, and testing all have Apple APIs available on the target deployment.
- Removing third-party packages reduces supply-chain, licensing, ABI, SDK-26, SideStore, and offline-build risk.
- A native implementation is necessary for exact control over the Android-compatible JSON and Penz packet/gesture behavior; a generic BLE or networking package would obscure protocol evidence.

## Mapping

| Need | Baseline framework | Evidence / decision |
|---|---|---|
| UI/settings | SwiftUI, UIKit wrappers | Spec §5.1; no package needed |
| Camera and capture | AVFoundation, Core Motion | Spec §3.2/§5.1; replace CameraX/sensors |
| Document scan | VisionKit | Spec §3.2/§11; do not automate system UI |
| OCR/rectangles | Vision | Spec §5.1/§10/§11 |
| Correction/sharpness | Core Image, Accelerate/vImage | Spec §5.1/§10 |
| LAN API | URLSession, Foundation Codable | Spec §3.2/§9; preserve Android field names |
| BLE | Core Bluetooth | Spec §3.2/§13; use peripheral UUID, not MAC |
| Hashing/secrets | CryptoKit, Security Keychain Services | Spec §5.1/§15 |
| Files/bookmarks | Foundation FileManager, UIDocumentPicker, security-scoped bookmarks, NSFileCoordinator | Spec §3.2/§8 |
| Tests | XCTest/XCUITest | Spec §5.1/§17 |

## Addition gate

An external dependency may be proposed only after a standard framework is shown insufficient for a specific requirement. The proposal must record package URL and pinned version, license, maintenance/release status, transitive dependencies, privacy/network behavior, Swift/Xcode/iOS 26 compatibility, binary size, and removal plan. Approval is required before adding it. Until that record exists, the status is **UNCONFIRMED** and the dependency is not part of the build.
