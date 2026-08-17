import AnswerCaptureCore
import SwiftUI

struct StableCaptureView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var camera = StableCaptureController()
    @State private var automatic = true
    @State private var capturedData: Data?
    @State private var showCrop = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(
                    "安定度: \(Int(camera.stability * 100))%\n"
                        + "\(camera.status)"
                )
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.55))
            }
            .frame(maxHeight: 520)
            Toggle("自動撮影", isOn: $automatic)
                .onChange(of: automatic) { _, value in camera.automaticCaptureEnabled = value }
            Button(camera.isCapturing ? "撮影中…" : "0.5秒後に撮影") {
                Task { await captureManually() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(camera.isCapturing)
        }
        .padding()
        .navigationTitle("安定撮影")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            automatic = model.settings.autoCaptureEnabled
            camera.automaticCaptureEnabled = automatic
            camera.onAutomaticCapture = { data in
                capturedData = data
                showCrop = true
            }
            do {
                try await camera.ensureCameraPermission()
                try camera.configure()
                camera.setZoom(model.settings.defaultZoom)
                camera.start()
            } catch {
                errorMessage = "カメラを開始できません: \(error.localizedDescription)"
            }
        }
        .onDisappear { camera.stop() }
        .navigationDestination(isPresented: $showCrop) {
            if let capturedData {
                CropView(imageData: capturedData)
            } else {
                Text("撮影画像がありません")
            }
        }
        .alert("撮影エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("設定を開く") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func captureManually() async {
        do {
            capturedData = try await camera.captureBurst(manualDelay: 0.5)
            showCrop = true
        } catch {
            errorMessage = "撮影できません: \(error.localizedDescription)"
        }
    }
}
