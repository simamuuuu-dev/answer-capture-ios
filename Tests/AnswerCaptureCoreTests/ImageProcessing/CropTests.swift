import XCTest
@testable import AnswerCaptureCore
final class CropTests: XCTestCase { func testPresetsAreValid() { for p in CropPreset.allCases { XCTAssertTrue(CropValidator.isValid(p.rect())) } }; func testTooSmallOrOutsideIsInvalid() { XCTAssertFalse(CropValidator.isValid(.init(x: 0, y: 0, width: 0.04, height: 0.5))); XCTAssertFalse(CropValidator.isValid(.init(x: 0.8, y: 0, width: 0.3, height: 0.5))) } }
