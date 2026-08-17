import Foundation

public struct AnswerImagePage: Codable, Sendable, Equatable {
    public let pageIndex: Int
    public let filename: String
    public let dataUrl: String

    public init(pageIndex: Int, filename: String, dataUrl: String) {
        self.pageIndex = pageIndex
        self.filename = filename
        self.dataUrl = dataUrl
    }
}

public struct AnswerImageImportRequest: Codable, Sendable, Equatable {
    public let requiresProblemIdentification: Bool
    public let source: String
    public let captureId: String
    public let filename: String
    public let pageCount: Int
    public let problemIdUnknown: Bool
    public let clientCapturedAt: Date
    public let pages: [AnswerImagePage]

    public init(
        captureId: String,
        capturedAt: Date,
        pages: [AnswerImagePage],
        source: String = "ios_answer_capture_app"
    ) {
        requiresProblemIdentification = true
        self.source = source
        self.captureId = captureId
        filename = "\(captureId).jpg"
        pageCount = pages.count
        problemIdUnknown = true
        clientCapturedAt = capturedAt
        self.pages = pages
    }
}

public struct AnswerImageImportResponse: Decodable, Sendable, Equatable {
    public let ok: Bool?
    public let imported: Int?
    public let skipped: Int?
    public let problemId: String?
    public let requiresProblemIdentification: Bool?
    public let error: String?

    private enum CodingKeys: String, CodingKey {
        case ok, imported, skipped, problemId, requiresProblemIdentification, error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
        imported = try Self.decodeCount(container, key: .imported)
        skipped = try Self.decodeCount(container, key: .skipped)
        problemId = try container.decodeIfPresent(String.self, forKey: .problemId)
        requiresProblemIdentification = try container.decodeIfPresent(
            Bool.self,
            forKey: .requiresProblemIdentification
        )
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    private static func decodeCount(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value ? 1 : 0
        }
        return nil
    }
}

public struct HeartbeatRequest: Codable, Sendable, Equatable {
    public let deviceId: String
    public let status: String
    public let requestId: String?
    public let sessionId: String?
    public let manufacturer: String
    public let model: String
    public let platform: String
    public let osVersion: String
    public let appVersion: String
    public let lastError: String
    public let androidVersion: String

    public init(
        deviceId: String,
        status: String,
        requestId: String? = nil,
        sessionId: String? = nil,
        osVersion: String,
        appVersion: String,
        lastError: String = ""
    ) {
        self.deviceId = deviceId
        self.status = status
        self.requestId = requestId
        self.sessionId = sessionId
        manufacturer = "Apple"
        model = "iPhone 12"
        platform = "ios"
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.lastError = lastError
        androidVersion = osVersion
    }
}

public struct RemoteCaptureUploadRequest: Codable, Sendable, Equatable {
    public let deviceId: String
    public let requestId: String
    public let sessionId: String
    public let captureId: String
    public let capturedAt: Date
    public let manufacturer: String
    public let model: String
    public let platform: String
    public let osVersion: String
    public let androidVersion: String
    public let appVersion: String
    public let dataUrl: String

    public init(
        deviceId: String,
        requestId: String,
        sessionId: String,
        captureId: String,
        capturedAt: Date,
        osVersion: String,
        appVersion: String,
        dataUrl: String
    ) {
        self.deviceId = deviceId
        self.requestId = requestId
        self.sessionId = sessionId
        self.captureId = captureId
        self.capturedAt = capturedAt
        manufacturer = "Apple"
        model = "iPhone 12"
        platform = "ios"
        self.osVersion = osVersion
        androidVersion = osVersion
        self.appVersion = appVersion
        self.dataUrl = dataUrl
    }
}

public struct SlatePageRequest: Codable, Sendable {
    public let problemId: String?
    public let pageId: String
    public let deviceId: String
    public let draftId: String?
    public let captureSequence: Int
    public let createdAt: Date
    public let slateOrientation: String
    public let widthMm: Double
    public let heightMm: Double
    public let paperSize: String
    public let coordinateSpace: WireCoordinateSpace
    public let androidCaptureMode: String
    public let clientPlatform: String
    public let androidCommandDetection: Bool
    public let trigger: String
    public let commandType: String
    public let strokes: [WireSlateStroke]
}

public struct WireCoordinateSpace: Codable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct WireSlateStroke: Codable, Sendable {
    public let strokeId: String
    public let startedAtMs: Int64
    public let endedAtMs: Int64
    public let role: String
    public let commandType: String?
    public let excludedFromAnswer: Bool
    public let points: [WireSlatePoint]
}

public struct WireSlatePoint: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let t: Int64
    public let pressure: Int
}

public struct SlatePageResponse: Codable, Sendable, Equatable {
    public let ok: Bool?
    public let finalized: Bool?
    public let nextPageReady: Bool?
    public let draftId: String?
    public let reason: String?
    public let error: String?
}

public enum RemoteCommandType: String, Codable, Sendable {
    case capturePreview = "CAPTURE_PREVIEW"
}

public struct RemoteCommand: Codable, Sendable, Equatable {
    public let seq: Int64
    public let type: String
    public let requestId: String?
    public let sessionId: String?
    public let zoom: Double?

    public init(
        seq: Int64,
        type: String,
        requestId: String? = nil,
        sessionId: String? = nil,
        zoom: Double? = nil
    ) {
        self.seq = seq
        self.type = type
        self.requestId = requestId
        self.sessionId = sessionId
        self.zoom = zoom
    }
}

/// Android `RemoteCameraActivity` consumes a single optional `command` object.
public struct RemoteCommandsResponse: Codable, Sendable, Equatable {
    public let command: RemoteCommand?
}
