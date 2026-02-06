import Vision
import UIKit

actor RecognitionService {
    static let shared = RecognitionService()

    private let featurePrintService = FeaturePrintService.shared
    private let classifierService = ClassifierService.shared

    // Weights for hybrid score (Feature Print is more reliable)
    private let fpWeight: Float = 0.8
    private let mlWeight: Float = 0.2

    struct RecognitionResult: Sendable {
        let itemID: UUID
        let itemName: String
        let similarity: Float
        let fpScore: Float
        let mlScore: Float
    }

    /// Recognize which registered item best matches the query image (1:N Identification).
    func recognize(
        queryImage: CGImage,
        candidates: [(id: UUID, name: String, featurePrintDataList: [Data])]
    ) async -> RecognitionResult? {
        // 1. Get ML Classification result (Global search)
        let mlResult = await classifierService.classify(queryImage)
        
        var bestResult: RecognitionResult?

        for candidate in candidates {
            guard !candidate.featurePrintDataList.isEmpty else { continue }

            // 2. Feature Print similarity (1-NN within this candidate's photos)
            let fpScore: Float
            do {
                fpScore = try await featurePrintService.bestSimilarity(
                    queryImage: queryImage,
                    references: candidate.featurePrintDataList
                )
            } catch {
                continue
            }

            // 3. ML Score
            let mlScore: Float
            if let mlResult, mlResult.itemID == candidate.id {
                mlScore = mlResult.confidence
            } else {
                mlScore = 0
            }

            // 4. Combine
            // If ML model is not available, fall back to FP only (re-normalize weight if needed, 
            // but here we just accept lower scores or assume ML weight is 0 effectively)
            let combined: Float
            if await classifierService.isModelAvailable {
                combined = fpScore * fpWeight + mlScore * mlWeight
            } else {
                combined = fpScore
            }

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

    /// Compute hybrid score for a specific target (1:1 Verification).
    /// Used in Game Mode.
    func computeHybridMatch(
        queryImage: CGImage,
        targetID: UUID,
        references: [Data]
    ) async -> Float {
        // 1. Feature Print Score
        let fpScore: Float
        do {
            fpScore = try await featurePrintService.bestSimilarity(
                queryImage: queryImage,
                references: references
            )
        } catch {
            fpScore = 0
        }

        // 2. ML Classification Score
        let mlScore: Float
        if await classifierService.isModelAvailable,
           let mlResult = await classifierService.classify(queryImage),
           mlResult.itemID == targetID {
            mlScore = mlResult.confidence
        } else {
            mlScore = 0
        }

        // 3. Combine
        if await classifierService.isModelAvailable {
             return fpScore * fpWeight + mlScore * mlWeight
        } else {
            return fpScore
        }
    }

    /// Legacy support: simplified similarity
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
