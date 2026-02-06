import SwiftUI

struct GameView: View {
    let targetItem: TargetItem
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GameViewModel?
    @State private var cameraService = CameraService()

    var body: some View {
        ZStack {
            if let viewModel {
                if viewModel.showMissionCard {
                    MissionCardView(item: targetItem) {
                        viewModel.dismissMissionCard()
                    }
                } else if viewModel.isFound {
                    SuccessView(item: targetItem) {
                        dismiss()
                    }
                } else {
                    gamePlayView(viewModel: viewModel)
                }
            } else {
                ProgressView("카메라 준비 중...")
            }
        }
        .task {
            let granted = await cameraService.requestPermission()
            if granted {
                cameraService.configure()
            }
            viewModel = GameViewModel(targetItem: targetItem, cameraService: cameraService)
        }
        .onDisappear {
            viewModel?.cleanup()
        }
    }

    private func gamePlayView(viewModel: GameViewModel) -> some View {
        ZStack {
            // Camera feed
            CameraPreviewView(session: cameraService.session)
                .ignoresSafeArea()

            // Feedback border
            RoundedRectangle(cornerRadius: 0)
                .stroke(viewModel.feedbackLevel.borderColor, lineWidth: viewModel.feedbackLevel.borderWidth)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: viewModel.feedbackLevel.borderWidth)

            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        viewModel.cleanup()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(targetItem.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)

                        Text("을(를) 찾는 중...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                }
                .padding()

                Spacer()

                // Bottom similarity gauge
                SimilarityGaugeView(similarity: viewModel.similarity)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
    }
}
