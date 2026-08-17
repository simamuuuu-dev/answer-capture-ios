import CryptoKit
import Foundation

public enum ScanStatus: String, Codable, Sendable { case ready }
public enum StorageMode: String, Codable, Sendable {
    case appSandboxOrDocumentPicker = "app-sandbox-or-document-picker"
}

public struct ScanPage: Codable, Sendable, Equatable {
    public let index: Int
    public let fileName: String
    public let relativePath: String
    public let controlPanelRelativePath: String?
    public let mimeType: String
    public let width: Int
    public let height: Int
    public let sizeBytes: Int
    public let sha256: String
    public let androidUri: String?
    public let platform: String

    public init(index: Int, fileName: String, relativePath: String,
                controlPanelRelativePath: String? = nil, mimeType: String = "image/jpeg",
                width: Int, height: Int, sizeBytes: Int, sha256: String,
                androidUri: String? = nil, platform: String = "ios") {
        self.index = index
        self.fileName = fileName
        self.relativePath = relativePath
        self.controlPanelRelativePath = controlPanelRelativePath
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.androidUri = androidUri
        self.platform = platform
    }

    private enum CodingKeys: String, CodingKey {
        case index, fileName, relativePath, controlPanelRelativePath, mimeType
        case width, height, sizeBytes, sha256, androidUri, platform
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encodeIfPresent(controlPanelRelativePath, forKey: .controlPanelRelativePath)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(sizeBytes, forKey: .sizeBytes)
        try container.encode(sha256, forKey: .sha256)
        if let androidUri { try container.encode(androidUri, forKey: .androidUri) }
        else { try container.encodeNil(forKey: .androidUri) }
        try container.encode(platform, forKey: .platform)
    }
}

public struct ScanRecord: Codable, Sendable, Equatable {
    public let schema: String
    public let id: String
    public let createdAt: Date
    public let source: String
    public let status: ScanStatus
    public let storageMode: StorageMode
    public let scanFolder: String
    public let imageFolder: String
    public let metadataFolder: String
    public let pageCount: Int
    public let pages: [ScanPage]

    public init(id: String, createdAt: Date, storageMode: StorageMode,
                pages: [ScanPage], source: String = "ios-answer-capture") {
        schema = "answer-capture.scan.v1"
        self.id = id
        self.createdAt = createdAt
        self.source = source
        status = .ready
        self.storageMode = storageMode
        scanFolder = "AnswerCapture/\(id)"
        imageFolder = "AnswerCapture/\(id)"
        metadataFolder = "AnswerCapture/\(id)"
        pageCount = pages.count
        self.pages = pages
    }
}

public struct ManifestRecord: Codable, Sendable, Equatable {
    public let schema: String
    public let id: String
    public let createdAt: Date
    public let status: ScanStatus
    public let storageMode: StorageMode
    public let imageBaseFolder: String
    public let metadataBaseFolder: String
    public let pageCount: Int
    public let scanFolder: String
    public let imageFolder: String
    public let metadataFolder: String
    public let scanJson: String
    public let pages: [ScanPage]

    public init(scan: ScanRecord) {
        schema = "answer-capture.manifest.v1"
        id = scan.id
        createdAt = scan.createdAt
        status = scan.status
        storageMode = scan.storageMode
        imageBaseFolder = scan.imageFolder
        metadataBaseFolder = scan.metadataFolder
        pageCount = scan.pageCount
        scanFolder = scan.scanFolder
        imageFolder = scan.imageFolder
        metadataFolder = scan.metadataFolder
        scanJson = "\(scan.scanFolder)/scan.json"
        pages = scan.pages
    }
}

public enum CaptureID {
    public static func make(now: Date = Date(), random: String = String(
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
    ).lowercased()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return "\(formatter.string(from: now))_\(random)"
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum WireCoding {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(format(date))
        }
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = parse(value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date"
                )
            }
            return date
        }
        return decoder
    }

    public static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter.string(from: date)
    }

    public static func parse(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
