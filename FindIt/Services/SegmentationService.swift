import Vision
import UIKit
import CoreImage
import CoreVideo

actor SegmentationService {
    static let shared = SegmentationService()

    /// Segments an object from the image using LiDAR depth data.
    /// Returns the cropped image of the object with background removed.
    func segmentObjectWithDepth(at point: CGPoint, in image: CGImage, depthMap: CVPixelBuffer) async throws -> UIImage? {
        // 1. Get depth at tapped point
        guard let targetDepth = getDepth(at: point, in: depthMap) else {
            // Fallback to Vision-only segmentation
            return try await segmentObject(at: point, in: image)
        }

        // 2. Create depth-based mask (tolerance 0.5m for more forgiving segmentation)
        let depthMask = createDepthMask(depthMap: depthMap, targetDepth: targetDepth, tolerance: 0.5)

        // 3. Also use Vision for instance segmentation
        let visionMask = try? await getVisionMask(at: point, in: image)

        // 4. Combine depth mask with vision mask for better results
        let combinedMask: CVPixelBuffer
        if let visionMask = visionMask {
            combinedMask = combineMasks(depthMask: depthMask, visionMask: visionMask)
        } else {
            combinedMask = depthMask
        }

        // 5. Apply mask to original image
        return applyMask(combinedMask, to: image)
    }

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
        let maskPixelBuffer = try result.generateMask(forInstances: [Int(instanceId)])

        // 3. Apply mask to the original image
        return applyMask(maskPixelBuffer, to: image)
    }

    // MARK: - Instance Detection

    /// Detect all instances in the image and return their contours
    func detectInstances(in image: CGImage) async throws -> [DetectedInstance] {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            return []
        }

        let instanceMask = result.instanceMask
        CVPixelBufferLockBaseAddress(instanceMask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(instanceMask, .readOnly) }

        let width = CVPixelBufferGetWidth(instanceMask)
        let height = CVPixelBufferGetHeight(instanceMask)

        // Find all unique instance IDs (excluding background 0)
        var instanceIds = Set<UInt8>()
        let baseAddress = CVPixelBufferGetBaseAddress(instanceMask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(instanceMask)
        let buffer = baseAddress?.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let id = buffer?[y * bytesPerRow + x] ?? 0
                if id > 0 {
                    instanceIds.insert(id)
                }
            }
        }

        // Generate masks and contours for each instance
        var instances: [DetectedInstance] = []
        for instanceId in instanceIds {
            if let maskBuffer = try? result.generateMask(forInstances: [Int(instanceId)]) {
                let contour = extractContour(from: maskBuffer)
                instances.append(DetectedInstance(
                    id: instanceId,
                    contour: contour,
                    maskBuffer: maskBuffer
                ))
            }
        }

        return instances
    }

    struct DetectedInstance: Sendable {
        let id: UInt8
        let contour: [CGPoint]  // Normalized coordinates (0.0 - 1.0)
        let maskBuffer: CVPixelBuffer
    }

    /// Segment object using a pre-detected instance mask
    func segmentWithMask(_ maskBuffer: CVPixelBuffer, in image: CGImage) async -> UIImage? {
        return applyMask(maskBuffer, to: image)
    }

    private func extractContour(from maskBuffer: CVPixelBuffer) -> [CGPoint] {
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer)
        let buffer = baseAddress?.assumingMemoryBound(to: UInt8.self)

        var contourPoints: [CGPoint] = []

        // Simple edge detection - find pixels at the boundary
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let current = buffer?[idx] ?? 0

                if current > 128 {  // Foreground pixel
                    // Check if it's an edge (has background neighbor)
                    let top = buffer?[(y - 1) * width + x] ?? 0
                    let bottom = buffer?[(y + 1) * width + x] ?? 0
                    let left = buffer?[y * width + (x - 1)] ?? 0
                    let right = buffer?[y * width + (x + 1)] ?? 0

                    if top < 128 || bottom < 128 || left < 128 || right < 128 {
                        // Normalize to 0.0 - 1.0
                        contourPoints.append(CGPoint(
                            x: CGFloat(x) / CGFloat(width),
                            y: CGFloat(y) / CGFloat(height)
                        ))
                    }
                }
            }
        }

        return contourPoints
    }

    // MARK: - Private Helpers

    private func getDepth(at point: CGPoint, in depthMap: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let x = Int(point.x * CGFloat(width))
        let y = Int(point.y * CGFloat(height))

        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }

        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self)
        return floatBuffer?[y * width + x]
    }

    private func createDepthMask(depthMap: CVPixelBuffer, targetDepth: Float, tolerance: Float) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        // Create output mask buffer
        var maskBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary

        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, attrs, &maskBuffer)

        guard let mask = maskBuffer else { return depthMap }

        CVPixelBufferLockBaseAddress(mask, [])
        defer { CVPixelBufferUnlockBaseAddress(mask, []) }

        let depthBase = CVPixelBufferGetBaseAddress(depthMap)?.assumingMemoryBound(to: Float32.self)
        let maskBase = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self)

        let minDepth = targetDepth - tolerance
        let maxDepth = targetDepth + tolerance

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let depth = depthBase?[idx] ?? 0

                // If depth is within tolerance, mark as foreground (255), else background (0)
                if depth >= minDepth && depth <= maxDepth && depth > 0 {
                    maskBase?[idx] = 255
                } else {
                    maskBase?[idx] = 0
                }
            }
        }

        return mask
    }

    private func getVisionMask(at point: CGPoint, in image: CGImage) async throws -> CVPixelBuffer? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else { return nil }

        let instanceMask = result.instanceMask
        CVPixelBufferLockBaseAddress(instanceMask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(instanceMask, .readOnly) }

        let width = CVPixelBufferGetWidth(instanceMask)
        let height = CVPixelBufferGetHeight(instanceMask)
        let x = Int(point.x * CGFloat(width))
        let y = Int(point.y * CGFloat(height))

        var instanceId: UInt8 = 0
        if x >= 0 && x < width && y >= 0 && y < height {
            let baseAddress = CVPixelBufferGetBaseAddress(instanceMask)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(instanceMask)
            let buffer = baseAddress?.assumingMemoryBound(to: UInt8.self)
            instanceId = buffer?[y * bytesPerRow + x] ?? 0
        }

        guard instanceId > 0 else { return nil }
        return try result.generateMask(forInstances: [Int(instanceId)])
    }

    private func combineMasks(depthMask: CVPixelBuffer, visionMask: CVPixelBuffer) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(depthMask, .readOnly)
        CVPixelBufferLockBaseAddress(visionMask, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMask, .readOnly)
            CVPixelBufferUnlockBaseAddress(visionMask, .readOnly)
        }

        let width = CVPixelBufferGetWidth(depthMask)
        let height = CVPixelBufferGetHeight(depthMask)

        // Create combined mask buffer
        var combinedBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_OneComponent8,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary

        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, attrs, &combinedBuffer)

        guard let combined = combinedBuffer else { return depthMask }

        CVPixelBufferLockBaseAddress(combined, [])
        defer { CVPixelBufferUnlockBaseAddress(combined, []) }

        let depthBase = CVPixelBufferGetBaseAddress(depthMask)?.assumingMemoryBound(to: UInt8.self)
        let visionBase = CVPixelBufferGetBaseAddress(visionMask)?.assumingMemoryBound(to: UInt8.self)
        let combinedBase = CVPixelBufferGetBaseAddress(combined)?.assumingMemoryBound(to: UInt8.self)

        // Combine masks using AND operation (both must agree)
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let depthVal = depthBase?[idx] ?? 0
                let visionVal = visionBase?[idx] ?? 0

                // Pixel is foreground only if both masks agree
                combinedBase?[idx] = (depthVal > 128 && visionVal > 128) ? 255 : 0
            }
        }

        return combined
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
