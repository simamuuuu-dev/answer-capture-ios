import Foundation

public enum PenzCommand: UInt8 {
    case checkAuth = 0xE6, register = 0xE7, registerComplete = 0xE5, buttonConfirm = 0xE4
    case setTime = 0xB6, getBattery = 0xB9, setMode = 0xB1, selectTransfer = 0xEC
    case getFileCount = 0xC1, getStrokeInfo = 0xCC, startDownload = 0xC3, deletePage = 0xCA
}

public enum PenzResponse: UInt8 {
    case fileCount = 0xC2, strokeInfo = 0xCF, downloadStatus = 0xC8
}

public enum PenzMode: UInt8 { case live = 0, paper = 1, idle = 2 }
public enum PenzOpcode: UInt8 { case penData = 0xA1, penProximity = 0xA2, buttonPress = 0xCB }

/// Exact Android framing: `[opcode, unsigned body length, body...]`. No checksum is present.
public enum PenzProtocol {
    public static func buildFrame(_ opcode: UInt8, data: [UInt8] = []) -> [UInt8] {
        precondition(data.count <= 255, "Penz frame body exceeds one-byte length")
        return [opcode, UInt8(data.count)] + data
    }
    public static func authFrame(_ registeredUUID: [UInt8]) -> [UInt8] { buildFrame(PenzCommand.checkAuth.rawValue, data: registeredUUID) }
    public static func registerFrame(_ registeredUUID: [UInt8]) -> [UInt8] { buildFrame(PenzCommand.register.rawValue, data: registeredUUID) }
    public static func registerCompleteFrame(_ registeredUUID: [UInt8]) -> [UInt8] { buildFrame(PenzCommand.registerComplete.rawValue, data: registeredUUID) }
    public static func modeCommand(_ mode: PenzMode) -> [UInt8] { [PenzCommand.setMode.rawValue, 1, mode.rawValue] }
    public static func setTimeFrame(date: Date = Date(), calendar: Calendar = .current) -> [UInt8] {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return buildFrame(PenzCommand.setTime.rawValue, data: [UInt8((c.year ?? 0) % 100), UInt8(c.month ?? 0), UInt8(c.day ?? 0), UInt8(c.hour ?? 0), UInt8(c.minute ?? 0), UInt8(c.second ?? 0)])
    }
    public static func getBatteryFrame() -> [UInt8] { [PenzCommand.getBattery.rawValue, 1, 0] }
    public static func selectFileTransferFrame() -> [UInt8] { buildFrame(PenzCommand.selectTransfer.rawValue, data: [6, 0, 0, 0, 0, 0]) }
    public static func zeroArgFrame(_ opcode: UInt8) -> [UInt8] { buildFrame(opcode, data: [0]) }
    public static func liveModeEnableSequence(_ registeredUUID: [UInt8]) -> [[UInt8]] {
        let mode = modeCommand(.live)
        return [mode, mode, mode, authFrame(registeredUUID), mode]
    }
    /// DELETE_PAGE is intentionally unavailable without an explicit confirmed server-success capability.
    public static func deletePageFrame(afterServerSuccess confirmed: Bool) -> [UInt8]? {
        confirmed ? zeroArgFrame(PenzCommand.deletePage.rawValue) : nil
    }
    public static func uuidHexToBytes(_ value: String) -> [UInt8] {
        let clean = value.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(clean.count.isMultiple(of: 2), "odd hex length")
        var result: [UInt8] = []; result.reserveCapacity(clean.count / 2)
        var i = clean.startIndex
        while i < clean.endIndex {
            let j = clean.index(i, offsetBy: 2)
            guard let b = UInt8(clean[i..<j], radix: 16) else { preconditionFailure("invalid hex") }
            result.append(b); i = j
        }
        return result
    }
}
