import XCTest
@testable import AnswerCaptureCore
final class NetworkingTests:XCTestCase{
 func testURLNormalization()throws{XCTAssertEqual(try URLNormalizer.normalize(" http://example.test///").absoluteString,"http://example.test");XCTAssertThrowsError(try URLNormalizer.normalize("ftp://example.test"))}
 func testHeartbeatCompatibilityKeys()throws{let r=HeartbeatRequest(deviceId:"d",status:"WAITING",osVersion:"26.5.2",appVersion:"1");let s=String(decoding:try WireCoding.encoder.encode(r),as:UTF8.self);XCTAssertTrue(s.contains("androidVersion"));XCTAssertTrue(s.contains("manufacturer"))}
 func testAndroidSingleCommandEnvelope()throws{let data=Data(#"{"command":{"seq":4,"type":"CAPTURE_PREVIEW","requestId":"r","sessionId":"s"}}"#.utf8);let response=try WireCoding.decoder.decode(RemoteCommandsResponse.self,from:data);XCTAssertEqual(response.command?.seq,4);XCTAssertEqual(response.command?.type,"CAPTURE_PREVIEW")}
 func testFlexibleImportCounts()throws{let data=Data(#"{"ok":true,"imported":true,"skipped":0}"#.utf8);let response=try WireCoding.decoder.decode(AnswerImageImportResponse.self,from:data);XCTAssertEqual(response.imported,1);XCTAssertEqual(response.skipped,0)}
 func testImageImportIncludesAndroidFilenameAndMillisecondDate()throws{let r=AnswerImageImportRequest(captureId:"capture",capturedAt:Date(timeIntervalSince1970:0),pages:[]);let data=try WireCoding.encoder.encode(r);let json=String(decoding:data,as:UTF8.self);XCTAssertTrue(json.contains(#""filename":"capture.jpg""#));XCTAssertNotNil(json.range(of:#""clientCapturedAt":"[^"]+\.\d{3}(Z|[+-]\d{2}:\d{2})"#,options:.regularExpression))}
}
