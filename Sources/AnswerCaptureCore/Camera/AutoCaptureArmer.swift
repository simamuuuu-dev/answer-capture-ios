import CoreGraphics
import Foundation
import ImageIO

public struct AutoCaptureArmer: Sendable {
    public let thresholds: StabilityThresholds

    public init(thresholds: StabilityThresholds = .init()) { self.thresholds = thresholds }

    public func canCapture(
        startedAt: TimeInterval,
        now: TimeInterval,
        samples: [MotionSample]
    ) -> Bool {
        let evaluator = StabilityEvaluator(thresholds: thresholds)
        return evaluator.isWarmedUp(at: now, startedAt: startedAt)
            && evaluator.isStable(samples, now: now)
    }
}

public protocol BurstSharpnessScoring: Sendable {
    func score(imageData: Data) async -> Double
}

public struct LaplacianSharpnessScorer: BurstSharpnessScoring {
    public let maximumDimension: Int

    public init(maximumDimension: Int = 1280) { self.maximumDimension = maximumDimension }

    public func score(imageData: Data) async -> Double {
        Self.calculate(imageData, maximumDimension: maximumDimension)
    }

    private static func calculate(_ data: Data, maximumDimension: Int) -> Double {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumDimension
                ] as CFDictionary
              ) else { return 0 }
        let width = image.width
        let height = image.height
        guard width >= 3, height >= 3 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return 0 }
        var count = 0.0
        var mean = 0.0
        var sumSquaredDifferences = 0.0
        for y in 1 ..< (height - 1) {
            for x in 1 ..< (width - 1) {
                let index = y * width + x
                let laplacian = Double(Int(pixels[index]) * 4
                    - Int(pixels[index - 1]) - Int(pixels[index + 1])
                    - Int(pixels[index - width]) - Int(pixels[index + width]))
                count += 1
                let delta = laplacian - mean
                mean += delta / count
                sumSquaredDifferences += delta * (laplacian - mean)
            }
        }
        return count > 1 ? sumSquaredDifferences / (count - 1) : 0
    }
}

public struct BurstCaptureSelector: Sendable {
    public init() {}

    public func select(_ frames: [(data: Data, score: Double)]) -> Data? {
        let candidates = frames.enumerated().map {
            SharpnessCandidate(index: $0.offset, score: $0.element.score)
        }
        guard let winner = SharpnessSelector.best(in: candidates) else { return nil }
        return frames[winner.index].data
    }
}
