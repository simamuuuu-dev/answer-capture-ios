import Foundation

public struct StabilityThresholds: Sendable, Equatable {
    public var motionLimit: Double
    public var requiredDuration: TimeInterval
    public var minimumFrames: Int
    public var warmupDuration: TimeInterval

    /// The default is deliberately conservative for Core Motion units. It must be
    /// calibrated on an iPhone 12; Android's CameraX threshold is not reused.
    public init(motionLimit: Double = 0.025, requiredDuration: TimeInterval = 1.8, minimumFrames: Int = 10, warmupDuration: TimeInterval = 2.5) {
        self.motionLimit = motionLimit; self.requiredDuration = requiredDuration
        self.minimumFrames = minimumFrames; self.warmupDuration = warmupDuration
    }
}

public struct MotionSample: Sendable, Equatable { public let time: TimeInterval; public let magnitude: Double; public init(time: TimeInterval, magnitude: Double) { self.time = time; self.magnitude = magnitude } }

public struct StabilityEvaluator: Sendable {
    public let thresholds: StabilityThresholds
    public init(thresholds: StabilityThresholds = .init()) { self.thresholds = thresholds }

    public func isWarmedUp(at time: TimeInterval, startedAt: TimeInterval) -> Bool { time - startedAt >= thresholds.warmupDuration }
    public func isStable(_ samples: [MotionSample], now: TimeInterval) -> Bool {
        guard let first = samples.first, let last = samples.last,
              samples.count >= thresholds.minimumFrames,
              now - first.time >= thresholds.requiredDuration,
              last.time - first.time >= thresholds.requiredDuration else { return false }
        return samples.allSatisfy { $0.magnitude <= thresholds.motionLimit }
    }
}

public struct SharpnessCandidate: Sendable, Equatable { public let index: Int; public let score: Double; public init(index: Int, score: Double) { self.index = index; self.score = score } }

public enum SharpnessSelector {
    public static func best(in candidates: [SharpnessCandidate]) -> SharpnessCandidate? {
        guard !candidates.isEmpty else { return nil }
        let maximum = candidates.map(\.score).max() ?? -.infinity
        let tied = candidates.filter { $0.score == maximum }
        let center = (candidates.count - 1) / 2
        return tied.min { abs($0.index - center) < abs($1.index - center) || ($0.index == $1.index && $0.index < $1.index) }
    }
}

public protocol PhotoCaptureControlling: AnyObject {
    func start() async throws
    func stop()
    func capture() async throws -> Data
}
