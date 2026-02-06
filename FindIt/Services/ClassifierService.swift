import UIKit
import Vision

/// A custom k-NN classifier using Vision Feature Prints.
actor ClassifierService {
    static let shared = ClassifierService()

    struct ClassificationResult: Sendable {
        let label: String // Item Name
        let itemID: UUID
        let confidence: Float
    }

    private struct TrainingData {
        let itemID: UUID
        let itemName: String
        let observation: VNFeaturePrintObservation
    }

    private var trainingDataset: [TrainingData] = []
    private(set) var isModelAvailable: Bool = false
    
    // Hyperparameters
    private let k: Int = 3 // Number of neighbors to consider

    /// Classify an image using k-NN.
    func classify(_ cgImage: CGImage) async -> ClassificationResult? {
        guard isModelAvailable, !trainingDataset.isEmpty else { return nil }

        do {
            // 1. Extract feature print from query
            let queryObservation = try FeaturePrintService.shared.extractFeaturePrint(from: cgImage)

            // 2. Compute distances to all training samples
            // Note: This linear scan is O(N), which is fine for < 1000 items. 
            // For larger datasets, use a spatial index structure.
            var distances: [(distance: Float, sample: TrainingData)] = []
            distances.reserveCapacity(trainingDataset.count)

            for sample in trainingDataset {
                var dist: Float = 0
                try queryObservation.computeDistance(&dist, to: sample.observation)
                distances.append((dist, sample))
            }

            // 3. Find k nearest neighbors
            // Sort by distance ascending
            distances.sort { $0.distance < $1.distance }
            let neighbors = distances.prefix(k)

            guard !neighbors.isEmpty else { return nil }

            // 4. Vote (Weighted by inverse distance)
            var voteCounts: [UUID: Float] = [:]
            var itemNames: [UUID: String] = [:]

            for neighbor in neighbors {
                let weight = 1.0 / (neighbor.distance + 0.0001) // Avoid division by zero
                voteCounts[neighbor.sample.itemID, default: 0] += weight
                itemNames[neighbor.sample.itemID] = neighbor.sample.itemName
            }

            // 5. Determine winner
            guard let bestMatch = voteCounts.max(by: { $0.value < $1.value }) else { return nil }
            
            let winnerID = bestMatch.key
            let totalWeight = voteCounts.values.reduce(0, +)
            let confidence = bestMatch.value / totalWeight
            
            guard let winnerName = itemNames[winnerID] else { return nil }

            return ClassificationResult(
                label: winnerName,
                itemID: winnerID,
                confidence: confidence
            )

        } catch {
            print("Classification error: \(error)")
            return nil
        }
    }

    /// Train the classifier (Load data into memory).
    func train(items: [TargetItem]) async {
        var newDataset: [TrainingData] = []
        
        print("Training classifier with \(items.count) items...")

        for item in items {
            for photo in item.photos {
                do {
                    let observation = try FeaturePrintService.shared.deserializeFeaturePrint(photo.featurePrintData)
                    let data = TrainingData(
                        itemID: item.id,
                        itemName: item.name,
                        observation: observation
                    )
                    newDataset.append(data)
                } catch {
                    print("Failed to load feature print for item \(item.name): \(error)")
                }
            }
        }

        self.trainingDataset = newDataset
        self.isModelAvailable = !newDataset.isEmpty
        print("Classifier trained. Total samples: \(newDataset.count)")
    }
}
