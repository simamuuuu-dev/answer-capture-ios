# Answer Capture iOS parity plan

## Scope and evidence rule

This plan is for the iOS 26 / iPhone 12 port described in `C:/Users/pc/Downloads/AnswerCapture_iOS26_iPhone12_Codex_Spec.md`. The Android reference is `answer-capture-android`; the APK is `app/build/outputs/apk/debug/app-debug.apk` (49,189,917 bytes at inspection). The specification is a product requirement, while source and server evidence control compatibility claims. Unknown protocol facts remain explicitly marked `UNCONFIRMED`.

## Milestones and dependency order

1. **M0 — contract and parity freeze**
   - Read the specification, Android source, APK metadata, and viewer contract.
   - Freeze API field names, scan schemas, Slate UUID/opcode inventory, gesture behavior, and evidence links.
   - Stop M0 if an endpoint or payload differs between Android and the viewer, if a Slate frame checksum/byte order is not source-confirmed, or if a server validator is unavailable for an acceptance test.
2. **M1 — iOS foundation** (after M0)
   - SwiftUI navigation/settings, UserDefaults, Keychain token storage, permissions, URL normalization, actors, and test seams.
   - Windows may edit and unit-test portable Swift/source artifacts; macOS/Xcode is required for the actual iOS build, signing, and device debugging.
   - Stop if the clean macOS build cannot resolve the chosen SDK or if signing would require repository secrets.
3. **M2 — local capture and storage** (after M1)
   - AVFoundation/Core Motion, 3-frame selection, image correction/crop, `scan.json`, `manifest.jsonl`, SHA-256, atomic pending storage.
   - Stop if image persistence is not complete before upload or if Android-compatible metadata cannot be represented without leaking a security-scoped URL.
4. **M3 — document scan and OCR** (after M2 foundation; independent camera UI work may proceed in parallel)
   - VisionKit, Vision Japanese OCR, page-level error handling, and metrics mapping.
   - Stop if OCR cancellation or partial-page failure loses saved images.
5. **M4 — viewer remote capture** (after M1, M2, and API contract test fixtures)
   - Foreground long-poll state machine, heartbeat, sequence persistence, capture upload, retry queue, and offline transitions.
   - Stop if server acceptance of iOS compatibility fields is not confirmed, or if background behavior is being treated as indefinite.
6. **M5 — Bamboo Slate** (after M1 and M0 protocol freeze)
   - Core Bluetooth discovery/registration, live packets, stored-page parser, gesture recognizer, payload, and safe delete-after-success.
   - Stop before any write/delete command if frame structure, UUID byte order, or delete semantics are not source- and device-confirmed.
7. **M6 — integration, distribution, and endurance** (after M2–M5)
   - Automated tests, iPhone 12 tests, Slate tests, LAN tests, SideStore installation, 30-minute to 2-hour endurance, and privacy review.
   - Stop release if any required acceptance test is unexecuted, if tokens/images appear in logs, or if a new dependency lacks the decision record.

## Windows/Mac boundary

Windows/Codex can perform source editing, contract analysis, fixture preparation, static checks, and repository tests that do not require Apple tooling. macOS with a stable Xcode containing the iOS 26 SDK is required for Swift compilation against Apple frameworks, code signing, IPA generation, SideStore/AltStore installation, and iPhone 12/Bamboo Slate validation. A permitted macOS CI can replace a local Mac only when it can access the required signing workflow without storing secrets in the repository.

## Stop conditions

Do not invent API keys, server acceptance rules, BLE checksums, byte order, or gesture behavior. Escalate with the evidence and alternatives when any of these is `UNCONFIRMED`. Do not run Slate page deletion or initialization commands on a real device until the device test explicitly confirms the target-page semantics. Do not claim completion from a build alone; all automated and device checks in `docs/device-test-checklist.md` must be recorded.
