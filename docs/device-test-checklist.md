# Device and automated verification checklist

Record date, app commit/build, iOS version, device identifiers, result, and evidence for every executed item. A requirement with no result is not accepted.

## Static audit record — 2026-08-17 (Windows)

- PASS: all 40 Swift files parsed without syntax-tree errors using an independent Swift grammar parser.
- PASS: `Info.plist`, entitlements, and the shared scheme parsed as XML.
- PASS: the handwritten `project.pbxproj` parsed with an OpenStep/Xcode project parser; deployment target 26.0, Swift 6, strict concurrency, empty Development Team, and example bundle ID were present.
- PASS: 20 deterministic XCTest methods are present, including the single-command remote envelope, flexible import counts, millisecond dates, explicit `androidUri:null`, seq deduplication, pending retention/rejection/limit, camera timing/sharpness, crop, OCR metrics, and synthetic Slate fixtures.
- NOT RUN: Swift compilation and XCTest execution. This Windows host has no Swift/Xcode/iOS SDK; results below remain unchecked until run on macOS and the target devices.

## Automated checks (Windows or macOS where the toolchain permits)

- [ ] URL normalization trims whitespace and all trailing slashes; rejects non-http(s).
- [ ] Codable/API fixtures assert all four paths, methods, query parameters, headers, timeout defaults, and response gates.
- [ ] Import JSON golden fixture preserves page order, `data:image/jpeg;base64,` prefix, and iOS source compatibility decision.
- [ ] `scan.json` and `manifest.jsonl` golden fixtures preserve schema, status, page fields, SHA-256, and `androidUri=null`.
- [ ] Atomic save tests prove incomplete images never produce a ready manifest row.
- [ ] Pending queue tests cover restart, network recovery, 200 success deletion, 401/403, 404, 409, 500, timeout, malformed JSON, 200 with `ok=false`, and queue limit warning.
- [ ] Remote state tests cover `OFFLINE → WAITING → CAPTURING → UPLOADING → WAITING`, failure retry backoff 1/2/4/8/30 s, and duplicate seq suppression.
- [ ] Camera logic tests cover 2.5 s startup gate, 1.8 s stable window, ten-frame minimum, 3-frame selection, tie-to-center, and manual 0.5 s delay using injected clocks/sensor values.
- [ ] Image tests cover orientation, rectangle fallback, perspective correction, crop minimum 5%, and no destructive discard on detection failure.
- [ ] OCR tests cover Japanese/English configuration, page order, cancellation, and one-page failure without losing other pages.
- [ ] Penz golden hex tests cover every command/frame, little-endian live samples, invalid range rejection, stored magic/delta parsing, and stroke separators.
- [ ] Gesture tests cover four orientations, one/two-stroke L, timing/size/corner constraints, no-strokes, no-finalize, empty-answer rejection, and command exclusion.
- [ ] Security tests prove token, Authorization data, Base64 image text, bookmark, and raw sensitive payloads do not enter logs.

## iPhone 12 / iOS 26.5.2 checks

- [ ] Clean install launches without jailbreak; camera, Bluetooth, and Local Network prompts appear only when needed.
- [ ] Rear main wide camera is selected; zoom clamps to device limits; portrait normalization is correct.
- [ ] Fixed desk: automatic capture waits through startup and stable window, then captures once; record motion/sharpness telemetry.
- [ ] Handheld and lightly vibrating desk: false captures are suppressed; calibrate the iOS threshold from recorded data.
- [ ] Three-frame capture chooses the sharpest image and persists the score/selection.
- [ ] Perspective correction, lighting compensation, pencil-line retention, manual crop, upper/lower-half presets, and invalid crop disabling work.
- [ ] One- and ten-page VisionKit scans save in order; cancellation is not reported as an error.
- [ ] Japanese plus Latin/math-like answer OCR returns page-level text/metrics without blocking the saved scan.
- [ ] Local HTTP viewer connection succeeds after Local Network permission; HTTPS behavior and token failures are clear.
- [ ] Foreground remote wait runs 30 minutes, shows seq/request/session/time, captures once per command, and resumes after transient network loss.
- [ ] Background transition records state and does not claim indefinite long-poll support; foreground recovery works.
- [ ] Files shared-folder bookmark can be resolved after restart; expired/read-only bookmark gives a reselect action.
- [ ] Offline capture remains locally available; recovery resends once and does not duplicate the page.

## Bamboo Slate checks

- [ ] Initial scan shows name, peripheral UUID, RSSI, and advertised services; user confirms the intended Slate rather than a MAC address.
- [ ] Registered `CBPeripheral.identifier` reconnects within the bounded retry policy; Bluetooth off/denied gives actionable guidance.
- [ ] Registration/auth/time/mode commands are run only with captured logs and confirmed target device.
- [ ] Live notification subscription decodes PEN_DATA, PEN_UP, proximity, and button events; coordinates and pressure remain in bounds.
- [ ] Stored page download verifies magic, point/stroke counts, delta decode, and page identity before delete.
- [ ] Live and stored orientation transforms pass `button_top`, `button_bottom`, `button_left`, and `button_right`.
- [ ] Valid one- and two-stroke bottom-right `「」`-style command finalizes only with answer strokes present; command strokes are excluded.
- [ ] Ordinary bottom-right answer writing, short strokes, late second stroke, and empty answer are rejected with the documented reason.
- [ ] Viewer receives Slate page; next page is writable immediately; OCR failure does not remove captured page.
- [ ] Page deletion is performed only after confirmed server success and a device-specific safety check.

## SideStore / distribution checks

- [ ] macOS clean build creates a signed IPA without committing Apple Account, team ID, or secrets.
- [ ] SideStore installation on iPhone 12 launches and preserves required entitlements/permissions.
- [ ] Seven-day signing renewal is verified as an external operation; app does not implement signing renewal.
- [ ] Reinstall/update preserves or explicitly migrates local scans, pending queue, settings, and peripheral UUID.
