import Foundation
@preconcurrency import Vision

public struct OCRPageResult: Sendable, Equatable {
    public let text: String
    public let metrics: OCRMetrics
    public let errorDescription: String?
}

public final class OCRService: @unchecked Sendable {
    public init() {}

    public func recognize(_ image: CGImage) async -> OCRPageResult {
        let start = Date()
        if Task.isCancelled { return failure("OCRをキャンセルしました", startedAt: start) }
        return await withCheckedContinuation { continuation in
            let sink = OCRResultSink(continuation)
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    sink.resume(self.failure(
                        error.localizedDescription,
                        startedAt: start
                    ))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")
                sink.resume(.init(
                    text: text,
                    metrics: OCRMetricsCalculator.calculate(
                        text: text,
                        observations: observations.count,
                        duration: Date().timeIntervalSince(start)
                    ),
                    errorDescription: nil
                ))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) }
                catch {
                    sink.resume(self.failure(
                        error.localizedDescription,
                        startedAt: start
                    ))
                }
            }
        }
    }

    private func failure(_ message: String, startedAt: Date) -> OCRPageResult {
        .init(
            text: "",
            metrics: .init(
                observations: 0,
                lines: 0,
                tokens: 0,
                characters: 0,
                duration: Date().timeIntervalSince(startedAt)
            ),
            errorDescription: message
        )
    }
}

private final class OCRResultSink: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<OCRPageResult, Never>?

    init(_ continuation: CheckedContinuation<OCRPageResult, Never>) {
        self.continuation = continuation
    }

    func resume(_ result: OCRPageResult) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(returning: result)
    }
}
