# Android to iOS parity matrix

Status values: **CONFIRMED** means the Android source/spec gives an implementable contract; **ADAPT** means an Apple replacement is specified; **UNCONFIRMED** means evidence is insufficient and implementation must stop or use a test seam.

## Implementation snapshot

- **Implemented in source:** project/settings/Keychain, local camera and three-frame sharpness selection, crop/correction, VisionKit import, Vision OCR, atomic scan/manifest storage, image import, foreground remote capture, typed pending queue with startup/manual/30-second retry, API models, Slate UUIDs/parsers/gesture/payload, and deterministic unit/contract tests.
- **Safety-scaffolded only:** `SlateCentral` state model and UI. No unconfirmed registration/authentication/write/delete sequence is sent to a real Slate.
- **Blocked on Apple hardware/tooling:** Xcode compile/test, iPhone 12 camera calibration, LAN server acceptance, security-scoped File Provider behavior, BLE packet fixtures/byte order, signing/IPA, and endurance tests.
- **Not yet acceptance-complete:** real Core Bluetooth transport, UI-test target, network-recovery-triggered retry, and full device integration. The app must not be described as release-ready until the device checklist is completed.

| Android feature/class | Android evidence | iOS equivalent | Status / parity note |
|---|---|---|---|
| `MainActivity`, `AppSettings` | `app/src/main/java/com/example/answercapture/MainActivity.java`, `AppSettings.java` | SwiftUI Home/Settings, `AppSettingsStore`, UserDefaults; token in Keychain | ADAPT; default viewer URL/device ID must match spec |
| `StableCameraActivity` | `StableCameraActivity.java` | AVFoundation camera + Core Motion + `StableCaptureController` | ADAPT; reference timing/limits are source/spec evidence, sensor threshold needs iPhone calibration |
| Three-frame capture / sharpness selection | `StableCameraActivity.java` | AVFoundation burst + downsampled Laplacian variance | ADAPT; 3 frames, ~140 ms interval, max-score selection and center tie-break are implemented; device calibration remains |
| `RectangleCropActivity` | `RectangleCropActivity.java` | Vision rectangle detection + Core Image perspective correction + SwiftUI crop | ADAPT; preserve fallback to manual crop |
| `OcrCheckActivity` | `OcrCheckActivity.java` | Vision `VNRecognizeTextRequest`, VisionKit document scanner | ADAPT; Android block/line/element counts map to iOS observations/lines/tokens |
| `ScannerAutoApproveService` | `ScannerAutoApproveService.java` and XML service config | No equivalent; self-owned AVFoundation remote camera UI | ADAPT by requirement; iOS must not automate VisionKit system UI |
| `ScanRepository` | `ScanRepository.java`, `docs/viewer-contract.md` | `ScanRepository` actor, Application Support or security-scoped folder | ADAPT; preserve `answer-capture.scan.v1`, `answer-capture.manifest.v1`, page ordering, SHA-256, atomic writes |
| `ViewerUploadClient` image import | `ViewerUploadClient.java` | `ViewerAPIClient` with URLSession | CONFIRMED endpoint/fields; iOS `source` compatibility is UNCONFIRMED until server accepts `ios_answer_capture_app` |
| Remote command polling | `ViewerUploadClient.pollRemoteCommand`, `RemoteCameraActivity.java` | `RemoteCameraCoordinator` | CONFIRMED path/query/25s wait and persisted seq; unknown-command seq advancement is UNCONFIRMED |
| Remote heartbeat | `ViewerUploadClient.sendRemoteHeartbeat` | URLSession heartbeat encoder | ADAPT; Android sends `androidVersion` and no `platform`; spec requests iOS fields and transitional compatibility |
| Remote capture upload | `ViewerUploadClient.uploadRemoteCapture` | URLSession capture upload | ADAPT; Android uses `androidVersion` and no `platform`; iOS field acceptance UNCONFIRMED |
| `SlateCaptureActivity` | `SlateCaptureActivity.java` | `SlateCentral` actor/Core Bluetooth | ADAPT; iOS identifies by `CBPeripheral.identifier`, not Android MAC |
| `PenzSlateProtocol` | `slate/PenzSlateProtocol.java` | `PenzProtocol` | CONFIRMED for listed UUIDs, opcodes, two-byte header (`opcode`, one-byte body length), and listed sequences; checksum/delete semantics remain device-risk items |
| `NativeBleSlateTransport` | `slate/NativeBleSlateTransport.java` | Core Bluetooth transport | ADAPT; background operation is not guaranteed in MVP |
| `SlateLivePacketParser` | `slate/SlateLivePacketParser.java` | Swift live parser | CONFIRMED: opcode dispatch, six-byte little-endian x/y/pressure, coordinate/pressure bounds, `baseTime + sample index` |
| `StoredSlatePageParser` | `StoredSlatePageParser.java` | Swift stored-page parser | CONFIRMED for magic `62 38 62 74`, header bit-count/delta rules, 5 ms points, 40 ms stroke gap; needs golden fixtures |
| `SlateGestureRecognizer` | `SlateGestureRecognizer.java` | Swift `SlateGestureRecognizer` | CONFIRMED thresholds/normalized rotations/reasons; must add golden tests and reject empty answer strokes |
| `SlatePayloadFactory` | `SlatePayloadFactory.java` | Swift Codable payload factory | CONFIRMED field names from source; §13.7 reverses Android's `trigger`/`commandType` values, so Android values are retained pending server confirmation; iOS compatibility fields remain UNCONFIRMED |
| Slate page upload | `ViewerUploadClient.uploadSlatePageIfConfigured` | URLSession `/api/slate-capture/pages` | CONFIRMED path/response keys; Android deliberately omits token header, so authentication policy is UNCONFIRMED |
| Pending/rejected uploads | Specification §14; Android source has local save/error paths | `PendingUploadQueue` actor | ADAPT; exact Android queue implementation and server idempotency header are UNCONFIRMED |
| Android MAC address | spec §3.2 | Saved peripheral UUID + service/name/RSSI discovery | ADAPT; never port `E1:0D:E9:77:A4:09` as an iOS identifier |
