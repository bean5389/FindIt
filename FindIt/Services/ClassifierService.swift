import UIKit
import Vision
import Observation

/// A custom k-NN classifier using Vision Feature Prints.
actor ClassifierService {
    static let shared = ClassifierService()

    struct ClassificationResult: Sendable {
        let label: String // Item Name
        let itemID: UUID
        let confidence: Float
    }

    private struct TrainingData: Sendable {
        let itemID: UUID
        let itemName: String
        let observation: VNFeaturePrintObservation
    }

    enum TrainingStatus: Sendable {
        case idle
        case training(progress: Double)
        case ready(sampleCount: Int, duration: TimeInterval)
        case failed(error: String)
    }

    private var trainingDataset: [TrainingData] = []
    private(set) var isModelAvailable: Bool = false
    var trainingStatus: TrainingStatus = .idle
    private(set) var totalSamples: Int = 0

    // Hyperparameters
    private let k: Int = 3 // Number of neighbors to consider

    // Performance metrics
    private var lastTrainingDuration: TimeInterval = 0
    private var lastClassificationTime: TimeInterval = 0

    /// Classify an image using k-NN.
    func classify(_ cgImage: CGImage) async -> ClassificationResult? {
        guard isModelAvailable, !trainingDataset.isEmpty else { return nil }

        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            lastClassificationTime = CFAbsoluteTimeGetCurrent() - startTime
        }

        do {
            // 1. Extract feature print from query
            let queryObservation = try await FeaturePrintService.shared.extractFeaturePrint(from: cgImage)

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
            print("❌ Classification error: \(error)")
            return nil
        }
    }

    /// Train the classifier (Load data into memory).
    func train(items: [TargetItem]) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        trainingStatus = .training(progress: 0.0)

        var newDataset: [TrainingData] = []
        let totalPhotos = items.reduce(0) { $0 + $1.photos.count }
        var processedPhotos = 0

        print("🎓 Training classifier with \(items.count) items (\(totalPhotos) photos)...")

        for item in items {
            for photo in item.photos {
                do {
                    let observation = try await FeaturePrintService.shared.deserializeFeaturePrint(photo.featurePrintData)
                    let data = TrainingData(
                        itemID: item.id,
                        itemName: item.name,
                        observation: observation
                    )
                    newDataset.append(data)

                    processedPhotos += 1
                    let progress = Double(processedPhotos) / Double(totalPhotos)
                    trainingStatus = .training(progress: progress)
                } catch {
                    print("⚠️ Failed to load feature print for item \(item.name): \(error)")
                }
            }
        }

        self.trainingDataset = newDataset
        self.isModelAvailable = !newDataset.isEmpty
        self.totalSamples = newDataset.count

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        self.lastTrainingDuration = duration

        if newDataset.isEmpty {
            trainingStatus = .failed(error: "No valid training data")
        } else {
            trainingStatus = .ready(sampleCount: newDataset.count, duration: duration)
        }

        print("✅ Classifier trained. Samples: \(newDataset.count), Duration: \(String(format: "%.2f", duration))s")
    }

    /// Get performance metrics for debugging
    func getMetrics() -> (trainingDuration: TimeInterval, classificationTime: TimeInterval, samples: Int) {
        return (lastTrainingDuration, lastClassificationTime, totalSamples)
    }
}
