import SwiftUI
import UIKit
@preconcurrency import VisionKit

@MainActor
public struct DocumentScannerView: UIViewControllerRepresentable {
    public static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    public let onPages: ([UIImage]) -> Void
    public let onCancel: () -> Void
    public let onError: (Error) -> Void

    public init(
        onPages: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onPages = onPages
        self.onCancel = onCancel
        self.onError = onError
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }
    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    public func updateUIViewController(
        _ controller: VNDocumentCameraViewController,
        context: Context
    ) {}

    public final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        init(_ parent: DocumentScannerView) { self.parent = parent }

        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            parent.onPages((0 ..< scan.pageCount).map { scan.imageOfPage(at: $0) })
            controller.dismiss(animated: true)
        }
        public func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            parent.onCancel()
            controller.dismiss(animated: true)
        }
        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error)
            controller.dismiss(animated: true)
        }
    }
}
