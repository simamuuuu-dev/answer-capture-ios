import Foundation

public enum SlateConstants {
    public static let coordinateWidth = 21600
    public static let coordinateHeight = 14700
    public static let pressureMax = 2047
}
public struct SlatePoint: Codable, Equatable, Sendable { public let x: Double; public let y: Double; public let tMs: Int64; public let pressure: Double; public init(x: Double, y: Double, tMs: Int64, pressure: Double) { self.x=x; self.y=y; self.tMs=tMs; self.pressure=pressure } }
public struct SlateStroke: Codable, Equatable, Sendable { public let strokeId: String; public let points: [SlatePoint]; public let startedAtMs: Int64; public let endedAtMs: Int64; public init(strokeId: String, points: [SlatePoint], startedAtMs: Int64, endedAtMs: Int64) { self.strokeId=strokeId.isEmpty ? "stroke" : strokeId; self.points=points; self.startedAtMs=startedAtMs; self.endedAtMs=endedAtMs } }
public enum SlateOrientation: String, Codable, Sendable { case buttonTop = "button_top", buttonBottom = "button_bottom", buttonLeft = "button_left", buttonRight = "button_right" }
public struct SlateGestureSettings: Sendable { public let pageWidthMm: Double; public let pageHeightMm: Double; public let sourceWidth: Double; public let sourceHeight: Double; public let orientation: SlateOrientation; public init(pageWidthMm: Double=210, pageHeightMm: Double=297, sourceWidth: Double=10000, sourceHeight: Double=14000, orientation: SlateOrientation = .buttonTop) { self.pageWidthMm=max(1,pageWidthMm); self.pageHeightMm=max(1,pageHeightMm); self.sourceWidth=max(1,sourceWidth); self.sourceHeight=max(1,sourceHeight); self.orientation=orientation } }
public struct SlateDetection: Equatable, Sendable { public let accepted: Bool; public let kind: String; public let reason: String; public let commandStrokeIds: [String] }
public struct SlateStoredPage: Sendable { public let pageId: String; public let strokes: [SlateStroke]; public let magicOK: Bool; public let byteCount: Int; public var pointCount: Int { strokes.reduce(0) { $0 + $1.points.count } } }
public struct SlateCommandDetectionPayload: Codable, Equatable, Sendable { public let accepted: Bool; public let kind: String; public let reason: String; public let commandStrokeIds: [String] }
public struct SlatePayload: Codable, Equatable, Sendable {
    public let problemId: String; public let pageId: String; public let deviceId: String; public let draftId: String; public let captureSequence: Int64; public let createdAt: String; public let slateOrientation: SlateOrientation; public let paperSize: PaperSize; public let coordinateSpace: CoordinateSpace; public let androidCaptureMode: String?; public let clientPlatform: String; public let storedPage: StoredPageMeta?; public let androidCommandDetection: SlateCommandDetectionPayload; public let trigger: String; public let commandType: String?; public let strokes: [SlatePayloadStroke]
    public struct PaperSize: Codable, Equatable, Sendable { public let widthMm: Double; public let heightMm: Double }
    public struct CoordinateSpace: Codable, Equatable, Sendable { public let width: Double; public let height: Double }
    public struct StoredPageMeta: Codable, Equatable, Sendable { public let byteCount: Int; public let magicOk: Bool; public let strokeCount: Int; public let pointCount: Int }
    public struct SlatePayloadStroke: Codable, Equatable, Sendable { public let strokeId: String; public let startedAtMs: Int64; public let endedAtMs: Int64; public let role: String; public let commandType: String?; public let excludedFromAnswer: Bool; public let points: [PayloadPoint] }
    public struct PayloadPoint: Codable, Equatable, Sendable { public let x: Int; public let y: Int; public let t: Int64; public let pressure: Double }
}
