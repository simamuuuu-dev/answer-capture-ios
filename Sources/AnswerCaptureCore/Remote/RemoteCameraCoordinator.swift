import Foundation

public enum RemoteCameraState: Equatable, Sendable {
    case offline
    case waiting(lastSeq: Int64)
    case capturing(seq: Int64, requestId: String, sessionId: String)
    case uploading(seq: Int64, requestId: String, sessionId: String)
    case error(message: String, retryAfter: TimeInterval)
}

public enum RemoteStateError: Error, Sendable { case busy, noActiveCommand }

public actor RemoteCameraCoordinator {
    public private(set) var state: RemoteCameraState = .offline
    private var committedSeq: Int64
    private var activeCommand: RemoteCommand?
    private let settings: AppSettingsStore
    private let client: ViewerAPIClient

    public init(
        settings: AppSettingsStore,
        client: ViewerAPIClient,
        lastSeq: Int64 = 0
    ) {
        self.settings = settings
        self.client = client
        committedSeq = lastSeq
    }

    public func start() async {
        committedSeq = max(committedSeq, (await settings.load()).lastRemoteSeq)
        state = .waiting(lastSeq: committedSeq)
    }

    public func stop() {
        activeCommand = nil
        state = .offline
    }

    public func poll(deviceId: String) async throws -> RemoteCommand? {
        guard case .waiting = state else { throw RemoteStateError.busy }
        return try await client.commands(deviceId: deviceId, after: committedSeq).command
    }

    public func accept(_ command: RemoteCommand) throws -> Bool {
        let inFlightSeq = activeCommand?.seq ?? committedSeq
        guard command.seq > max(committedSeq, inFlightSeq) else { return false }
        guard command.type == RemoteCommandType.capturePreview.rawValue else { return false }
        guard case .waiting = state else { throw RemoteStateError.busy }
        activeCommand = command
        state = .capturing(
            seq: command.seq,
            requestId: command.requestId ?? "",
            sessionId: command.sessionId ?? ""
        )
        return true
    }

    public func beginUpload() throws {
        guard case let .capturing(seq, requestId, sessionId) = state else {
            throw RemoteStateError.noActiveCommand
        }
        state = .uploading(seq: seq, requestId: requestId, sessionId: sessionId)
    }

    /// Call only after upload succeeds or the exact captured payload is durably queued.
    public func finishProcessed() async throws {
        guard let command = activeCommand else { throw RemoteStateError.noActiveCommand }
        guard case .uploading = state else { throw RemoteStateError.noActiveCommand }
        try await settings.update { $0.lastRemoteSeq = command.seq }
        committedSeq = command.seq
        activeCommand = nil
        state = .waiting(lastSeq: committedSeq)
    }

    public func fail(_ message: String, retryAfter: TimeInterval) {
        state = .error(message: message, retryAfter: min(30, max(1, retryAfter)))
    }

    /// Retry the same in-memory command without accepting a duplicate from the server.
    public func retryActiveCommand() throws {
        guard let command = activeCommand else { throw RemoteStateError.noActiveCommand }
        state = .capturing(
            seq: command.seq,
            requestId: command.requestId ?? "",
            sessionId: command.sessionId ?? ""
        )
    }
}
