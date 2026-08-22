import AnswerCaptureCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentScanView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showScanner = false
    @State private var message = "複数ページの答案を取り込めます"
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder").font(.system(size: 56))
            Text(message).multilineTextAlignment(.center)
            Button("文書スキャンを開始") {
                if DocumentScannerView.isSupported { showScanner = true }
                else { errorMessage = "この端末では文書スキャンを利用できません" }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("文書スキャン")
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onPages: { pages in
                    showScanner = false
                    Task { await save(pages) }
                },
                onCancel: { showScanner = false },
                onError: {
                    errorMessage = $0.localizedDescription
                    showScanner = false
                }
            )
        }
        .alert("スキャンエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("閉じる", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func save(_ images: [UIImage]) async {
        do {
            let pages = try images.map { image -> CapturedPageData in
                guard let data = image.jpegData(compressionQuality: 0.92) else {
                    throw ImageProcessingError.invalidImage
                }
                return .init(
                    jpeg: data,
                    width: Int(image.size.width * image.scale),
                    height: Int(image.size.height * image.scale)
                )
            }
            let result = try await model.saveCapturedPagesAndUpload(pages)
            message = result.uploaded
                ? "\(result.scan.pageCount)ページを保存して送信しました"
                : "\(result.scan.pageCount)ページを保存し、送信待ちに追加しました"
            model.record(scan: result.scan, message: message)
        } catch {
            errorMessage = "保存できません: \(error.localizedDescription)"
        }
    }
}

struct OCRView: View {
    @State private var showScanner = false
    @State private var showFiles = false
    @State private var photoItems = [PhotosPickerItem]()
    @State private var results = [OCRPageResult]()
    @State private var runningTask: Task<Void, Never>?
    @State private var errorMessage: String?

    private var combinedText: String {
        results.enumerated().map { "【ページ \($0.offset + 1)】\n\($0.element.text)" }
            .joined(separator: "\n\n")
    }

    var body: some View {
        List {
            Section("入力") {
                Button("文書スキャンしてOCR") { showScanner = true }
                    .disabled(!DocumentScannerView.isSupported)
                PhotosPicker("Photosから選択", selection: $photoItems, maxSelectionCount: 10,
                             matching: .images)
                Button("Filesから選択") { showFiles = true }
                if runningTask != nil {
                    Button("OCRをキャンセル", role: .destructive) {
                        runningTask?.cancel()
                        runningTask = nil
                    }
                }
            }
            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                Section("ページ \(index + 1)") {
                    Text(result.text.isEmpty ? "認識結果なし" : result.text)
                    Text(String(
                        format: "%.2f秒 / %d文字 / %d行 / %d観測",
                        result.metrics.duration, result.metrics.characters,
                        result.metrics.lines, result.metrics.observations
                    )).font(.caption)
                    if let error = result.errorDescription {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            if !results.isEmpty {
                Section {
                    Button("結果をコピー") { UIPasteboard.general.string = combinedText }
                    ShareLink("結果を共有", item: combinedText)
                }
            }
        }
        .navigationTitle("OCR確認")
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onPages: {
                    showScanner = false
                    startOCR($0)
                },
                onCancel: { showScanner = false },
                onError: {
                    errorMessage = $0.localizedDescription
                    showScanner = false
                }
            )
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let image = UIImage(data: try Data(contentsOf: url)) else {
                    throw ImageProcessingError.invalidImage
                }
                startOCR([image])
            } catch { errorMessage = error.localizedDescription }
        }
        .onChange(of: photoItems) { _, items in
            Task {
                var images = [UIImage]()
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) { images.append(image) }
                }
                startOCR(images)
            }
        }
        .alert("OCRエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("閉じる", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func startOCR(_ images: [UIImage]) {
        runningTask?.cancel()
        results = []
        runningTask = Task {
            let service = OCRService()
            for image in images {
                guard !Task.isCancelled else { break }
                if let cgImage = image.cgImage {
                    let result = await service.recognize(cgImage)
                    guard !Task.isCancelled else { break }
                    results.append(result)
                }
            }
            runningTask = nil
        }
    }
}

struct RemoteWaitingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = StableCaptureController()
    @State private var status = "OFFLINE"
    @State private var lastSeq: Int64 = 0
    @State private var lastRequestID = "—"
    @State private var lastCommunication: Date?
    @State private var zoom = 1.0
    @State private var waitingTask: Task<Void, Never>?
    @State private var screenWakeUntil: Date?
    @State private var screenWakeTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                CameraPreview(session: camera.session)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(status).font(.title2.monospaced().bold())
                Text("最終受信seq: \(lastSeq)")
                Text("requestId: \(lastRequestID)")
                Text("最終通信: \(lastCommunication?.formatted() ?? "—")")
                Slider(value: $zoom, in: 1 ... 5, step: 0.1)
                    .onChange(of: zoom) { _, value in camera.setZoom(value) }
                Text("ズーム: \(zoom, specifier: "%.1f")x")
                Button(waitingTask == nil ? "待機開始" : "待機終了") {
                    waitingTask == nil ? start() : stop()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if waitingTask != nil && !isScreenAwake {
                Color.black
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { revealScreenForOneMinute() }
                    .accessibilityLabel("画面を1分間表示")
            }
        }
        .navigationTitle("遠隔撮影待機")
        .toolbar(waitingTask == nil ? .automatic : .hidden, for: .navigationBar)
        .statusBarHidden(waitingTask != nil)
        .onDisappear { stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stop() }
        }
        .alert("遠隔撮影エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("設定を開く") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("閉じる", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func start() {
        zoom = model.settings.defaultZoom
        UIApplication.shared.isIdleTimerDisabled = true
        waitingTask = Task { await runLoop() }
    }

    private func stop() {
        waitingTask?.cancel()
        waitingTask = nil
        cancelScreenWakeTimer()
        camera.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        status = "OFFLINE"
    }

    private var isScreenAwake: Bool {
        guard let screenWakeUntil else { return false }
        return screenWakeUntil > Date()
    }

    private func revealScreenForOneMinute() {
        screenWakeTask?.cancel()
        screenWakeUntil = Date().addingTimeInterval(60)
        screenWakeTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                screenWakeUntil = nil
                screenWakeTask = nil
            } catch {
                // Cancellation is expected when waiting stops or the view disappears.
            }
        }
    }

    private func cancelScreenWakeTimer() {
        screenWakeTask?.cancel()
        screenWakeTask = nil
        screenWakeUntil = nil
    }

    private func runLoop() async {
        do {
            try await camera.ensureCameraPermission()
            try camera.configure()
            camera.setZoom(model.settings.defaultZoom)
            camera.start()
            let client = try ViewerAPIClient(baseURL: model.settings.viewerURL, token: model.token)
            let coordinator = RemoteCameraCoordinator(
                settings: model.settingsStore,
                client: client
            )
            await coordinator.start()
            status = "WAITING"
            while !Task.isCancelled {
                do {
                    _ = try? await client.heartbeat(heartbeat(status: status))
                    lastCommunication = Date()
                    guard let command = try await coordinator.poll(deviceId: model.settings.deviceId)
                    else { continue }
                    lastSeq = command.seq
                    lastRequestID = command.requestId ?? "—"
                    guard try await coordinator.accept(command) else { continue }
                    if let commandZoom = command.zoom {
                        zoom = commandZoom
                        camera.setZoom(commandZoom)
                        model.settings.defaultZoom = commandZoom
                        try? await model.settingsStore.save(model.settings)
                    }
                    status = "CAPTURING"
                    let raw = try await camera.captureBurst()
                    let jpeg = try await ImageProcessor().processToJPEG(raw)
                    guard let image = UIImage(data: jpeg) else {
                        throw ImageProcessingError.invalidImage
                    }
                    let localScan = try await model.saveCapturedPages([
                        .init(jpeg: jpeg, width: Int(image.size.width * image.scale),
                              height: Int(image.size.height * image.scale))
                    ])
                    model.record(scan: localScan, message: "遠隔撮影をローカル保存しました")
                    try await coordinator.beginUpload()
                    status = "UPLOADING"
                    let request = RemoteCaptureUploadRequest(
                        deviceId: model.settings.deviceId,
                        requestId: command.requestId ?? "",
                        sessionId: command.sessionId ?? "",
                        captureId: "ACC-\(Int64(Date().timeIntervalSince1970 * 1000))",
                        capturedAt: Date(),
                        osVersion: UIDevice.current.systemVersion,
                        appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                            as? String) ?? "unknown",
                        dataUrl: "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
                    )
                    do {
                        let response = try await client.upload(request)
                        guard response.ok == true else {
                            throw APIError.transport(response.error ?? "画像送信に失敗しました")
                        }
                    } catch {
                        let payload = try WireCoding.encoder.encode(request)
                        try await PendingUploadQueue(root: AppModel.applicationSupportRoot)
                            .enqueue(.init(id: request.captureId, payload: payload,
                                           reason: error.localizedDescription))
                    }
                    try await coordinator.finishProcessed()
                    await model.refreshPendingCount()
                    status = "WAITING"
                    lastCommunication = Date()
                } catch {
                    status = "ERROR"
                    errorMessage = error.localizedDescription
                    break
                }
            }
        } catch {
            status = "ERROR"
            errorMessage = error.localizedDescription
        }
        cancelScreenWakeTimer()
        waitingTask = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func heartbeat(status: String) -> HeartbeatRequest {
        .init(
            deviceId: model.settings.deviceId,
            status: status,
            osVersion: UIDevice.current.systemVersion,
            appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                as? String) ?? "unknown",
            lastError: errorMessage ?? ""
        )
    }
}

struct SlateView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: 16) {
            Text("Bamboo Slate").font(.title.bold())
            Text(model.settings.savedPeripheralUUID == nil ? "未登録" : "登録済み")
            Text("未確認の登録UUIDバイト順と書き込み順序が実機で確定するまで、Slateへの書き込みは無効です。")
                .font(.callout)
            Button("BLE診断チェックリストを確認") {}
                .buttonStyle(.bordered)
            Text("ページ削除はサーバー成功確認後にのみ許可されます。")
                .font(.caption)
        }
        .padding()
        .navigationTitle("Bamboo Slate")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section("ビューア") {
                TextField("URL", text: $model.settings.viewerURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                SecureField("送信トークン", text: $model.token)
                TextField("遠隔カメラ端末ID", text: $model.settings.deviceId)
            }
            Section("保存先") {
                Text(model.settings.storageBookmark == nil ? "アプリ内" : "Files共有フォルダ")
                Button("Filesフォルダを選択") { showFolderPicker = true }
            }
            Section("カメラ") {
                Toggle("自動撮影", isOn: $model.settings.autoCaptureEnabled)
                Slider(value: $model.settings.defaultZoom, in: 1 ... 5, step: 0.1)
                Text("既定ズーム: \(model.settings.defaultZoom, specifier: "%.1f")x")
                Text("安定判定閾値はiPhone 12実機で校正が必要です").font(.caption)
            }
            Section("Slate") {
                Text(model.settings.savedPeripheralUUID ?? "未登録")
                Button("登録解除", role: .destructive) {
                    model.settings.savedPeripheralUUID = nil
                }
            }
            Button("設定を保存") { Task { await model.saveSettings() } }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .navigationTitle("設定")
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            do {
                let url = try result.get()
                model.settings.storageBookmark = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch { model.errorMessage = "保存先を選択できません: \(error.localizedDescription)" }
        }
    }
}
