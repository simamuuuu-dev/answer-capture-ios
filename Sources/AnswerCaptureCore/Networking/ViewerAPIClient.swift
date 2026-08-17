import Foundation

public enum APIError: Error, Sendable, Equatable {
    case invalidResponse
    case httpStatus(Int, String)
    case decoding
    case transport(String)
}

public struct APIStatusResponse: Decodable, Sendable, Equatable {
    public let ok: Bool?
    public let error: String?

    public init(ok: Bool? = nil, error: String? = nil) {
        self.ok = ok
        self.error = error
    }
}

public actor ViewerAPIClient {
    private let session: URLSession
    private let base: URL
    private let token: String?

    public init(baseURL: String, token: String? = nil, session: URLSession? = nil) throws {
        base = try URLNormalizer.normalize(baseURL)
        let normalizedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = normalizedToken?.isEmpty == false ? normalizedToken : nil
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    public func importImages(
        _ request: AnswerImageImportRequest
    ) async throws -> AnswerImageImportResponse {
        try await send(path: "api/answer-image-watch-import", request: request)
    }

    public func heartbeat(_ request: HeartbeatRequest) async throws -> APIStatusResponse {
        try await send(path: "api/answer-camera/heartbeat", request: request)
    }

    public func upload(_ request: RemoteCaptureUploadRequest) async throws -> APIStatusResponse {
        try await send(path: "api/answer-camera/captures", request: request)
    }

    /// Android deliberately omits the upload-token header for this endpoint.
    /// Keep that behavior until the server authentication contract is confirmed.
    public func sendSlate(_ request: SlatePayload) async throws -> SlatePageResponse {
        try await send(path: "api/slate-capture/pages", request: request, includeToken: false)
    }

    public func commands(
        deviceId: String,
        after: Int64,
        wait: Int = 25
    ) async throws -> RemoteCommandsResponse {
        let url = URLNormalizer.endpoint(
            base: base,
            path: "api/answer-camera/commands",
            query: [
                URLQueryItem(name: "deviceId", value: deviceId),
                URLQueryItem(name: "after", value: String(after)),
                URLQueryItem(name: "wait", value: String(wait))
            ]
        )
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, includeToken: true)
    }

    private func send<Request: Encodable, Response: Decodable>(
        path: String,
        request body: Request,
        includeToken: Bool = true
    ) async throws -> Response {
        var request = URLRequest(
            url: URLNormalizer.endpoint(base: base, path: path),
            timeoutInterval: 60
        )
        request.httpMethod = "POST"
        request.httpBody = try WireCoding.encoder.encode(body)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, includeToken: includeToken)
    }

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        includeToken: Bool
    ) async throws -> Response {
        var request = request
        if includeToken, let token {
            request.setValue(token, forHTTPHeaderField: "X-Answer-Capture-Token")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200 ... 299).contains(http.statusCode) else {
                var body = String(data: data.prefix(4096), encoding: .utf8) ?? "<非UTF-8応答>"
                if let token { body = body.replacingOccurrences(of: token, with: "<redacted>") }
                throw APIError.httpStatus(http.statusCode, body)
            }
            if data.isEmpty, let empty = APIStatusResponse() as? Response {
                return empty
            }
            do { return try WireCoding.decoder.decode(Response.self, from: data) }
            catch { throw APIError.decoding }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(String(describing: error))
        }
    }
}
