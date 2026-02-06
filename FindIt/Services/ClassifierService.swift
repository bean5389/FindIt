import UIKit

/// Stub for future CreateML image classifier.
/// Will be implemented in Step 4 (ML Pipeline phase).
actor ClassifierService {
    static let shared = ClassifierService()

    struct ClassificationResult: Sendable {
        let label: String
        let confidence: Float
    }

    /// Classify an image. Currently returns a stub result.
    func classify(_ cgImage: CGImage) async -> ClassificationResult? {
        // TODO: Step 4 - Implement CreateML MLImageClassifier inference
        nil
    }

    /// Train the classifier with registered items' photos.
    func train(items: [TargetItem]) async {
        // TODO: Step 4 - Implement on-device CreateML training
    }

    /// Whether a trained model is available.
    var isModelAvailable: Bool {
        // TODO: Step 4
        false
    }
}
