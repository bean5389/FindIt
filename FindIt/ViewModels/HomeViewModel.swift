import SwiftUI
import SwiftData

@Observable
final class HomeViewModel {
    var showRegistration = false
    var selectedItem: TargetItem?
    var showGame = false

    // Training state
    var isTraining = false
    var trainingProgress: Double = 0.0
    var trainingMessage: String = ""
    var showTrainingComplete = false

    func deleteItem(_ item: TargetItem, context: ModelContext) {
        context.delete(item)
        HapticHelper.delete()
    }

    func startGame(with item: TargetItem) {
        selectedItem = item
        showGame = true
    }

    func startRandomGame(items: [TargetItem]) {
        guard let item = items.randomElement() else { return }
        startGame(with: item)
    }

    func trainClassifier(items: [TargetItem]) async {
        guard !items.isEmpty else {
            isTraining = false
            return
        }

        isTraining = true
        trainingMessage = "분류기 학습 중..."

        await ClassifierService.shared.train(items: items)

        // Get training status
        let status = await ClassifierService.shared.trainingStatus

        switch status {
        case .ready(let sampleCount, let duration):
            trainingMessage = "학습 완료! (\(sampleCount)개 샘플, \(String(format: "%.1f", duration))초)"
            showTrainingComplete = true

            // Auto-hide after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    isTraining = false
                    showTrainingComplete = false
                }
            }
        case .failed(let error):
            trainingMessage = "학습 실패: \(error)"
            isTraining = false
        default:
            isTraining = false
        }
    }

    func updateTrainingProgress() async {
        let status = await ClassifierService.shared.trainingStatus

        switch status {
        case .training(let progress):
            trainingProgress = progress
        default:
            break
        }
    }
}
