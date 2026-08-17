import Foundation
public struct OCRMetrics: Sendable, Equatable { public let observations: Int; public let lines: Int; public let tokens: Int; public let characters: Int; public let duration: TimeInterval }
public enum OCRMetricsCalculator {
    public static func calculate(text: String, observations: Int, duration: TimeInterval) -> OCRMetrics {
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let tokens = text.split { $0.isWhitespace || $0.isPunctuation }.count
        return .init(observations: observations, lines: lines, tokens: tokens, characters: text.count, duration: duration)
    }
}
