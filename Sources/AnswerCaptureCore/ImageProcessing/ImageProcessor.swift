import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit
@preconcurrency import Vision

public struct RectangleDetectionResult: @unchecked Sendable {
    public let image: CIImage
    public let rectangle: VNRectangleObservation?
}

public actor ImageProcessor {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    public init() {}

    public func process(_ jpeg: Data) throws -> RectangleDetectionResult {
        guard let image = CIImage(data: jpeg, options: [.applyOrientationProperty: true]) else {
            throw ImageProcessingError.invalidImage
        }
        return detectAndCorrect(image)
    }

    public func processToJPEG(
        _ jpeg: Data,
        normalizedCrop: CGRect? = nil,
        quality: CGFloat = 0.92
    ) throws -> Data {
        let result = try process(jpeg)
        let image = try normalizedCrop.map { try crop(result.image, normalized: $0) }
            ?? result.image
        guard let data = jpegData(image, quality: quality) else {
            throw ImageProcessingError.invalidImage
        }
        return data
    }

    public func detectAndCorrect(_ image: CIImage) -> RectangleDetectionResult {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 4
        request.minimumConfidence = 0.5
        request.minimumSize = 0.2
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do { try handler.perform([request]) }
        catch { return .init(image: enhance(image), rectangle: nil) }
        guard let rectangle = request.results?.max(by: {
            ($0.boundingBox.width * $0.boundingBox.height)
                < ($1.boundingBox.width * $1.boundingBox.height)
        }) else { return .init(image: enhance(image), rectangle: nil) }
        let extent = image.extent
        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.minX + normalized.x * extent.width,
                y: extent.minY + normalized.y * extent.height
            )
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = point(rectangle.topLeft)
        filter.topRight = point(rectangle.topRight)
        filter.bottomLeft = point(rectangle.bottomLeft)
        filter.bottomRight = point(rectangle.bottomRight)
        return .init(image: enhance(filter.outputImage ?? image), rectangle: rectangle)
    }

    public func crop(_ image: CIImage, normalized rect: CGRect) throws -> CIImage {
        guard CropValidator.isValid(rect) else { throw ImageProcessingError.invalidCrop }
        let extent = image.extent
        let crop = CGRect(
            x: extent.minX + rect.minX * extent.width,
            y: extent.minY + (1 - rect.minY - rect.height) * extent.height,
            width: rect.width * extent.width,
            height: rect.height * extent.height
        )
        return image.cropped(to: crop).transformed(
            by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY)
        )
    }

    public func jpegData(_ image: CIImage, quality: CGFloat = 0.92) -> Data? {
        // CIImageRepresentationOption.lossyCompressionQuality is not exposed by
        // the iOS 26 SDK. Keep the public quality parameter for call-site
        // compatibility and use Core Image's default JPEG quality here.
        _ = quality
        return context.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [:]
        )
    }

    private func enhance(_ image: CIImage) -> CIImage {
        let shadow = CIFilter.highlightShadowAdjust()
        shadow.inputImage = image
        shadow.shadowAmount = 0.35
        shadow.highlightAmount = 0.9
        let controls = CIFilter.colorControls()
        controls.inputImage = shadow.outputImage ?? image
        controls.saturation = 0.15
        controls.contrast = 1.12
        controls.brightness = 0.02
        return controls.outputImage ?? image
    }
}

public enum ImageProcessingError: Error, Sendable { case invalidImage, invalidCrop }
