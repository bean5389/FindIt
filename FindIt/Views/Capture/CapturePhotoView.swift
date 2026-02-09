import SwiftUI
import AVFoundation

struct CapturePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraService = CameraService()
    @State private var segmentationService = SegmentationService()
    @State private var visionService = VisionService()
    
    @State private var detectedObjects: [DetectedObject] = []
    @State private var selectedObject: DetectedObject?
    @State private var capturedImage: UIImage?  // 선택 시점의 이미지 저장
    @State private var croppedPreviewImage: UIImage?  // 크롭된 미리보기 이미지
    @State private var showConfirmationSheet = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var detectionTimer: Timer?
    
    let onObjectSelected: (UIImage, Data) -> Void
    
    var body: some View {
        ZStack {
            // 카메라 프리뷰
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
            
            // 바운딩 박스 오버레이 & 터치 영역 (선택 전이고 모달이 안 떠있을 때만)
            if selectedObject == nil && !showConfirmationSheet {
                GeometryReader { geometry in
                    ZStack {
                        // 감지된 모든 사물 표시
                        ForEach(detectedObjects) { object in
                            BoundingBoxOverlay(
                                object: object,
                                frameSize: geometry.size,
                                isSelected: false
                            )
                        }

                        // 터치 영역
                        ForEach(detectedObjects) { object in
                            TouchableBox(
                                object: object,
                                frameSize: geometry.size,
                                onTap: { selectObject(object) }
                            )
                        }
                    }
                }
                .allowsHitTesting(!isProcessing)
            }
            
            // UI Controls
            VStack {
                // 상단: 닫기 버튼 & 감지된 사물 개수
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                    
                    if !detectedObjects.isEmpty {
                        Text("\(detectedObjects.count)개 감지됨")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding()
                
                Spacer()
                
                // 하단: 안내 메시지
                VStack(spacing: 16) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                        Text("처리 중...")
                            .foregroundStyle(.white)
                    } else if detectedObjects.isEmpty {
                        Text("사물을 화면에 담아주세요")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else if selectedObject == nil {
                        Text("초록색 박스를 탭하거나\n사물을 직접 탭해주세요")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            await setupCamera()
        }
        .onDisappear {
            detectionTimer?.invalidate()
            detectionTimer = nil
            cameraService.stopSession()
        }
        .alert("오류", isPresented: $showError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
        .sheet(isPresented: $showConfirmationSheet) {
            if let previewImage = croppedPreviewImage, let selected = selectedObject {
                ObjectConfirmationView(
                    previewImage: previewImage,
                    onConfirm: {
                        showConfirmationSheet = false
                        confirmSelection(selected)
                    },
                    onCancel: {
                        showConfirmationSheet = false
                    }
                )
            }
        }
        .onChange(of: showConfirmationSheet) { oldValue, newValue in
            if newValue {
                // 모달이 올라올 때: 실시간 감지 멈추기
                stopRealtimeDetection()
            } else if oldValue && !newValue {
                // 모달이 닫힐 때 (스와이프, 밖 터치, 취소 버튼 등): 상태 초기화 및 실시간 감지 재시작
                selectedObject = nil
                croppedPreviewImage = nil
                detectedObjects = []  // 이전 바운딩 박스 제거
                startRealtimeDetection()
            }
        }
    }
    
    private func setupCamera() async {
        do {
            try await cameraService.setupSession()
            cameraService.startSession()
            
            startRealtimeDetection()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func startRealtimeDetection() {
        // 기존 타이머가 있으면 먼저 정리
        stopRealtimeDetection()

        detectionTimer = Timer.scheduledTimer(withTimeInterval: Constants.Capture.detectionInterval, repeats: true) { _ in
            Task {
                await detectObjectsInCurrentFrame()
            }
        }
    }

    private func stopRealtimeDetection() {
        detectionTimer?.invalidate()
        detectionTimer = nil
    }

    private func detectObjectsInCurrentFrame() async {
        guard !isProcessing, selectedObject == nil else { return }

        do {
            let image = try await cameraService.capturePhoto()
            let allObjects = try await segmentationService.detectObjects(in: image)

            // 화면 경계를 벗어나는 객체 필터링 (완전히 화면 안에 있는 것만)
            let margin = Constants.Capture.screenBoundaryMargin
            let visibleObjects = allObjects.filter { object in
                let box = object.boundingBox
                return box.minX >= margin &&
                       box.minY >= margin &&
                       box.maxX <= 1 - margin &&
                       box.maxY <= 1 - margin
            }

            await MainActor.run {
                // 선택되지 않은 경우에만 업데이트
                if selectedObject == nil {
                    detectedObjects = visibleObjects
                }
            }
        } catch {
        }
    }
    
    private func selectObject(_ object: DetectedObject) {
        // 사물을 선택하는 순간 이미지 캡처
        Task {
            do {
                let image = try await cameraService.capturePhoto()
                let cropped = cropImage(image, to: object.boundingBox)

                await MainActor.run {
                    capturedImage = image  // 선택 시점의 이미지 저장
                    croppedPreviewImage = cropped  // 크롭된 미리보기 이미지
                    selectedObject = object
                    showConfirmationSheet = true  // 모달 표시
                }
            } catch {
                // 캡처 실패 시 에러 처리
                await MainActor.run {
                    errorMessage = "이미지 캡처에 실패했습니다."
                    showError = true
                }
            }
        }
    }
    
    private func confirmSelection(_ object: DetectedObject) {
        Task {
            isProcessing = true
            
            do {
                // 선택 시점에 저장해둔 이미지 사용
                guard let image = capturedImage else {
                    throw CaptureError.noImageAvailable
                }
                
                let croppedImage = cropImage(image, to: object.boundingBox)
                
                let featurePrintData = try await visionService.extractFeaturePrint(from: croppedImage)
                
                onObjectSelected(croppedImage, featurePrintData)
                
                dismiss()
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func cropImage(_ image: UIImage, to normalizedRect: CGRect) -> UIImage {
        let imageSize = image.size
        let scale = image.scale
        
        // bounding box를 확장
        let expandRatio = Constants.Capture.boundingBoxExpandRatio
        let expandWidth = normalizedRect.width * expandRatio
        let expandHeight = normalizedRect.height * expandRatio
        
        let expandedRect = CGRect(
            x: max(0, normalizedRect.minX - expandWidth / 2),
            y: max(0, normalizedRect.minY - expandHeight / 2),
            width: min(1.0 - normalizedRect.minX + expandWidth / 2, normalizedRect.width + expandWidth),
            height: min(1.0 - normalizedRect.minY + expandHeight / 2, normalizedRect.height + expandHeight)
        )
        
        // bounding box는 이미 top-left origin (픽셀 버퍼 좌표계)
        let rect = CGRect(
            x: expandedRect.minX * imageSize.width,
            y: expandedRect.minY * imageSize.height,
            width: expandedRect.width * imageSize.width,
            height: expandedRect.height * imageSize.height
        )
        
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if context.coordinator.previewLayer == nil, let previewLayer = cameraService.makePreviewLayer() {
            context.coordinator.previewLayer = previewLayer
            uiView.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.main.async {
            if let previewLayer = context.coordinator.previewLayer {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.frame = uiView.bounds
                CATransaction.commit()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

struct BoundingBoxOverlay: View {
    let object: DetectedObject
    let frameSize: CGSize
    let isSelected: Bool

    var body: some View {
        let box = object.boundingBox
        let maskSize = object.maskImage.size

        // 마스크 이미지를 화면 크기에 맞게 스케일
        let widthScale = frameSize.width / maskSize.width
        let heightScale = frameSize.height / maskSize.height
        let scale = max(widthScale, heightScale) * Constants.Capture.maskScaleFactor

        let scaledWidth = maskSize.width * scale
        let scaledHeight = maskSize.height * scale

        // 중앙 정렬 오프셋
        let offsetX = (frameSize.width - scaledWidth) / 2
        let offsetY = (frameSize.height - scaledHeight) / 2

        // bounding box를 스케일된 좌표계로 변환
        let scaledBox = CGRect(
            x: box.minX * scaledWidth + offsetX,
            y: box.minY * scaledHeight + offsetY,
            width: box.width * scaledWidth,
            height: box.height * scaledHeight
        )

        RoundedRectangle(cornerRadius: Constants.Capture.boundingBoxCornerRadius)
            .stroke(isSelected ? Color.yellow : Color.green, lineWidth: Constants.Capture.boundingBoxLineWidth)
            .frame(width: scaledBox.width, height: scaledBox.height)
            .position(x: scaledBox.midX, y: scaledBox.midY)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: Constants.Capture.selectionAnimationDuration), value: isSelected)
    }
}

struct TouchableBox: View {
    let object: DetectedObject
    let frameSize: CGSize
    let onTap: () -> Void
    
    var body: some View {
        let box = object.boundingBox
        let maskSize = object.maskImage.size
        
        // ContourOverlay와 동일한 스케일 계산
        let widthScale = frameSize.width / maskSize.width
        let heightScale = frameSize.height / maskSize.height
        let scale = max(widthScale, heightScale) * Constants.Capture.maskScaleFactor
        
        let scaledWidth = maskSize.width * scale
        let scaledHeight = maskSize.height * scale
        
        // 중앙 정렬 오프셋
        let offsetX = (frameSize.width - scaledWidth) / 2
        let offsetY = (frameSize.height - scaledHeight) / 2
        
        // bounding box를 스케일된 좌표계로 변환
        // box는 이미 top-left origin (픽셀 버퍼 좌표계)
        let scaledBox = CGRect(
            x: box.minX * scaledWidth + offsetX,
            y: box.minY * scaledHeight + offsetY,
            width: box.width * scaledWidth,
            height: box.height * scaledHeight
        )

        // 터치 영역을 확대하여 선택을 쉽게 만듦
        let expandRatio = Constants.Capture.touchAreaExpandRatio
        let touchWidth = scaledBox.width * (1 + expandRatio)
        let touchHeight = scaledBox.height * (1 + expandRatio)

        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: touchWidth, height: touchHeight)
            .position(
                x: scaledBox.midX,
                y: scaledBox.midY
            )
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Object Confirmation View
struct ObjectConfirmationView: View {
    let previewImage: UIImage
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // 상단 바
            HStack {
                Text("선택한 사물 확인")
                    .font(.headline)

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            // 이미지 미리보기
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 10)
                .padding(.horizontal)

            Text("이 사물을 등록하시겠습니까?")
                .font(.title3)
                .fontWeight(.medium)

            Spacer()

            // 버튼
            HStack(spacing: 16) {
                Button {
                    onCancel()
                } label: {
                    Text("취소")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.red, in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onConfirm()
                } label: {
                    Text("확인")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Errors
enum CaptureError: LocalizedError {
    case noImageAvailable
    
    var errorDescription: String? {
        switch self {
        case .noImageAvailable:
            return "저장된 이미지가 없습니다."
        }
    }
}

// MARK: - Preview
#Preview {
    CapturePhotoView { image, featurePrint in
        print("Selected image: \(image.size)")
        print("Feature print: \(featurePrint.count) bytes")
    }
}
