import AnswerCaptureCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var token = ""
    @Published var pendingCount = 0
    @Published var lastCaptureID: String?
    @Published var lastMessage = "未実行"
    @Published var errorMessage: String?
    @Published var isRetrying = false

    let settingsStore = AppSettingsStore()
    let credentialStore = CredentialStore()
    private var retryTask: Task<Void, Never>?

    func load() async {
        settings = await settingsStore.load()
        token = (try? await credentialStore.token()) ?? ""
        await refreshPendingCount()
        startRetryLoop()
    }

    func saveSettings() async {
        do {
            settings.viewerURL = try URLNormalizer.normalize(settings.viewerURL).absoluteString
            try await settingsStore.save(settings)
            try await credentialStore.setToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
            lastMessage = "設定を保存しました"
        } catch {
            errorMessage = "設定を保存できません: \(error.localizedDescription)"
        }
    }

    func record(scan: ScanRecord, message: String) {
        lastCaptureID = scan.id
        lastMessage = message
    }

    func saveCapturedPages(_ pages: [CapturedPageData]) async throws -> ScanRecord {
        guard let bookmark = settings.storageBookmark else {
            return try await ScanRepository().saveCapturedPages(pages)
        }
        var stale = false
        let selectedFolder = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard !stale else { throw AppStorageError.bookmarkExpired }
        let accessing = selectedFolder.startAccessingSecurityScopedResource()
        guard accessing else { throw AppStorageError.accessDenied }
        defer { selectedFolder.stopAccessingSecurityScopedResource() }
        let root = selectedFolder.appendingPathComponent("AnswerCapture", isDirectory: true)
        return try await ScanRepository(root: root).saveCapturedPages(pages)
    }

    func saveCapturedPagesAndUpload(
        _ pages: [CapturedPageData]
    ) async throws -> (scan: ScanRecord, uploaded: Bool) {
        let scan = try await saveCapturedPages(pages)
        let request = AnswerImageImportRequest(
            captureId: scan.id,
            capturedAt: scan.createdAt,
            pages: zip(scan.pages, pages).map { record, page in
                AnswerImagePage(
                    pageIndex: record.index,
                    filename: record.fileName,
                    dataUrl: "data:image/jpeg;base64,\(page.jpeg.base64EncodedString())"
                )
            }
        )
        do {
            let client = try ViewerAPIClient(baseURL: settings.viewerURL, token: token)
            let response = try await client.importImages(request)
            guard response.ok == true else {
                throw APIError.transport(response.error ?? "答案画像の取り込みが拒否されました")
            }
            return (scan, true)
        } catch {
            let queued = PendingUpload(
                id: scan.id,
                payload: try WireCoding.encoder.encode(request),
                reason: error.localizedDescription,
                kind: .imageImport
            )
            try await PendingUploadQueue(root: Self.applicationSupportRoot).enqueue(queued)
            await refreshPendingCount()
            return (scan, false)
        }
    }

    func refreshPendingCount() async {
        let queue = PendingUploadQueue(root: Self.applicationSupportRoot)
        pendingCount = (try? await queue.status())?.count ?? 0
    }

    func retryPendingUploads() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        do {
            let queue = PendingUploadQueue(root: Self.applicationSupportRoot)
            let client = try ViewerAPIClient(baseURL: settings.viewerURL, token: token)
            var failures = 0
            let pendingItems = try await queue.listPending()
            for item in pendingItems {
                guard !Task.isCancelled else { break }
                do {
                    switch item.kind {
                    case .remoteCapture:
                        let request = try WireCoding.decoder.decode(
                            RemoteCaptureUploadRequest.self,
                            from: item.payload
                        )
                        let response = try await client.upload(request)
                        guard response.ok == true else {
                            throw APIError.transport(response.error ?? "遠隔画像の送信が拒否されました")
                        }
                    case .imageImport:
                        let request = try WireCoding.decoder.decode(
                            AnswerImageImportRequest.self,
                            from: item.payload
                        )
                        let response = try await client.importImages(request)
                        guard response.ok == true else {
                            throw APIError.transport(response.error ?? "答案画像の取り込みが拒否されました")
                        }
                    case .slatePage:
                        let request = try WireCoding.decoder.decode(SlatePayload.self, from: item.payload)
                        let response = try await client.sendSlate(request)
                        if PendingUploadQueue.isTerminalRejectionReason(response.reason) {
                            try await queue.reject(PendingUpload(
                                id: item.id,
                                payload: item.payload,
                                reason: response.reason,
                                createdAt: item.createdAt,
                                kind: item.kind
                            ))
                            continue
                        }
                        guard response.ok == true else {
                            throw APIError.transport(response.error ?? "Slateページの送信が拒否されました")
                        }
                    }
                    try await queue.removeAfterConfirmedSuccess(item.id)
                } catch {
                    failures += 1
                }
            }
            await refreshPendingCount()
            lastMessage = failures == 0
                ? "未送信データの再送を完了しました"
                : "未送信データのうち\(failures)件を再送できませんでした"
        } catch {
            lastMessage = "未送信データを確認できません: \(error.localizedDescription)"
        }
    }

    private func startRetryLoop() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            await self?.retryPendingUploads()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self?.retryPendingUploads()
            }
        }
    }

    static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AnswerCapture", isDirectory: true)
    }
}

enum AppStorageError: LocalizedError {
    case bookmarkExpired, accessDenied
    var errorDescription: String? {
        switch self {
        case .bookmarkExpired: "保存先の許可が失効しました。設定から選び直してください。"
        case .accessDenied: "保存先へアクセスできません。設定から選び直してください。"
        }
    }
}
