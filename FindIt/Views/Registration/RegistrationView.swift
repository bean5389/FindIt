import SwiftUI

struct RegistrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RegistrationViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .capture:
                    CapturePhotoView(viewModel: viewModel)
                case .info:
                    ItemInfoFormView(viewModel: viewModel)
                }
            }
            .navigationTitle(viewModel.currentStep == .capture ? "사진 촬영" : "물건 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.currentStep == .info {
                        Button("이전") {
                            viewModel.backToCapture()
                        }
                    } else {
                        Button("취소") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.currentStep == .info {
                        Button("저장") {
                            Task {
                                let success = await viewModel.save(context: modelContext)
                                if success {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!viewModel.canSave || viewModel.isProcessing)
                    }
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.4)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Feature Print 추출 중...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }
}
