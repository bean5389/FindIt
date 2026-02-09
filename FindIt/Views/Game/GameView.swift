import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    let treasure: TreasureItem
    
    @State private var cameraService = CameraService()
    @State private var visionService = VisionService()
    @State private var segmentationService = SegmentationService()

    @State private var matchLevel: MatchLevel = .cold
    @State private var similarity: Float = 0
    @State private var bestMatchBox: CGRect?
    @State private var matchHoldTime: TimeInterval = 0
    @State private var isFound = false
    @State private var matchingTimer: Timer?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showHint = false
    
    var body: some View {
        ZStack {
            if isFound {
                successView
            } else {
                gamePlayView
            }
        }
        .task {
            await setupCamera()
        }
        .onDisappear {
            matchingTimer?.invalidate()
            matchingTimer = nil
            cameraService.stopSession()
        }
        .alert("오류", isPresented: $showError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }
    
    // MARK: - Game Play View
    private var gamePlayView: some View {
        ZStack {
            // 카메라 프리뷰 (전체 화면)
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
            
            // 매칭 바운딩 박스
            if let box = bestMatchBox {
                GeometryReader { geometry in
                    let rect = CGRect(
                        x: box.minX * geometry.size.width,
                        y: box.minY * geometry.size.height,
                        width: box.width * geometry.size.width,
                        height: box.height * geometry.size.height
                    )
                    RoundedRectangle(cornerRadius: Constants.Game.detectionBoxCornerRadius)
                        .stroke(Color(matchLevel.color), lineWidth: Constants.Game.detectionBoxLineWidth)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.origin.x)
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.origin.y)
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.size.width)
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.size.height)
            }

            // 피드백 테두리
            if matchLevel != .cold {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color(matchLevel.color), lineWidth: Constants.Game.feedbackBorderWidth)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: matchLevel)
            }
            
            // 힌트 오버레이
            if showHint,
               let photoData = treasure.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .opacity(0.5)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // UI 오버레이
            VStack {
                // 상단 바
                topBar
                
                Spacer()
                
                // 하단: 미션 카드 + 상태 텍스트
                bottomPanel
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
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
            
            Text("보물을 찾아라!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHint.toggle()
                }
            } label: {
                Image(systemName: showHint ? "eye.fill" : "eye")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding()
    }
    
    // MARK: - Bottom Panel
    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // 미션 카드
            missionCard
            
            // 상태 텍스트 + 매칭률
            if matchLevel != .cold {
                VStack(spacing: 6) {
                    Text(matchLevel.description)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(matchLevel.color))
                    
                    Text("\(Int(similarity * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .animation(.easeInOut(duration: 0.3), value: matchLevel)
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Mission Card
    private var missionCard: some View {
        HStack(spacing: 12) {
            // 보물 사진
            if let photoData = treasure.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Constants.Game.missionImageSize, height: Constants.Game.missionImageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: Constants.Game.missionImageSize, height: Constants.Game.missionImageSize)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            
            // 보물 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(treasure.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if !treasure.hint.isEmpty {
                    Text("힌트: \(treasure.hint)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 2) {
                    ForEach(Constants.UI.minDifficulty...Constants.UI.maxDifficulty, id: \.self) { star in
                        Image(systemName: star <= treasure.difficulty ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .frame(height: Constants.Game.missionCardHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Success View
    private var successView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 보물 사진
                if let photoData = treasure.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green, lineWidth: 4)
                        )
                }
                
                // 찾았다! 텍스트
                VStack(spacing: 8) {
                    Text("🎉")
                        .font(.system(size: 60))
                    
                    Text("찾았다!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    
                    Text(treasure.name)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // 홈으로 버튼
                Button {
                    dismiss()
                } label: {
                    Text("홈으로")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Camera Setup
    private func setupCamera() async {
        do {
            try await cameraService.setupSession()
            cameraService.startSession()
            startMatching()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Matching Logic
    private func startMatching() {
        matchingTimer = Timer.scheduledTimer(withTimeInterval: Constants.Game.matchingInterval, repeats: true) { _ in
            Task {
                await performMatching()
            }
        }
    }
    
    private func performMatching() async {
        guard !isFound else { return }
        guard let featurePrintData = treasure.featurePrintData else { return }

        do {
            let image = try await cameraService.capturePhoto()
            let currentSimilarity = try await visionService.computeSimilarity(
                between: image,
                and: featurePrintData
            )

            let newLevel = visionService.matchLevel(for: currentSimilarity)

            // warm 이상이면 세그먼테이션으로 가장 유사한 사물 찾기
            var detectedBox: CGRect?
            if newLevel != .cold {
                detectedBox = await findBestMatchBox(in: image, featurePrintData: featurePrintData)
            }

            await MainActor.run {
                similarity = currentSimilarity
                matchLevel = newLevel
                bestMatchBox = detectedBox

                if newLevel == .match {
                    matchHoldTime += Constants.Game.matchingInterval
                    if matchHoldTime >= Constants.Game.matchHoldDuration {
                        isFound = true
                        matchingTimer?.invalidate()
                        matchingTimer = nil
                    }
                } else {
                    matchHoldTime = 0
                }
            }
        } catch {
            // 캡처 실패 시 무시 (다음 프레임에서 재시도)
        }
    }

    private func findBestMatchBox(in image: UIImage, featurePrintData: Data) async -> CGRect? {
        guard let objects = try? await segmentationService.detectObjects(in: image) else {
            return nil
        }

        var bestSimilarity: Float = -1
        var bestBox: CGRect?

        for object in objects {
            guard let croppedImage = cropImage(image, to: object.boundingBox) else { continue }
            guard let sim = try? await visionService.computeSimilarity(
                between: croppedImage,
                and: featurePrintData
            ) else { continue }

            if sim > bestSimilarity {
                bestSimilarity = sim
                bestBox = object.boundingBox
            }
        }

        return bestBox
    }

    private func cropImage(_ image: UIImage, to normalizedRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let cropRect = CGRect(
            x: normalizedRect.minX * width,
            y: normalizedRect.minY * height,
            width: normalizedRect.width * width,
            height: normalizedRect.height * height
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}

#Preview {
    GameView(treasure: {
        let item = TreasureItem(name: "테스트 보물", hint: "힌트입니다", difficulty: 2)
        return item
    }())
}
