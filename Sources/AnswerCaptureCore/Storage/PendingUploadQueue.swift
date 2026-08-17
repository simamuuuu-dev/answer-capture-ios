import Foundation

public enum PendingUploadKind: String, Codable, Sendable, Equatable {
    case remoteCapture
    case imageImport
    case slatePage
}

public struct PendingUpload: Codable, Sendable, Equatable {
    public let id: String
    public let payload: Data
    public let reason: String?
    public let createdAt: Date
    public let kind: PendingUploadKind

    public init(
        id: String,
        payload: Data,
        reason: String? = nil,
        createdAt: Date = Date(),
        kind: PendingUploadKind = .remoteCapture
    ) {
        self.id = id
        self.payload = payload
        self.reason = reason
        self.createdAt = createdAt
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case id, payload, reason, createdAt, kind }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        payload = try container.decode(Data.self, forKey: .payload)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decodeIfPresent(PendingUploadKind.self, forKey: .kind)
            ?? .remoteCapture
    }
}

public struct PendingQueueSnapshot: Sendable, Equatable {
    public let count: Int
    public let bytes: Int64
    public let isOverLimit: Bool
}

public enum PendingQueueError: Error, Sendable, Equatable {
    case limitExceeded(count: Int, bytes: Int64)
}

public actor PendingUploadQueue {
    public static let maximumCount = 200
    public static let maximumBytes: Int64 = 500 * 1024 * 1024

    public let pendingURL: URL
    public let rejectedURL: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        pendingURL = root.appendingPathComponent("Pending", isDirectory: true)
        rejectedURL = root.appendingPathComponent("Rejected", isDirectory: true)
    }

    public func enqueue(_ item: PendingUpload) throws {
        let encoded = try WireCoding.encoder.encode(item)
        let existingURL = pendingURL.appendingPathComponent("\(item.id).json")
        let existingSize = (try? existingURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let snapshot = try status()
        let nextCount = snapshot.count + (fileManager.fileExists(atPath: existingURL.path) ? 0 : 1)
        let nextBytes = snapshot.bytes - Int64(existingSize) + Int64(encoded.count)
        guard nextCount <= Self.maximumCount, nextBytes <= Self.maximumBytes else {
            throw PendingQueueError.limitExceeded(count: nextCount, bytes: nextBytes)
        }
        try AtomicFile.write(encoded, to: existingURL, fileManager: fileManager)
    }

    public func reject(_ item: PendingUpload) throws {
        let data = try WireCoding.encoder.encode(item)
        try AtomicFile.write(
            data,
            to: rejectedURL.appendingPathComponent("\(item.id).json"),
            fileManager: fileManager
        )
        try remove(item.id, from: pendingURL)
    }

    public func listPending() throws -> [PendingUpload] { try list(pendingURL) }
    public func removeAfterConfirmedSuccess(_ id: String) throws { try remove(id, from: pendingURL) }

    public func status() throws -> PendingQueueSnapshot {
        guard fileManager.fileExists(atPath: pendingURL.path) else {
            return .init(count: 0, bytes: 0, isOverLimit: false)
        }
        let urls = try fileManager.contentsOfDirectory(
            at: pendingURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ).filter { $0.pathExtension == "json" }
        let bytes = try urls.reduce(Int64(0)) { total, url in
            total + Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        return .init(
            count: urls.count,
            bytes: bytes,
            isOverLimit: urls.count > Self.maximumCount || bytes > Self.maximumBytes
        )
    }

    public static func isTerminalRejectionReason(_ reason: String?) -> Bool {
        guard let reason else { return false }
        return ["no_finalize_command", "empty_answer", "no_strokes"].contains(reason)
    }

    private func list(_ folder: URL) throws -> [PendingUpload] {
        guard fileManager.fileExists(atPath: folder.path) else { return [] }
        return try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try WireCoding.decoder.decode(PendingUpload.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func remove(_ id: String, from folder: URL) throws {
        let url = folder.appendingPathComponent("\(id).json")
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }
}
