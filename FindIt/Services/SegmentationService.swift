@preconcurrency import Vision
import UIKit
import CoreImage

/// 실시간 사물 감지 및 세그먼테이션 서비스
class SegmentationService {
    // MARK: - Properties
    private let processingQueue = DispatchQueue(label: "com.findit.segmentation", qos: .userInitiated)
    
    // MARK: - Object Detection
    /// 이미지에서 모든 사물의 윤곽선 감지
    func detectObjects(in image: UIImage) async throws -> [DetectedObject] {
        guard let cgImage = image.cgImage else {
            throw SegmentationError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNInstanceMaskObservation] else {
                    continuation.resume(throwing: SegmentationError.noObjectsDetected)
                    return
                }
                
                // 각 observation은 여러 인스턴스를 포함할 수 있음
                var allObjects: [DetectedObject] = []
                
                for observation in observations {
                    // 각 인스턴스를 개별적으로 처리
                    for instance in observation.allInstances {
                        guard let maskImage = try? self.createMaskImage(
                            from: observation,
                            instance: instance,
                            sourceImage: image
                        ),
                        let boundingBox = try? self.calculateBoundingBox(
                            from: observation,
                            instance: instance,
                            imageSize: image.size
                        ) else {
                            continue
                        }
                        
                        let object = DetectedObject(
                            id: UUID(),
                            boundingBox: boundingBox,
                            confidence: observation.confidence,
                            maskImage: maskImage
                        )
                        allObjects.append(object)
                    }
                }
                
                continuation.resume(returning: allObjects)
            }
            
            // 요청 설정
            request.revision = VNGenerateForegroundInstanceMaskRequestRevision1
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            self.processingQueue.async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    

    // MARK: - Helper Methods
    private func createMaskImage(
        from observation: VNInstanceMaskObservation,
        instance: IndexSet.Element,
        sourceImage: UIImage
    ) throws -> UIImage {
        guard let cgImage = sourceImage.cgImage else {
            throw SegmentationError.invalidImage
        }
        
        // 특정 인스턴스만의 마스크 픽셀 버퍼 생성
        var instanceSet = IndexSet()
        instanceSet.insert(instance)
        let maskPixelBuffer = try observation.generateMaskedImage(
            ofInstances: instanceSet,
            from: VNImageRequestHandler(cgImage: cgImage, options: [:]),
            croppedToInstancesExtent: false
        )
        
        // CIImage로 변환
        let ciImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw SegmentationError.maskCreationFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func calculateBoundingBox(
        from observation: VNInstanceMaskObservation,
        instance: IndexSet.Element,
        imageSize: CGSize
    ) throws -> CGRect {
        // 특정 인스턴스의 마스크에서 경계 계산
        // instanceMask를 직접 사용하여 해당 인스턴스의 영역 찾기
        let pixelBuffer = observation.instanceMask
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw SegmentationError.maskCreationFailed
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        
        // 특정 인스턴스의 마스크에서 객체 영역 찾기
        for y in 0..<height {
            for x in 0..<width {
                let pixel = buffer[y * bytesPerRow + x]
                // 해당 인스턴스 ID와 일치하는 픽셀만 계산
                if pixel == UInt8(instance) {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        
        // Normalized coordinates로 변환 (0-1)
        return CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(maxX - minX) / CGFloat(width),
            height: CGFloat(maxY - minY) / CGFloat(height)
        )
    }

}

// MARK: - Models
struct DetectedObject: Identifiable {
    let id: UUID
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let confidence: Float
    let maskImage: UIImage
}

// MARK: - Errors
enum SegmentationError: LocalizedError {
    case invalidImage
    case noObjectsDetected
    case maskCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 처리할 수 없습니다."
        case .noObjectsDetected:
            return "사물을 감지하지 못했습니다."
        case .maskCreationFailed:
            return "마스크 이미지 생성에 실패했습니다."
        }
    }
}
// MARK: - UIImage Orientation Extension
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

