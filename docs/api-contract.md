# Viewer API contract and compatibility record

## Common transport

Evidence: `answer-capture-android/app/src/main/java/com/example/answercapture/ViewerUploadClient.java` (`CONNECT_TIMEOUT_MS`, `READ_TIMEOUT_MS`, `getJson`, `postJson`) and `answer-capture-android/docs/viewer-contract.md` lines 9–25. Base URL is normalized by `normalizeViewerUrl`: trim and remove every trailing `/`. The spec default is `http://192.168.0.10:8785`; only `http`/`https` are allowed by the iOS requirement.

- Connect timeout: 5,000 ms.
- Read timeout: 60,000 ms, except command long-poll query `wait=25`.
- UTF-8 JSON; POST `Content-Type: application/json; charset=utf-8`; all requests send `Accept: application/json`.
- Token header: `X-Answer-Capture-Token` when the Android method includes it. The token is trimmed; Android reads preferences, while iOS must use Keychain.
- HTTP 200–299 is transport success. JSON `ok` is a separate application success gate.
- Android source logs/returns raw HTTP body in exception text; iOS requirement limits diagnostic body retention to 4 KB and forbids token logging.
- Viewer token evidence: `data/answer_capture_upload_token.txt` or `YC_ANSWER_CAPTURE_UPLOAD_TOKEN` in `answer-capture-android/docs/viewer-contract.md` lines 17–23. No server validator implementation was found in the searched workspace; acceptance rules below are therefore source/client evidence, not a server guarantee.

## `POST /api/answer-image-watch-import`

Android evidence: `ViewerUploadClient.uploadIfConfigured`; viewer behavior: `answer-capture-android/docs/viewer-contract.md` lines 7–25.

Header: `X-Answer-Capture-Token` required by the documented viewer contract and included by Android. Request JSON observed in Android:

```json
{
  "source": "android_answer_capture_app",
  "captureId": "<id>",
  "filename": "<id>.jpg",
  "pageCount": 1,
  "problemIdUnknown": true,
  "requiresProblemIdentification": true,
  "clientCapturedAt": "ISO-8601",
  "pages": [{"pageIndex": 1, "filename": "<id>_p001.jpg", "dataUrl": "data:image/jpeg;base64,..."}]
}
```

The viewer contract also names `dataUrl`, `filename`, `captureId`, `pageIndex`, and `pageCount`, and says problem ID comes from the armed watch target, not the request. Android accepts response keys `ok`, `imported`, `skipped`, `problemId`, `requiresProblemIdentification`, and `error`; it treats `ok=false` as failure. The spec proposes iOS `source=ios_answer_capture_app`, but source compatibility is **UNCONFIRMED** because no server validator was found and the viewer document only describes the Android path. Do not silently fall back to the Android source string; run a contract test or obtain server confirmation.

## `GET /api/answer-camera/commands?deviceId=<id>&after=<seq>&wait=25`

Evidence: `ViewerUploadClient.pollRemoteCommand`, `RemoteCameraActivity.java`, and spec §9.3. Android sends the token header, URL-encodes `deviceId`, and persists only the last successfully processed sequence. The verified response is a single optional command, not an array: `{"command":{"seq":4,"type":"CAPTURE_PREVIEW","requestId":"...","sessionId":"..."}}`. The Swift decoder and contract test preserve that exact envelope. Unknown command handling and whether its seq advances remain **UNCONFIRMED**; the iOS implementation currently ignores unknown types without advancing seq.

## `POST /api/answer-camera/heartbeat`

Evidence: `ViewerUploadClient.sendRemoteHeartbeat` and spec §9.4. Android sends token plus:

```json
{"deviceId":"...","status":"...","requestId":"...","sessionId":"...","manufacturer":"<Build.MANUFACTURER>","model":"<Build.MODEL>","androidVersion":"<release>","appVersion":"...","lastError":"..."}
```

`requestId` and `sessionId` are included when a command is supplied; `lastError` is always sent, including empty string. The spec requires iOS `manufacturer=Apple`, `model=iPhone 12`, `platform=ios`, `osVersion=<device>`, `appVersion`, and `lastError`, and says to send transitional `androidVersion` equal to the OS string if the backend still requires it. Server requiredness and acceptance of `platform`/`osVersion` are **UNCONFIRMED**.

## `POST /api/answer-camera/captures`

Evidence: `ViewerUploadClient.uploadRemoteCapture` and spec §9.5. Android sends token plus:

```json
{"deviceId":"...","requestId":"...","sessionId":"...","captureId":"ACC-<epoch-ms>","capturedAt":"ISO-8601","manufacturer":"<Build.MANUFACTURER>","model":"<Build.MODEL>","androidVersion":"<release>","appVersion":"...","dataUrl":"data:image/jpeg;base64,..."}
```

The iOS requirement adds `platform` and `osVersion`; server acceptance is **UNCONFIRMED**. Capture data must be saved locally before upload and queued after failure.

## `POST /api/slate-capture/pages`

Evidence: `ViewerUploadClient.uploadSlatePageIfConfigured`, `SlatePayloadFactory.java`, and spec §9.6/§13.7. Android sends JSON and deliberately passes an empty token with `includeUploadToken=false`; whether the viewer authenticates this endpoint, requires no token, or has another auth mechanism is **UNCONFIRMED**. Response keys consumed by Android: `ok`, `finalized`, `nextPageReady`, `draftId`, `reason`, `error`.

Payload compatibility keys observed in `SlatePayloadFactory`: `problemId`, `pageId`, `deviceId`, `draftId`, `captureSequence`, `createdAt`, `slateOrientation`, `paperSize.widthMm/heightMm`, `coordinateSpace.width/height`, `androidCaptureMode` (live path), `androidCommandDetection.accepted/kind/reason/commandStrokeIds`, `trigger`, `commandType`, and `strokes[]`. Stroke keys are `strokeId`, `startedAtMs`, `endedAtMs`, `role`, `commandType`, `excludedFromAnswer`, and `points[]` with `x/y/t/pressure`. The spec requires `clientPlatform=ios` and retains Android compatibility keys. Server validation of these fields is **UNCONFIRMED**.

**STOP CONDITION — field-value conflict:** Android `SlatePayloadFactory` sends `trigger="bottom_right_corner_gesture"` and `commandType="finalize_capture_ocr"` when the command is accepted. Specification §13.7 lists those values in the opposite fields. The Swift compatibility path currently preserves the verified Android values and adds `clientPlatform="ios"`; switching to the specification's reversed values requires server-contract confirmation.

## Local compatibility schemas

Evidence: `ScanRepository.java` methods `buildScanJson`, `buildManifestRow`, `pageArray`, plus `answer-capture-android/docs/viewer-contract.md` lines 93–127. Preserve schemas `answer-capture.scan.v1` and `answer-capture.manifest.v1`, status `ready`, ISO-8601 timestamps, page index starting at 1, `image/jpeg`, dimensions, byte size, SHA-256, relative paths, and Android compatibility `androidUri` as JSON `null` on iOS. Never serialize security-scoped bookmarks or file URLs. Exact viewer behavior for unknown keys/null `androidUri` is **UNCONFIRMED**.
