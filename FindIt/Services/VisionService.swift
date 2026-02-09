@preconcurrency import Vision
import UIKit

/// Vision Feature Print 기반 사물 인식 서비스
class VisionService {
    // MARK: - Properties
    private let processingQueue = DispatchQueue(label: "com.findit.vision", qos: .userInitiated)
    
    // MARK: - Feature Print Extraction
    /// 이미지에서 Feature Print 추출
    func extractFeaturePrint(from image: UIImage) async throws -> Data {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                    continuation.resume(throwing: VisionError.featurePrintExtractionFailed)
                    return
                }
                
                // Feature Print를 Data로 변환
                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: observation,
                        requiringSecureCoding: true
                    )
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: VisionError.featurePrintSerializationFailed)
                }
            }
            
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
    
    // MARK: - Feature Print Matching
    /// 두 Feature Print 간의 유사도 계산 (0.0 ~ 1.0, 높을수록 유사)
    func computeSimilarity(
        between data1: Data,
        and data2: Data
    ) throws -> Float {
        // Data를 VNFeaturePrintObservation으로 역직렬화
        guard let observation1 = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data1
        ) else {
            throw VisionError.featurePrintDeserializationFailed
        }
        
        guard let observation2 = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data2
        ) else {
            throw VisionError.featurePrintDeserializationFailed
        }
        
        // 거리 계산 (0.0 ~ 2.0, 낮을수록 유사)
        var distance: Float = 0
        try observation1.computeDistance(&distance, to: observation2)
        
        // 유사도로 변환 (0.0 ~ 1.0, 높을수록 유사)
        // distance가 0에 가까울수록 similarity는 1에 가까움
        let similarity = max(0, 1 - (distance / Constants.Vision.distanceNormalizationFactor))
        
        return similarity
    }
    
    /// 이미지와 Feature Print 간의 유사도 계산
    func computeSimilarity(
        between image: UIImage,
        and featurePrintData: Data
    ) async throws -> Float {
        // 이미지에서 Feature Print 추출
        let currentFeaturePrint = try await extractFeaturePrint(from: image)
        
        // 유사도 계산
        return try computeSimilarity(between: currentFeaturePrint, and: featurePrintData)
    }
    
    // MARK: - Matching Level
    /// 유사도를 게임 피드백 레벨로 변환
    func matchLevel(for similarity: Float) -> MatchLevel {
        switch similarity {
        case Constants.Vision.SimilarityThreshold.match...:
            return .match       // 매치!
        case Constants.Vision.SimilarityThreshold.hot..<Constants.Vision.SimilarityThreshold.match:
            return .hot         // 뜨거워요!
        case Constants.Vision.SimilarityThreshold.warm..<Constants.Vision.SimilarityThreshold.hot:
            return .warm        // 따뜻해요
        default:
            return .cold        // 차가워요
        }
    }
}

// MARK: - Models
enum MatchLevel {
    case cold       // < 0.3
    case warm       // 0.3 ~ 0.5
    case hot        // 0.5 ~ 0.7
    case match      // >= 0.7
    
    var description: String {
        switch self {
        case .cold: return "차가워요"
        case .warm: return "따뜻해요"
        case .hot: return "뜨거워요!"
        case .match: return "찾았다!"
        }
    }
    
    var color: UIColor {
        switch self {
        case .cold: return .systemBlue
        case .warm: return .systemYellow
        case .hot: return .systemOrange
        case .match: return .systemGreen
        }
    }
}

// MARK: - Errors
enum VisionError: LocalizedError {
    case invalidImage
    case featurePrintExtractionFailed
    case featurePrintSerializationFailed
    case featurePrintDeserializationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 처리할 수 없습니다."
        case .featurePrintExtractionFailed:
            return "특징 추출에 실패했습니다."
        case .featurePrintSerializationFailed:
            return "특징 데이터 저장에 실패했습니다."
        case .featurePrintDeserializationFailed:
            return "특징 데이터 로드에 실패했습니다."
        }
    }
}
