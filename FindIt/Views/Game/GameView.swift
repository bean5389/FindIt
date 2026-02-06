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
            Group {
                if cameraService.isLiDARAvailable {
                    CameraPreviewView(arSession: cameraService.arSession)
                } else {
                    CameraPreviewView(session: cameraService.session)
                }
            }
            .ignoresSafeArea()

            // Feedback border
            RoundedRectangle(cornerRadius: 0)
                .stroke(viewModel.feedbackLevel.borderColor, lineWidth: viewModel.feedbackLevel.borderWidth)
                .ignoresSafeArea()
                .opacity(viewModel.feedbackLevel == .hot || viewModel.feedbackLevel == .match ? animateBorder : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateBorder)
                .animation(.easeInOut(duration: 0.3), value: viewModel.feedbackLevel)

            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        viewModel.cleanup()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(targetItem.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)

                        Text("을(를) 찾는 중...")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal)

                Spacer()

                // Bottom similarity gauge
                SimilarityGaugeView(similarity: viewModel.similarity)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            animateBorder = 0.6
        }
    }
    
    @State private var animateBorder: Double = 1.0
}
