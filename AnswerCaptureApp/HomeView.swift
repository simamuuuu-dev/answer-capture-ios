import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Answer Capture").font(.largeTitle.bold())
                    GroupBox("接続状態") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                model.settings.storageBookmark == nil
                                    ? "保存先: アプリ内" : "保存先: Files共有フォルダ",
                                systemImage: "folder"
                            )
                            Label("ビューア: \(model.settings.viewerURL)", systemImage: "network")
                            Label("未送信: \(model.pendingCount)件", systemImage: "tray")
                            Label(
                                model.settings.savedPeripheralUUID == nil
                                    ? "Slate: 未登録" : "Slate: 登録済み",
                                systemImage: "bluetooth"
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("クイック操作").font(.title2.bold())
                    action("安定撮影", systemImage: "camera") { StableCaptureView() }
                    action("文書スキャン", systemImage: "doc.viewfinder") { DocumentScanView() }
                    action("遠隔撮影待機", systemImage: "antenna.radiowaves.left.and.right") {
                        RemoteWaitingView()
                    }
                    action("Bamboo Slate取り込み", systemImage: "pencil.and.scribble") {
                        SlateView()
                    }
                    action("OCR確認", systemImage: "text.viewfinder") { OCRView() }
                    Button {
                        Task { await model.retryPendingUploads() }
                    } label: {
                        Label(
                            model.isRetrying ? "再送中…" : "未送信を再送",
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRetrying || model.pendingCount == 0)
                    NavigationLink { SettingsView() } label: {
                        Label("設定", systemImage: "gearshape").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    GroupBox("前回結果") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Capture ID: \(model.lastCaptureID ?? "—")")
                            Text(model.lastMessage)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .alert("エラー", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) { Button("閉じる", role: .cancel) {} } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private func action<Destination: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            Label(title, systemImage: systemImage).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }
}
