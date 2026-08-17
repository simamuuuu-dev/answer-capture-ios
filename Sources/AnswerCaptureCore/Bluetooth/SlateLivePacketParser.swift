import Foundation

public enum SlateLivePacketKind: Equatable, Sendable { case none, penData, penUp, penProximity, buttonPress }
public struct SlateLiveParseResult: Sendable { public let kind: SlateLivePacketKind; public let points: [SlatePoint] }

public enum SlateLivePacketParser {
    public static func parse(_ data: [UInt8], baseTimeMs: Int64) -> SlateLiveParseResult {
        guard let opcode = data.first else { return .init(kind: .none, points: []) }
        if opcode == PenzOpcode.penProximity.rawValue { return .init(kind: .penProximity, points: []) }
        if opcode == PenzOpcode.buttonPress.rawValue { return .init(kind: .buttonPress, points: []) }
        guard opcode == PenzOpcode.penData.rawValue, data.count >= 2 else { return .init(kind: .none, points: []) }
        let payload = Array(data.dropFirst(2))
        if payload.count >= 6 && payload.allSatisfy({ $0 == 0xff }) { return .init(kind: .penUp, points: []) }
        let points = parseSixByteSamples(data, offset: 2, baseTimeMs: baseTimeMs)
        return .init(kind: points.isEmpty ? .none : .penData, points: points)
    }
    public static func parseSixByteSamples(_ data: [UInt8], offset: Int = 0, baseTimeMs: Int64) -> [SlatePoint] {
        guard offset >= 0, data.count - offset >= 6 else { return [] }
        let usable = ((data.count - offset) / 6) * 6
        return stride(from: offset, to: offset + usable, by: 6).compactMap { i in
            let x = UInt16(data[i]) | UInt16(data[i+1]) << 8; let y = UInt16(data[i+2]) | UInt16(data[i+3]) << 8; let p = UInt16(data[i+4]) | UInt16(data[i+5]) << 8
            guard Int(x) <= SlateConstants.coordinateWidth, Int(y) <= SlateConstants.coordinateHeight, Int(p) <= SlateConstants.pressureMax else { return nil }
            return SlatePoint(x: Double(x), y: Double(y), tMs: baseTimeMs + Int64((i-offset)/6), pressure: Double(p) / Double(SlateConstants.pressureMax))
        }
    }
}
