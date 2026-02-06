import SwiftUI

struct CapturePhotoView: View {
    @Bindable var viewModel: RegistrationViewModel
    @State private var cameraService = CameraService()
    @State private var isCameraReady = false

    var body: some View {
        VStack(spacing: 0) {
            // Camera preview
            ZStack {
                if isCameraReady {
                    CameraPreviewView(session: cameraService.session)
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                // Angle guide overlay
                VStack {
                    Spacer()
                    angleGuideLabel
                    Spacer().frame(height: 16)
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom controls
            VStack(spacing: 16) {
                // Thumbnails scroll
                if !viewModel.capturedPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.capturedPhotos.enumerated()), id: \.offset) { index, photo in
                                PhotoThumbnailView(
                                    image: photo.image,
                                    angle: photo.angle
                                ) {
                                    viewModel.removePhoto(at: index)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 100)
                }

                // Capture button + count
                HStack {
                    Text("\(viewModel.capturedPhotos.count)장 촬영됨")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task {
                            if let image = await cameraService.capturePhoto() {
                                viewModel.addPhoto(image)
                            }
                        }
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle()
                                    .stroke(.gray, lineWidth: 3)
                                    .frame(width: 62, height: 62)
                            }
                    }

                    Spacer()

                    if viewModel.canProceedToInfo {
                        Button("다음") {
                            viewModel.proceedToInfo()
                        }
                        .fontWeight(.semibold)
                    } else {
                        Text("최소 3장")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(.ultraThinMaterial)
        }
        .task {
            let granted = await cameraService.requestPermission()
            if granted {
                cameraService.configure()
                cameraService.start()
                isCameraReady = true
            }
        }
        .onDisappear {
            cameraService.stop()
        }
    }

    private var angleGuideLabel: some View {
        Text(viewModel.currentAngleGuide)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.black.opacity(0.6), in: Capsule())
    }
}
