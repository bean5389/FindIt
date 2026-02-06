import SwiftUI
import Combine

@Observable
final class GameViewModel {
    let targetItem: TargetItem
    let cameraService: CameraService

    private(set) var similarity: Float = 0
    private(set) var feedbackLevel: FeedbackLevel = .cold
    private(set) var isFound = false
    private(set) var showMissionCard = true

    private var matchStartTime: Date?
    private let matchDuration: TimeInterval = 1.0
    private let matchThreshold: Float = 0.65  // Lowered from 0.8 for better recognition

    private var featurePrintDataList: [Data] = []
    private let recognitionService = RecognitionService.shared

    enum FeedbackLevel: Sendable {
        case cold    // < 0.25
        case warm    // 0.25 ~ 0.5
        case hot     // 0.5 ~ 0.65
        case match   // >= 0.65

        var borderColor: Color {
            switch self {
            case .cold: .clear
            case .warm: .yellow
            case .hot: .orange
            case .match: .green
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .cold: 0
            case .warm: 4
            case .hot: 8
            case .match: 10
            }
        }
    }

    init(targetItem: TargetItem, cameraService: CameraService) {
        self.targetItem = targetItem
        self.cameraService = cameraService
        self.featurePrintDataList = targetItem.photos.map(\.featurePrintData)
    }

    func startGame() {
        showMissionCard = false
        cameraService.onFrame = { [weak self] cgImage in
            guard let self, !self.isFound else { return }
            Task {
                await self.processFrame(cgImage)
            }
        }
        cameraService.start()
    }

    func dismissMissionCard() {
        startGame()
    }

    private func processFrame(_ cgImage: CGImage) async {
        let score = await recognitionService.computeHybridMatch(
            queryImage: cgImage,
            targetID: targetItem.id,
            references: featurePrintDataList
        )

        await MainActor.run {
            self.similarity = score
            self.updateFeedbackLevel(score)
            self.checkMatch(score)
        }
    }

    private func updateFeedbackLevel(_ score: Float) {
        let oldLevel = feedbackLevel

        switch score {
        case 0.65...:
            feedbackLevel = .match
        case 0.5..<0.65:
            feedbackLevel = .hot
        case 0.25..<0.5:
            feedbackLevel = .warm
        default:
            feedbackLevel = .cold
        }

        // Debug logging
        if oldLevel != feedbackLevel || score > 0.3 {
            print("📊 Similarity: \(String(format: "%.3f", score)) → \(feedbackLevel)")
        }

        // Haptic feedback on level change
        if oldLevel != feedbackLevel {
            switch feedbackLevel {
            case .warm: HapticHelper.impact(.light)
            case .hot: HapticHelper.impact(.medium)
            case .match: HapticHelper.impact(.heavy)
            case .cold: break
            }
        }
    }

    private func checkMatch(_ score: Float) {
        if score >= matchThreshold {
            if matchStartTime == nil {
                matchStartTime = Date()
                HapticHelper.impact(.medium)
            } else if let start = matchStartTime,
                      Date().timeIntervalSince(start) >= matchDuration {
                isFound = true
                HapticHelper.notification(.success) // Success haptic
                cameraService.onFrame = nil
                cameraService.stop()
            } else {
                // "Ticking" feel while holding match
                HapticHelper.selection()
            }
        } else {
            matchStartTime = nil
        }
    }

    func cleanup() {
        cameraService.onFrame = nil
        cameraService.stop()
    }
}
