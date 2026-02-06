import Vision
import UIKit

actor RecognitionService {
    static let shared = RecognitionService()

    private let featurePrintService = FeaturePrintService.shared
    private let classifierService = ClassifierService.shared

    private let fpWeight: Float = 0.6
    private let mlWeight: Float = 0.4

    struct RecognitionResult: Sendable {
        let itemID: String
        let itemName: String
        let similarity: Float
        let fpScore: Float
        let mlScore: Float
    }

    /// Recognize which registered item best matches the query image.
    func recognize(
        queryImage: CGImage,
        candidates: [(id: String, name: String, featurePrintDataList: [Data])]
    ) async -> RecognitionResult? {
        var bestResult: RecognitionResult?

        for candidate in candidates {
            guard !candidate.featurePrintDataList.isEmpty else { continue }

            // Feature Print similarity
            let fpScore: Float
            do {
                fpScore = try await featurePrintService.bestSimilarity(
                    queryImage: queryImage,
                    references: candidate.featurePrintDataList
                )
            } catch {
                continue
            }

            // ML classifier score (stub returns nil for now)
            let mlResult = await classifierService.classify(queryImage)
            let mlScore: Float
            if let mlResult, mlResult.label == candidate.name {
                mlScore = mlResult.confidence
            } else if await classifierService.isModelAvailable {
                mlScore = 0
            } else {
                // No ML model yet — use FP only
                let result = RecognitionResult(
                    itemID: candidate.id,
                    itemName: candidate.name,
                    similarity: fpScore,
                    fpScore: fpScore,
                    mlScore: 0
                )
                if bestResult == nil || result.similarity > bestResult!.similarity {
                    bestResult = result
                }
                continue
            }

            let combined = fpScore * fpWeight + mlScore * mlWeight
            let result = RecognitionResult(
                itemID: candidate.id,
                itemName: candidate.name,
                similarity: combined,
                fpScore: fpScore,
                mlScore: mlScore
            )
            if bestResult == nil || result.similarity > bestResult!.similarity {
                bestResult = result
            }
        }

        return bestResult
    }

    /// Simplified: compute similarity against a single item.
    func computeSimilarity(
        queryImage: CGImage,
        featurePrintDataList: [Data]
    ) async -> Float {
        do {
            return try await featurePrintService.bestSimilarity(
                queryImage: queryImage,
                references: featurePrintDataList
            )
        } catch {
            return 0
        }
    }
}
