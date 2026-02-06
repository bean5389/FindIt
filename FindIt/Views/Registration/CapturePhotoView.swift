import SwiftUI

struct CapturePhotoView: View {
    @Bindable var viewModel: RegistrationViewModel
    @State private var cameraService = CameraService()
    @State private var isCameraReady = false
    @State private var tapLocation: CGPoint?
    @State private var showTapIndicator = false
    @State private var segmentationStatus: String = ""
    @State private var detectedInstances: [SegmentationService.DetectedInstance] = []
    @State private var isDetecting = false
    @State private var currentFrame: CGImage?

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
                            // Show tap indicator
                            tapLocation = location
                            showTapIndicator = true
                            HapticHelper.impact(.medium)

                            // Normalize location (0 to 1)
                            let normalizedPoint = CGPoint(
                                x: location.x / geo.size.width,
                                y: location.y / geo.size.height
                            )

                            Task {
                                segmentationStatus = "사물 선택 중..."

                                // Find which instance was tapped
                                let selectedInstance = detectedInstances.first { instance in
                                    // Check if tap is inside this instance's contour
                                    isPointInContour(normalizedPoint, contour: instance.contour)
                                }

                                if let selectedInstance = selectedInstance {
                                    print("✅ 인스턴스 \(selectedInstance.id) 선택됨")
                                    segmentationStatus = "선택된 사물 추출 중..."

                                    // Capture current frame
                                    if let frame = currentFrame {
                                        let uiImage = UIImage(cgImage: frame, scale: 1.0, orientation: .right)
                                        await viewModel.segmentAndAddPhotoWithMask(
                                            selectedInstance.maskBuffer,
                                            in: uiImage
                                        )
                                    } else {
                                        segmentationStatus = "⚠️ 프레임 캡처 실패"
                                        HapticHelper.error()
                                        try? await Task.sleep(for: .seconds(2))
                                        segmentationStatus = ""
                                        showTapIndicator = false
                                        return
                                    }
                                } else {
                                    print("⚠️ 탭한 위치에 인스턴스 없음 - 일반 세그먼테이션 시도")
                                    segmentationStatus = "일반 추출 중..."

                                    // Fallback to normal segmentation
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

                                // Check if successful
                                if viewModel.errorMessage == nil {
                                    segmentationStatus = "✅ 추출 성공!"
                                    HapticHelper.success()
                                } else {
                                    segmentationStatus = "⚠️ 추출 실패"
                                    HapticHelper.error()
                                }

                                // Hide tap indicator and status after delay
                                try? await Task.sleep(for: .seconds(0.5))
                                showTapIndicator = false

                                try? await Task.sleep(for: .seconds(1.5))
                                segmentationStatus = ""
                            }
                        }
                    }
                    .ignoresSafeArea()

                    // Instance contours overlay
                    if !detectedInstances.isEmpty {
                        GeometryReader { geo in
                            Canvas { context, size in
                                for instance in detectedInstances {
                                    var path = Path()

                                    // Draw contour
                                    for (index, point) in instance.contour.enumerated() {
                                        let scaledPoint = CGPoint(
                                            x: point.x * size.width,
                                            y: point.y * size.height
                                        )

                                        if index == 0 {
                                            path.move(to: scaledPoint)
                                        } else {
                                            path.addLine(to: scaledPoint)
                                        }
                                    }

                                    // Stroke the contour
                                    context.stroke(
                                        path,
                                        with: .color(.green.opacity(0.8)),
                                        lineWidth: 2
                                    )

                                    // Fill with semi-transparent green
                                    context.fill(
                                        path,
                                        with: .color(.green.opacity(0.1))
                                    )
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }

                    // Instruction overlay
                    VStack {
                        Text(detectedInstances.isEmpty ? "사물 감지 중..." : "윤곽선을 탭해서 선택하세요")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(.top, 60)
                            .accessibilityLabel("카메라 프리뷰에서 등록할 사물을 탭하세요")
                        Spacer()
                    }

                    // Tap indicator
                    if showTapIndicator, let location = tapLocation {
                        Circle()
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 60, height: 60)
                            .position(location)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: showTapIndicator)

                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .position(location)
                            .scaleEffect(showTapIndicator ? 1.5 : 1.0)
                            .opacity(showTapIndicator ? 0.0 : 0.5)
                            .animation(.easeOut(duration: 0.6), value: showTapIndicator)
                    }

                    // Segmentation status
                    if !segmentationStatus.isEmpty {
                        VStack {
                            Spacer()
                            Text(segmentationStatus)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .background(.black.opacity(0.7), in: Capsule())
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            Spacer().frame(height: 180)
                        }
                        .animation(.spring(response: 0.3), value: segmentationStatus)
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

                // Set up frame callback for real-time instance detection
                cameraService.onFrame = { [weak cameraService] cgImage in
                    guard let cameraService, !isDetecting else { return }
                    currentFrame = cgImage

                    Task {
                        isDetecting = true
                        if let instances = try? await SegmentationService.shared.detectInstances(in: cgImage) {
                            await MainActor.run {
                                detectedInstances = instances
                            }
                        }
                        isDetecting = false
                    }
                }

                cameraService.start()
                isCameraReady = true
            }
        }
        .onDisappear {
            cameraService.onFrame = nil
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

    // MARK: - Helper Functions

    /// Check if a point is inside a contour using ray casting algorithm
    private func isPointInContour(_ point: CGPoint, contour: [CGPoint]) -> Bool {
        guard contour.count > 2 else { return false }

        var inside = false
        var j = contour.count - 1

        for i in 0..<contour.count {
            let xi = contour[i].x
            let yi = contour[i].y
            let xj = contour[j].x
            let yj = contour[j].y

            let intersect = ((yi > point.y) != (yj > point.y))
                && (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }

            j = i
        }

        return inside
    }
}
