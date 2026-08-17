import AnswerCaptureCore
import SwiftUI
import UIKit

struct CropView: View {
    @EnvironmentObject private var model: AppModel
    let imageData: Data
    @State private var selection = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var dragStart: CGPoint?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("切り抜き").font(.title.bold())
            GeometryReader { geometry in
                ZStack {
                    if let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                    Rectangle()
                        .stroke(.yellow, lineWidth: 3)
                        .background(.yellow.opacity(0.08))
                        .frame(
                            width: selection.width * geometry.size.width,
                            height: selection.height * geometry.size.height
                        )
                        .position(
                            x: selection.midX * geometry.size.width,
                            y: selection.midY * geometry.size.height
                        )
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in updateDrag(value, in: geometry.size) }
                    .onEnded { _ in dragStart = nil })
            }
            HStack {
                preset("上半分", .upperHalf)
                preset("下半分", .lowerHalf)
                preset("全体", .full)
            }
            Button(isSaving ? "保存中…" : "補正済み画像を使用") {
                Task { await save() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || !CropValidator.isValid(selection))
        }
        .padding()
        .alert("保存エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("閉じる", role: .cancel) {} } message: {
            Text(errorMessage ?? "")
        }
    }

    private func preset(_ title: String, _ value: CropPreset) -> some View {
        Button(title) { selection = value.rect() }.buttonStyle(.bordered)
    }

    private func updateDrag(_ value: DragGesture.Value, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let point = CGPoint(
            x: min(1, max(0, value.location.x / size.width)),
            y: min(1, max(0, value.location.y / size.height))
        )
        let start = dragStart ?? point
        dragStart = start
        selection = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let processor = ImageProcessor()
            let jpeg = try await processor.processToJPEG(
                imageData,
                normalizedCrop: selection
            )
            guard let image = UIImage(data: jpeg) else {
                throw ImageProcessingError.invalidImage
            }
            let result = try await model.saveCapturedPagesAndUpload([
                .init(jpeg: jpeg, width: Int(image.size.width * image.scale),
                      height: Int(image.size.height * image.scale))
            ])
            model.record(
                scan: result.scan,
                message: result.uploaded
                    ? "1ページを保存してビューアへ送信しました"
                    : "1ページを保存し、送信待ちに追加しました"
            )
        } catch {
            errorMessage = "画像を保存できません: \(error.localizedDescription)"
        }
    }
}
