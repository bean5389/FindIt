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
    private let matchThreshold: Float = 0.8

    private var featurePrintDataList: [Data] = []
    private let recognitionService = RecognitionService.shared

    enum FeedbackLevel: Sendable {
        case cold    // < 0.3
        case warm    // 0.3 ~ 0.6
        case hot     // 0.6 ~ 0.8
        case match   // >= 0.8

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
        let score = await recognitionService.computeSimilarity(
            queryImage: cgImage,
            featurePrintDataList: featurePrintDataList
        )

        await MainActor.run {
            self.similarity = score
            self.updateFeedbackLevel(score)
            self.checkMatch(score)
        }
    }

    private func updateFeedbackLevel(_ score: Float) {
        switch score {
        case 0.8...:
            feedbackLevel = .match
        case 0.6..<0.8:
            feedbackLevel = .hot
        case 0.3..<0.6:
            feedbackLevel = .warm
        default:
            feedbackLevel = .cold
        }
    }

    private func checkMatch(_ score: Float) {
        if score >= matchThreshold {
            if matchStartTime == nil {
                matchStartTime = Date()
            } else if let start = matchStartTime,
                      Date().timeIntervalSince(start) >= matchDuration {
                isFound = true
                cameraService.onFrame = nil
                cameraService.stop()
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
