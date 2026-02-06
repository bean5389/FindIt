import Vision
import UIKit
import CoreImage

actor SegmentationService {
    static let shared = SegmentationService()

    /// Segments an object from the image based on a point.
    /// Returns the cropped image of the object.
    func segmentObject(at point: CGPoint, in image: CGImage) async throws -> UIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            return nil
        }

        // 1. Get the instance identifier at the tapped point from instanceMask
        let instanceMask = result.instanceMask
        CVPixelBufferLockBaseAddress(instanceMask, .readOnly)
        
        let width = CVPixelBufferGetWidth(instanceMask)
        let height = CVPixelBufferGetHeight(instanceMask)
        
        // Map normalized point (0.0 - 1.0) to mask coordinates
        let x = Int(point.x * CGFloat(width))
        let y = Int(point.y * CGFloat(height))
        
        var instanceId: UInt8 = 0
        if x >= 0 && x < width && y >= 0 && y < height {
            let baseAddress = CVPixelBufferGetBaseAddress(instanceMask)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(instanceMask)
            let buffer = baseAddress?.assumingMemoryBound(to: UInt8.self)
            instanceId = buffer?[y * bytesPerRow + x] ?? 0
        }
        
        CVPixelBufferUnlockBaseAddress(instanceMask, .readOnly)
        
        // 0 is typically the background
        guard instanceId > 0 else { return nil }

        // 2. Generate the mask for the specific instance identifier
        let maskPixelBuffer = try result.generateMaskForInstances(withIdentifiers: [Int(instanceId)])

        // 3. Apply mask to the original image
        return applyMask(maskPixelBuffer, to: image)
    }

    private func applyMask(_ maskPixelBuffer: CVPixelBuffer, to image: CGImage) -> UIImage? {
        let ciImage = CIImage(cgImage: image)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        // Scale mask to image size if needed
        let scaleX = ciImage.extent.width / maskImage.extent.width
        let scaleY = ciImage.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Blend: image * mask
        let parameters = [
            kCIInputMaskImageKey: scaledMask,
            kCIInputImageKey: ciImage,
            kCIInputBackgroundImageKey: CIImage.empty()
        ]

        guard let filter = CIFilter(name: "CIBlendWithMask", parameters: parameters),
              let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext()
        // Crop to visible content
        let maskedImage = outputImage.cropped(to: ciImage.extent)

        // Find the bounding box of the non-transparent pixels to crop tightly
        // This is a bit complex in CIImage, so we'll just return the masked image for now,
        // but ideally we crop it.
        guard let cgImage = context.createCGImage(maskedImage, from: maskedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Helper to crop image to its non-transparent bounds
    func cropToContent(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let ptr = data.assumingMemoryBound(to: UInt8.self)

        var lowX = width
        var lowY = height
        var highX = 0
        var highY = 0

        for y in 0..<height {
            for x in 0..<width {
                let alpha = ptr[(y * width + x) * 4 + 3]
                if alpha > 0 {
                    lowX = min(lowX, x)
                    lowY = min(lowY, y)
                    highX = max(highX, x)
                    highY = max(highY, y)
                }
            }
        }

        if lowX > highX || lowY > highY {
            return nil
        }

        let rect = CGRect(x: lowX, y: height - highY - 1, width: highX - lowX + 1, height: highY - lowY + 1)
        guard let cropped = cgImage.cropping(to: rect) else { return nil }

        return UIImage(cgImage: cropped)
    }
}
