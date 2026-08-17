# Bamboo Slate / Penz protocol parity

This document records the Swift port against the Android reference under `answer-capture-android/app/src/main/java/com/example/answercapture`.

## Verified from Android source

- UUIDs: `slate/PenzSlateProtocol.java:7-38`; Swift: `PenzUUIDs.swift`.
- Constants/opcodes/modes: `PenzSlateProtocol.java:40-60`; Swift: `PenzProtocol.swift`.
- Frame shape is exactly `[opcode, bodyLength, body]`, with no checksum: `PenzSlateProtocol.java:65-71`.
- Set time is YY, month, day, hour, minute, second in local `Calendar` order: `PenzSlateProtocol.java:90-99`.
- Live enable sequence is mode repeated three times, auth, then mode: `PenzSlateProtocol.java:136-144`.
- Live packet opcode dispatch, all-FF pen-up, six-byte little-endian samples, and bounds: `SlateLivePacketParser.java:28-80`.
- Stored-page magic `62 38 62 74`, bit-count payload width, separators, delta masks, little-endian absolute values, 5 ms point spacing and 40 ms stroke gap: `StoredSlatePageParser.java:11-214`.
- Coordinate normalization and button orientations: `SlateGestureRecognizer.java:60-94`.
- One/two stroke thresholds, corner region, size, orthogonality, join distance, command IDs and rejection reasons: `SlateGestureRecognizer.java:29-154`.
- JSON keys and command-stroke exclusion: `SlatePayloadFactory.java:62-170`.

## Explicitly unconfirmed

- Android source does not define a checksum; therefore Swift does not invent one. Any firmware-specific checksum or packet envelope outside these methods is **UNCONFIRMED** and must not be written to the device.
- Stored-page record offsets beyond the parser's bit-count algorithm are **UNCONFIRMED** until a real capture is validated.
- Registration UUID byte order and authentication semantics are **UNCONFIRMED** by source alone. The Swift central skeleton does not issue registration/destructive writes automatically.
- CoreBluetooth characteristic discovery/write sequencing and background behavior require a real Slate capture and iPhone validation.

## Safety

There is no MAC-address dependency; the central stores `CBPeripheral.identifier` (UUID). `DELETE_PAGE` is not automatically sent. A delete frame is exposed only through `SlateCentral.confirmedDeleteFrame(serverUploadSucceeded:)` after explicit server-success state, and all other uncertain writes remain absent.

Fixtures in `Tests/AnswerCaptureCoreTests/Bluetooth` are synthetic vectors derived from the verified source methods; they are not claims about an unobserved device capture.
