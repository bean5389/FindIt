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
    
    // MARK: - Animation States
    /// 성공 화면 애니메이션 상태
    @State private var successImageScale: CGFloat = 0.8
    @State private var successEmojiOpacity: Double = 0.0
    @State private var successTextOpacity: Double = 0.0
    @State private var successNameOpacity: Double = 0.0
    @State private var successButtonOpacity: Double = 0.0
    @State private var successImagePulse: CGFloat = 1.0
    
    /// 바운딩 박스 맥동 상태
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.8
    
    /// 상태 텍스트 펄스 상태
    @State private var statusTextScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            if isFound {
                successView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                gamePlayView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: Constants.Game.successTransitionDuration, dampingFraction: Constants.Game.successTransitionDamping), value: isFound)
        .task {
            await setupCamera()
            startPulseAnimation()
        }
        .onDisappear {
            matchingTimer?.invalidate()
            matchingTimer = nil
            cameraService.stopSession()
        }
        .onChange(of: isFound) { oldValue, newValue in
            if newValue {
                triggerSuccessAnimations()
            } else {
                resetSuccessAnimations()
            }
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
                    
                    ZStack {
                        // hot/match 레벨에서 맥동 후광 효과
                        if matchLevel == .hot || matchLevel == .match {
                            RoundedRectangle(cornerRadius: Constants.Game.detectionBoxCornerRadius)
                                .stroke(Color(matchLevel.color).opacity(0.4), lineWidth: Constants.Game.detectionBoxLineWidth * 2)
                                .frame(width: rect.width, height: rect.height)
                                .scaleEffect(pulseScale)
                                .opacity(pulseOpacity)
                        }
                        
                        // 메인 바운딩 박스
                        RoundedRectangle(cornerRadius: Constants.Game.detectionBoxCornerRadius)
                            .stroke(Color(matchLevel.color), lineWidth: Constants.Game.detectionBoxLineWidth)
                            .frame(width: rect.width, height: rect.height)
                    }
                    .position(x: rect.midX, y: rect.midY)
                    .animation(.easeInOut(duration: Constants.Game.boxColorTransitionDuration), value: matchLevel)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.origin.x)
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.origin.y)
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.size.width)
                .animation(.easeInOut(duration: 0.3), value: bestMatchBox?.size.height)
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
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
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
                HapticManager.shared.triggerLightImpact()
                withAnimation(.spring(response: Constants.Game.hintScaleResponse, dampingFraction: 0.6)) {
                    showHint.toggle()
                }
            } label: {
                Image(systemName: showHint ? "eye.fill" : "eye")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
                    .scaleEffect(showHint ? 1.1 : 1.0)
            }
        }
        .padding()
    }
    
    // MARK: - Bottom Panel
    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // 미션 카드
            missionCard
            
            // 상태 텍스트 + 매칭률 (cold 상태에서도 표시, 반투명)
            VStack(spacing: 6) {
                Text(matchLevel.description)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(matchLevel.color))
                    .opacity(matchLevel == .cold ? 0.6 : 1.0)
                
                Text("\(Int(similarity * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(matchLevel == .cold ? 0.5 : 1.0)
            }
            .scaleEffect(statusTextScale)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .animation(.easeInOut(duration: 0.3), value: matchLevel)
            .onChange(of: matchLevel) { oldValue, newValue in
                // matchLevel 변경 시 펄스 효과
                guard oldValue != newValue else { return }
                withAnimation(.spring(response: Constants.Game.statusPulseResponse, dampingFraction: 0.5)) {
                    statusTextScale = 1.15
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                    statusTextScale = 1.0
                }
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
                        .scaleEffect(successImageScale * successImagePulse)
                        .opacity(successImageScale > 0.85 ? 1.0 : 0.0)
                }
                
                // 찾았다! 텍스트
                VStack(spacing: 8) {
                    Text("🎉")
                        .font(.system(size: 60))
                        .opacity(successEmojiOpacity)
                    
                    Text("찾았다!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .opacity(successTextOpacity)
                    
                    Text(treasure.name)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .opacity(successNameOpacity)
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
                .opacity(successButtonOpacity)
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

            // 세그먼테이션으로 개별 사물의 최고 유사도 찾기
            let (bestSimilarity, detectedBox) = await findBestMatch(in: image, featurePrintData: featurePrintData)

            let newLevel = visionService.matchLevel(for: bestSimilarity)

            await MainActor.run {
                similarity = bestSimilarity
                
                // matchLevel 변경 감지 및 햅틱 피드백
                if matchLevel != newLevel {
                    matchLevel = newLevel
                    HapticManager.shared.triggerMatchLevelChange(to: newLevel)
                }
                
                bestMatchBox = detectedBox

                if newLevel == .match {
                    matchHoldTime += Constants.Game.matchingInterval
                    if matchHoldTime >= Constants.Game.matchHoldDuration {
                        isFound = true
                        HapticManager.shared.triggerSuccess()
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

    private func findBestMatch(in image: UIImage, featurePrintData: Data) async -> (Float, CGRect?) {
        guard let objects = try? await segmentationService.detectObjects(in: image) else {
            return (0, nil)
        }

        var bestSimilarity: Float = 0
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

        return (bestSimilarity, bestBox)
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
    
    // MARK: - Animation Helpers
    
    /// 성공 화면 순차 등장 애니메이션
    private func triggerSuccessAnimations() {
        // 0.0초: 이미지 스케일 업
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            successImageScale = 1.0
        }
        
        // 0.2초: 이모지 등장
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            successEmojiOpacity = 1.0
        }
        
        // 0.4초: "찾았다!" 텍스트
        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            successTextOpacity = 1.0
        }
        
        // 0.6초: 보물 이름
        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
            successNameOpacity = 1.0
        }
        
        // 0.8초: 홈으로 버튼
        withAnimation(.easeOut(duration: 0.3).delay(0.8)) {
            successButtonOpacity = 1.0
        }
        
        // 이미지 펄스 효과 (1초 주기)
        startImagePulseAnimation()
    }
    
    /// 성공 화면 애니메이션 상태 초기화
    private func resetSuccessAnimations() {
        successImageScale = 0.8
        successEmojiOpacity = 0.0
        successTextOpacity = 0.0
        successNameOpacity = 0.0
        successButtonOpacity = 0.0
        successImagePulse = 1.0
    }
    
    /// 이미지 펄스 효과
    private func startImagePulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            successImagePulse = 1.05
        }
    }
}

// MARK: - Pulse Animation Task

extension GameView {
    /// 바운딩 박스 맥동 애니메이션 시작
    private func startPulseAnimation() {
        Task {
            while !Task.isCancelled {
                if matchLevel == .hot || matchLevel == .match {
                    await MainActor.run {
                        withAnimation(.easeOut(duration: Constants.Game.boxPulseDuration)) {
                            pulseScale = 1.2
                            pulseOpacity = 0.0
                        }
                    }
                    try? await Task.sleep(nanoseconds: UInt64(Constants.Game.boxPulseDuration * 1_000_000_000))
                    await MainActor.run {
                        pulseScale = 1.0
                        pulseOpacity = 0.8
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
                }
            }
        }
    }
}

#Preview {
    GameView(treasure: {
        let item = TreasureItem(name: "테스트 보물", hint: "힌트입니다", difficulty: 2)
        return item
    }())
}
