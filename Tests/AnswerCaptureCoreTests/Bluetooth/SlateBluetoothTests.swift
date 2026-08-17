import XCTest
@testable import AnswerCaptureCore

final class SlateBluetoothTests: XCTestCase {
    func testSyntheticVerifiedFrames() {
        XCTAssertEqual(PenzProtocol.buildFrame(0xB1, data: [0]), [0xB1, 0x01, 0x00])
        XCTAssertEqual(PenzProtocol.selectFileTransferFrame(), [0xEC, 0x06, 0x06, 0, 0, 0, 0, 0])
        XCTAssertNil(PenzProtocol.deletePageFrame(afterServerSuccess: false))
        XCTAssertEqual(PenzProtocol.uuidHexToBytes("00-01 af").count, 3)
    }
    func testSyntheticLiveLittleEndianAndPenUp() {
        let packet:[UInt8] = [0xA1, 0x06, 0x10, 0x00, 0x20, 0x00, 0xFF, 0x03]
        let r=SlateLivePacketParser.parse(packet,baseTimeMs:100); XCTAssertEqual(r.kind,.penData); XCTAssertEqual(r.points.first?.x,16); XCTAssertEqual(r.points.first?.y,32); XCTAssertEqual(r.points.first?.pressure,1023.0/2047.0)
        XCTAssertEqual(SlateLivePacketParser.parse([0xA1,0x06,0xff,0xff,0xff,0xff,0xff,0xff],baseTimeMs:0).kind,.penUp)
    }
    func testSyntheticStoredPageMagicAbsolutePointAndSeparator() {
        // Synthetic fixture: Android StoredSlatePageParser masks 0xFC => three 16-bit absolute values.
        let bytes:[UInt8]=[0x62,0x38,0x62,0x74,0xFC,0x10,0,0x20,0,0x2F,0,0x3F,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF]
        let page=StoredSlatePageParser.parse(bytes,pageId:"fixture",baseTimeMs:1000)
        XCTAssertTrue(page.magicOK); XCTAssertEqual(page.strokes.count,1); XCTAssertEqual(page.strokes[0].points[0].x,16); XCTAssertEqual(page.strokes[0].points[0].y,32); XCTAssertEqual(page.strokes[0].points[0].pressure,47.0/2047.0)
    }
    func testSyntheticOrientationAndFalsePositiveRejection() {
        let p=SlatePoint(x:0.2,y:0.3,tMs:0,pressure:0.5); XCTAssertEqual(SlateGestureRecognizer.normalize(p,settings:.init(orientation:.buttonBottom)),SlatePoint(x:0.8,y:0.7,tMs:0,pressure:0.5)); XCTAssertEqual(SlateGestureRecognizer.normalize(p,settings:.init(orientation:.buttonRight)),SlatePoint(x:0.7,y:0.2,tMs:0,pressure:0.5))
        let short=SlateStroke(strokeId:"answer",points:[.init(x:9000,y:13000,tMs:0,pressure:1),.init(x:9050,y:13010,tMs:50,pressure:1)],startedAtMs:0,endedAtMs:50); XCTAssertFalse(SlateGestureRecognizer.detect([short]).accepted)
    }
    func testSyntheticPayloadRetainsAndroidKeysAndExcludesCommand() throws {
        let answer=SlateStroke(strokeId:"a",points:[.init(x:100,y:100,tMs:0,pressure:0.5)],startedAtMs:0,endedAtMs:0); let p=SlatePayloadFactory.live(problemId:"P",strokes:[answer],deviceId:"D",captureSequence:1000); let json=try JSONEncoder().encode(p); let s=String(data:json,encoding:.utf8)!; XCTAssertTrue(s.contains("androidCaptureMode")); XCTAssertTrue(s.contains("coordinateSpace")); XCTAssertTrue(s.contains("excludedFromAnswer"))
        XCTAssertTrue(s.contains("clientPlatform"))
    }
    func testFinalizeCommandWithoutAnswerIsRejected() {
        let command=SlateStroke(strokeId:"cmd",points:[
            .init(x:0.90,y:0.88,tMs:0,pressure:1),
            .init(x:0.90,y:0.92,tMs:100,pressure:1),
            .init(x:0.90,y:0.95,tMs:200,pressure:1),
            .init(x:0.97,y:0.95,tMs:300,pressure:1)
        ],startedAtMs:0,endedAtMs:300)
        let detection=SlateGestureRecognizer.detect([command])
        XCTAssertFalse(detection.accepted)
        XCTAssertEqual(detection.reason,"empty_answer")
    }
}
