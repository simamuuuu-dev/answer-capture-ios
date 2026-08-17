import Foundation
import CoreBluetooth

/// Core Bluetooth integration boundary. Transport callbacks feed this actor; BLE objects and
/// peripheral identifiers are intentionally kept outside the protocol model (no MAC dependency).
public actor SlateCentral {
    public static let knownServiceUUIDs: [CBUUID] = [
        CBUUID(nsuuid: PenzUUIDs.liveService), CBUUID(nsuuid: PenzUUIDs.dfuService),
        CBUUID(nsuuid: PenzUUIDs.fileTransferService), CBUUID(nsuuid: PenzUUIDs.systemEventService)
    ]
    public enum State: Equatable, Sendable { case idle, scanning, connecting, discovering, authenticating, live, downloading, readyToDelete, failed(String) }
    public private(set) var state: State = .idle
    public private(set) var peripheralIdentifier: UUID?
    public private(set) var pendingDeletePageID: String?
    public init() {}
    public func beginScan() { state = .scanning }
    public func discovered(peripheralID: UUID, advertisedServices: [UUID], name: String?, rssi: Int) { peripheralIdentifier = peripheralID; state = .connecting }
    public func didConnect() { state = .discovering }
    public func didDiscoverRequiredServices() { state = .authenticating }
    public func didAuthenticate() { state = .live }
    public func acceptLiveNotification(_ bytes: [UInt8], at timeMs: Int64) -> SlateLiveParseResult { SlateLivePacketParser.parse(bytes, baseTimeMs: timeMs) }
    public func prepareDeletePage(pageID: String, serverUploadSucceeded: Bool) { pendingDeletePageID = serverUploadSucceeded ? pageID : nil; state = serverUploadSucceeded ? .readyToDelete : .live }
    /// Deliberately only returns a frame after the caller has supplied confirmed server success.
    public func confirmedDeleteFrame(serverUploadSucceeded: Bool) -> [UInt8]? { guard serverUploadSucceeded, pendingDeletePageID != nil else { return nil }; return PenzProtocol.deletePageFrame(afterServerSuccess: true) }
    public func reset() { state = .idle; pendingDeletePageID = nil }
}
