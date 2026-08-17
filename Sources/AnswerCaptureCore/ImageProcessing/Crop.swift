import CoreGraphics

public enum CropPreset: CaseIterable, Sendable { case full, upperHalf, lowerHalf
    public func rect() -> CGRect { switch self { case .full: return .init(x: 0, y: 0, width: 1, height: 1); case .upperHalf: return .init(x: 0, y: 0, width: 1, height: 0.5); case .lowerHalf: return .init(x: 0, y: 0.5, width: 1, height: 0.5) } }
}
public enum CropValidator {
    public static func isValid(_ rect: CGRect, minimumEdge: CGFloat = 0.05) -> Bool {
        rect.minX >= 0 && rect.minY >= 0 && rect.maxX <= 1 && rect.maxY <= 1 && rect.width >= minimumEdge && rect.height >= minimumEdge
    }
}
