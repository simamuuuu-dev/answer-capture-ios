import XCTest
@testable import AnswerCaptureCore
final class RemoteTests:XCTestCase{
 func testSeqDedupAndTransitions()async throws{let defaults=UserDefaults(suiteName:"remote-test")!;defaults.removePersistentDomain(forName:"remote-test");let s=AppSettingsStore(defaults:defaults);let c=try ViewerAPIClient(baseURL:"http://example.test");let r=RemoteCameraCoordinator(settings:s,client:c);await r.start();let command=RemoteCommand(seq:1,type:"CAPTURE_PREVIEW",requestId:"r",sessionId:"s");let accepted=try await r.accept(command);XCTAssertTrue(accepted);let duplicate=try await r.accept(command);XCTAssertFalse(duplicate);try await r.beginUpload();try await r.finishProcessed();let finalState=await r.state;XCTAssertEqual(finalState,.waiting(lastSeq:1))}
}
