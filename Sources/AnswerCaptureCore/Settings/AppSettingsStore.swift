import Foundation

public struct AppSettings: Codable, Sendable, Equatable {
    public var viewerURL: String
    public var deviceId: String
    public var defaultZoom: Double
    public var autoCaptureEnabled: Bool
    public var savedPeripheralUUID: String?
    public var lastRemoteSeq: Int64
    public var storageBookmark: Data?

    public init(
        viewerURL: String = "http://192.168.0.10:8785",
        deviceId: String = "answer-camera-iphone12",
        defaultZoom: Double = 1,
        autoCaptureEnabled: Bool = true,
        savedPeripheralUUID: String? = nil,
        lastRemoteSeq: Int64 = 0,
        storageBookmark: Data? = nil
    ) {
        self.viewerURL = viewerURL
        self.deviceId = deviceId
        self.defaultZoom = defaultZoom
        self.autoCaptureEnabled = autoCaptureEnabled
        self.savedPeripheralUUID = savedPeripheralUUID
        self.lastRemoteSeq = lastRemoteSeq
        self.storageBookmark = storageBookmark
    }
}
public actor AppSettingsStore {
    private let defaults: UserDefaults; private let key = "answer-capture.settings.v1"; private var cached: AppSettings?
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> AppSettings { if let cached { return cached }; guard let d = defaults.data(forKey: key), let value = try? JSONDecoder().decode(AppSettings.self, from: d) else { let value = AppSettings(); cached=value; return value }; cached=value; return value }
    public func save(_ settings: AppSettings) throws { let d = try JSONEncoder().encode(settings); defaults.set(d, forKey: key); cached=settings }
    public func update(_ change: @Sendable (inout AppSettings) -> Void) throws { var s=load(); change(&s); try save(s) }
}
