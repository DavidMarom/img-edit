import AppKit
import CoreGraphics

/// A mutable RGBA bitmap. All rects passed to this type use top-left-origin,
/// y-down pixel coordinates (matching CGImage cropping conventions and a
/// flipped NSView) — never the bottom-left-origin convention CGContext
/// drawing normally expects. `flipped(_:)` is the only place that conversion
/// happens.
final class LayerBitmap {
    private(set) var context: CGContext

    var pixelSize: CGSize { CGSize(width: context.width, height: context.height) }

    init(size: CGSize) {
        context = CGContext(
            data: nil,
            width: max(1, Int(size.width.rounded())),
            height: max(1, Int(size.height.rounded())),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    convenience init(cgImage: CGImage) {
        self.init(size: CGSize(width: cgImage.width, height: cgImage.height))
        draw(image: cgImage, at: .zero)
    }

    var cgImage: CGImage { context.makeImage()! }

    func copy() -> LayerBitmap { LayerBitmap(cgImage: cgImage) }

    private func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: CGFloat(context.height) - rect.maxY, width: rect.width, height: rect.height)
    }

    /// rect: top-left-origin pixel coordinates
    func clear(rect: CGRect) {
        context.clear(flipped(rect))
    }

    /// origin: top-left-origin pixel coordinates
    func draw(image: CGImage, at origin: CGPoint) {
        let rect = CGRect(x: origin.x, y: origin.y, width: CGFloat(image.width), height: CGFloat(image.height))
        context.draw(image, in: flipped(rect))
    }

    /// rect: top-left-origin pixel coordinates
    func subImage(rect: CGRect) -> CGImage? {
        cgImage.cropping(to: rect)
    }

    /// rect: top-left-origin pixel coordinates
    func croppedBitmap(to rect: CGRect) -> LayerBitmap? {
        guard let piece = subImage(rect: rect) else { return nil }
        return LayerBitmap(cgImage: piece)
    }

    func pngData() -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
