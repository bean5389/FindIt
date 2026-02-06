import Vision
import UIKit

actor FeaturePrintService {
    static let shared = FeaturePrintService()

    /// Maximum expected distance for normalization. Tuned via PoC testing.
    private let maxDistance: Float = 30.0

    func extractFeaturePrint(from cgImage: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw FeaturePrintError.extractionFailed
        }
        return observation
    }

    func extractFeaturePrint(from imageData: Data) throws -> VNFeaturePrintObservation {
        guard let cgImage = ImageHelper.cgImage(from: imageData) else {
            throw FeaturePrintError.invalidImage
        }
        return try extractFeaturePrint(from: cgImage)
    }

    func extractFeaturePrint(from image: UIImage) throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage else {
            throw FeaturePrintError.invalidImage
        }
        return try extractFeaturePrint(from: cgImage)
    }

    func serializeFeaturePrint(_ observation: VNFeaturePrintObservation) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    func deserializeFeaturePrint(_ data: Data) throws -> VNFeaturePrintObservation {
        guard let observation = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data
        ) else {
            throw FeaturePrintError.deserializationFailed
        }
        return observation
    }

    func computeSimilarity(
        _ observation1: VNFeaturePrintObservation,
        _ observation2: VNFeaturePrintObservation
    ) throws -> Float {
        var distance: Float = 0
        try observation1.computeDistance(&distance, to: observation2)
        let similarity = max(0, 1.0 - (distance / maxDistance))
        return similarity
    }

    func computeSimilarity(
        queryImage: CGImage,
        referenceData: Data
    ) throws -> Float {
        let queryObservation = try extractFeaturePrint(from: queryImage)
        let referenceObservation = try deserializeFeaturePrint(referenceData)
        return try computeSimilarity(queryObservation, referenceObservation)
    }

    /// Compute best similarity against multiple reference photos.
    func bestSimilarity(
        queryImage: CGImage,
        references: [Data]
    ) throws -> Float {
        let queryObservation = try extractFeaturePrint(from: queryImage)
        var best: Float = 0
        for refData in references {
            let refObservation = try deserializeFeaturePrint(refData)
            let similarity = try computeSimilarity(queryObservation, refObservation)
            best = max(best, similarity)
        }
        return best
    }
}

enum FeaturePrintError: Error, LocalizedError {
    case extractionFailed
    case invalidImage
    case deserializationFailed

    var errorDescription: String? {
        switch self {
        case .extractionFailed: "Feature Print 추출에 실패했습니다."
        case .invalidImage: "유효하지 않은 이미지입니다."
        case .deserializationFailed: "Feature Print 데이터 복원에 실패했습니다."
        }
    }
}
