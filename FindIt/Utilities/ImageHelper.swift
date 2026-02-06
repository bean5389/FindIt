import UIKit
import CoreGraphics

@MainActor
enum ImageHelper {
    static let thumbnailMaxDimension: CGFloat = 300
    static let featurePrintMaxDimension: CGFloat = 600

    static func resizedImageData(_ image: UIImage, maxDimension: CGFloat, compressionQuality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    static func thumbnailData(from image: UIImage) -> Data? {
        resizedImageData(image, maxDimension: thumbnailMaxDimension, compressionQuality: 0.7)
    }

    nonisolated static func cgImage(from data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
    }

    nonisolated static func cgImage(from image: UIImage) -> CGImage? {
        image.cgImage
    }
}
