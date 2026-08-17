import XCTest
@testable import AnswerCaptureCore
final class OCRMetricsTests: XCTestCase { func testMetrics() { let m = OCRMetricsCalculator.calculate(text: "一行目\n二行目。", observations: 2, duration: 0.4); XCTAssertEqual(m.observations, 2); XCTAssertEqual(m.lines, 2); XCTAssertEqual(m.characters, 7); XCTAssertGreaterThanOrEqual(m.tokens, 2) } }
