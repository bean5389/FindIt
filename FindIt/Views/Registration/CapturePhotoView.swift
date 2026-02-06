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
                    GeometryReader { geo in
                        Group {
                            if cameraService.isLiDARAvailable {
                                CameraPreviewView(arSession: cameraService.arSession)
                            } else {
                                CameraPreviewView(session: cameraService.session)
                            }
                        }
                        .onTapGesture { location in
                            // Normalize location (0 to 1)
                            let normalizedPoint = CGPoint(
                                x: location.x / geo.size.width,
                                y: location.y / geo.size.height
                            )

                            Task {
                                // Use LiDAR depth if available
                                if cameraService.isLiDARAvailable,
                                   let capture = await cameraService.capturePhotoWithDepth() {
                                    await viewModel.segmentAndAddPhoto(
                                        at: normalizedPoint,
                                        in: capture.image,
                                        depthMap: capture.depthMap
                                    )
                                } else if let image = await cameraService.capturePhoto() {
                                    await viewModel.segmentAndAddPhoto(at: normalizedPoint, in: image)
                                }
                            }
                        }
                    }
                    .ignoresSafeArea()

                    // Instruction overlay
                    VStack {
                        Text("사물을 탭해서 선택하세요")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(.top, 60)
                            .accessibilityLabel("카메라 프리뷰에서 등록할 사물을 탭하세요")
                        Spacer()
                    }
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
                        HapticHelper.prepare(for: .medium)
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
                    .accessibilityLabel("사진 촬영")
                    .accessibilityHint("전체 사진을 촬영합니다")

                    Spacer()

                    if viewModel.canProceedToInfo {
                        Button("다음") {
                            HapticHelper.buttonTap()
                            viewModel.proceedToInfo()
                        }
                        .fontWeight(.semibold)
                        .accessibilityLabel("다음 단계로")
                        .accessibilityHint("물건 정보 입력 화면으로 이동합니다")
                    } else {
                        Text("최소 3장")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("최소 3장 촬영 필요")
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
