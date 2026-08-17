@preconcurrency import AVFoundation
import Combine
@preconcurrency import CoreMotion
import Foundation
import SwiftUI

@MainActor
public final class StableCaptureController: NSObject, ObservableObject {
    private let sessionRunner = CaptureSessionRunner()
    public var session: AVCaptureSession { sessionRunner.session }
    @Published public private(set) var status = "カメラを準備中"
    @Published public private(set) var stability = 0.0
    @Published public private(set) var isCapturing = false
    @Published public private(set) var lastSharpness = 0.0

    public var automaticCaptureEnabled = true
    public var onAutomaticCapture: (@MainActor @Sendable (Data) -> Void)?

    private let motion = CMMotionManager()
    private let thresholds: StabilityThresholds
    private let output = AVCapturePhotoOutput()
    private let scorer: any BurstSharpnessScoring
    private var continuation: CheckedContinuation<Data, Error>?
    private var samples = [MotionSample]()
    private var startedAt = ProcessInfo.processInfo.systemUptime

    public init(
        thresholds: StabilityThresholds = .init(),
        scorer: any BurstSharpnessScoring = LaplacianSharpnessScorer()
    ) {
        self.thresholds = thresholds
        self.scorer = scorer
    }

    public func ensureCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        @unknown default:
            throw CameraError.permissionDenied
        }
    }

    public func configure() throws {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else { throw CameraError.unavailable }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality
        if camera.isSmoothAutoFocusSupported {
            try camera.lockForConfiguration()
            camera.isSmoothAutoFocusEnabled = true
            camera.unlockForConfiguration()
        }
        status = "撮影準備完了"
    }

    public func start() {
        startedAt = ProcessInfo.processInfo.systemUptime
        samples.removeAll(keepingCapacity: true)
        sessionRunner.start()
        startMotion()
        status = "安定度を確認中"
    }

    public func stop() {
        sessionRunner.stop()
        motion.stopDeviceMotionUpdates()
        samples.removeAll()
    }

    public func setZoom(_ value: CGFloat) {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(
                max(value, device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.unlockForConfiguration()
        } catch {
            status = "ズーム設定に失敗しました"
        }
    }

    public func captureBurst(manualDelay: TimeInterval = 0) async throws -> Data {
        guard !isCapturing else { throw CameraError.captureInProgress }
        isCapturing = true
        defer { isCapturing = false }
        if manualDelay > 0 {
            focusAtCenter()
            try await Task.sleep(for: .seconds(manualDelay))
        }
        var frames = [(data: Data, score: Double)]()
        for index in 0 ..< 3 {
            if index > 0 { try await Task.sleep(for: .milliseconds(140)) }
            let data = try await captureOne()
            let score = await scorer.score(imageData: data)
            frames.append((data, score))
        }
        guard let best = BurstCaptureSelector().select(frames) else {
            throw CameraError.noPhotoData
        }
        lastSharpness = frames.map(\.score).max() ?? 0
        status = String(format: "撮影完了・鮮明度 %.1f", lastSharpness)
        return best
    }

    private func captureOne() async throws -> Data {
        guard continuation == nil else { throw CameraError.captureInProgress }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func focusAtCenter() {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .autoFocus
            }
            device.unlockForConfiguration()
        } catch {
            status = "オートフォーカス設定に失敗しました"
        }
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else {
            status = "モーションセンサーを利用できません"
            return
        }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let acceleration = data.userAcceleration
            let value = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )
            self.samples.append(.init(time: now, magnitude: value))
            self.samples.removeAll { now - $0.time > self.thresholds.requiredDuration + 0.15 }
            self.stability = max(0, 1 - min(1, value / self.thresholds.motionLimit))
            let armer = AutoCaptureArmer(thresholds: self.thresholds)
            guard self.automaticCaptureEnabled, !self.isCapturing,
                  armer.canCapture(startedAt: self.startedAt, now: now, samples: self.samples)
            else { return }
            self.samples.removeAll()
            self.startedAt = now
            Task { @MainActor [weak self] in
                guard let self else { return }
                do { self.onAutomaticCapture?(try await self.captureBurst()) }
                catch { self.status = "自動撮影に失敗しました" }
            }
        }
    }
}

private final class CaptureSessionRunner: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "AnswerCapture.camera.session")

    func start() {
        queue.async { [self] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}

@preconcurrency extension StableCaptureController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { continuation = nil }
        if let error { continuation?.resume(throwing: error) }
        else if let data = photo.fileDataRepresentation() { continuation?.resume(returning: data) }
        else { continuation?.resume(throwing: CameraError.noPhotoData) }
    }
}

public enum CameraError: LocalizedError, Sendable {
    case unavailable, configurationFailed, captureInProgress, noPhotoData, permissionDenied

    public var errorDescription: String? {
        switch self {
        case .unavailable: "背面カメラを利用できません。"
        case .configurationFailed: "カメラを構成できません。"
        case .captureInProgress: "別の撮影が進行中です。"
        case .noPhotoData: "撮影画像を取得できませんでした。"
        case .permissionDenied: "カメラへのアクセスが許可されていません。設定アプリで許可してください。"
        }
    }
}

public struct CameraPreview: UIViewRepresentable {
    public let session: AVCaptureSession
    public init(session: AVCaptureSession) { self.session = session }
    public func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        return view
    }
    public func updateUIView(_ view: PreviewView, context: Context) {
        view.preview.session = session
    }
}

public final class PreviewView: UIView {
    public let preview = AVCaptureVideoPreviewLayer()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
    public override func layoutSubviews() {
        super.layoutSubviews()
        preview.frame = bounds
    }
}
