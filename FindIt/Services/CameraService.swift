import AVFoundation
import UIKit

/// AVFoundation 기반 카메라 서비스
@Observable
class CameraService: NSObject {
    // MARK: - Properties
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureVideoDataOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let sessionQueue = DispatchQueue(label: "com.findit.camera.session")
    private var isSessionConfigured = false
    
    // MARK: - Lifecycle
    override init() {
        super.init()
    }
    
    // MARK: - Session Setup
    func setupSession() async throws {
        guard !isSessionConfigured else { return }
        
        let authorized = await checkAuthorization()
        guard authorized else {
            throw CameraError.notAuthorized
        }
        
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                do {
                    try self?.configureSession()
                    self?.isSessionConfigured = true
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func configureSession() throws {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // 해상도 설정 (input 추가 전에 설정)
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        
        // Input: 후면 카메라
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw CameraError.deviceNotFound
        }
        
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoInput) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(videoInput)
        
        // Output: 비디오 프레임
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.cannotAddOutput
        }
        session.addOutput(output)
        
        // 비디오 방향 설정 (Portrait 고정)
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(Constants.Camera.portraitRotationAngle) {
                connection.videoRotationAngle = Constants.Camera.portraitRotationAngle
            }
        }
        
        session.commitConfiguration()
        
        self.captureSession = session
        self.videoOutput = output
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let session = self.captureSession, session.isRunning else { return }
            
            // 진행 중인 캡처 취소
            if let continuation = self.photoCaptureContinuation, !self.photoCaptureContinuationResumed {
                self.photoCaptureContinuationResumed = true
                continuation.resume(throwing: CameraError.sessionNotRunning)
            }
            self.photoCaptureContinuation = nil
            
            // 세션 정지
            session.stopRunning()
            
            // 세션이 완전히 멈출 때까지 잠시 대기
            Thread.sleep(forTimeInterval: Constants.Camera.sessionStopDelay)
            
            // 입력/출력 제거
            session.beginConfiguration()
            
            for input in session.inputs {
                session.removeInput(input)
            }
            
            for output in session.outputs {
                session.removeOutput(output)
            }
            
            session.commitConfiguration()
            
            self.captureSession = nil
            self.videoOutput = nil
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async throws -> UIImage {
        guard let captureSession = captureSession,
              captureSession.isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        // 현재 프레임에서 사진 캡처
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: CameraError.captureFailure)
                    }
                    return
                }
                
                // 다음 프레임을 기다려서 반환
                self.photoCaptureContinuation = continuation
                self.photoCaptureContinuationResumed = resumed
            }
        }
    }
    
    private var photoCaptureContinuation: CheckedContinuation<UIImage, Error>?
    private var photoCaptureContinuationResumed = false
    
    // MARK: - Authorization
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    // MARK: - Preview Layer
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
        return layer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Photo capture를 위한 프레임 처리
        if let continuation = photoCaptureContinuation, !photoCaptureContinuationResumed {
            photoCaptureContinuationResumed = true
            
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continuation.resume(throwing: CameraError.captureFailure)
                photoCaptureContinuation = nil
                return
            }
            
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            
            guard let fullCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                continuation.resume(throwing: CameraError.captureFailure)
                photoCaptureContinuation = nil
                return
            }
            
            let imageWidth = CGFloat(fullCGImage.width)
            let imageHeight = CGFloat(fullCGImage.height)
            let targetAspect = Constants.Camera.targetAspectRatio
            let imageAspect = imageWidth / imageHeight
            
            var cropRect: CGRect
            if abs(imageAspect - targetAspect) < Constants.Camera.aspectRatioTolerance {
                cropRect = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
            } else if imageAspect > targetAspect {
                let targetWidth = imageHeight * targetAspect
                let offsetX = (imageWidth - targetWidth) / 2
                cropRect = CGRect(x: offsetX, y: 0, width: targetWidth, height: imageHeight)
            } else {
                let targetHeight = imageWidth / targetAspect
                let offsetY = (imageHeight - targetHeight) / 2
                cropRect = CGRect(x: 0, y: offsetY, width: imageWidth, height: targetHeight)
            }
            
            guard let croppedCGImage = fullCGImage.cropping(to: cropRect) else {
                continuation.resume(throwing: CameraError.captureFailure)
                photoCaptureContinuation = nil
                return
            }
            
            let image = UIImage(cgImage: croppedCGImage, scale: Constants.Camera.defaultImageScale, orientation: .up)
            continuation.resume(returning: image)
            photoCaptureContinuation = nil
        }
    }
}

// MARK: - Errors
enum CameraError: LocalizedError {
    case notAuthorized
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
    case sessionNotRunning
    case captureFailure
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "카메라 권한이 필요합니다."
        case .deviceNotFound:
            return "카메라를 찾을 수 없습니다."
        case .cannotAddInput:
            return "카메라 입력을 추가할 수 없습니다."
        case .cannotAddOutput:
            return "카메라 출력을 추가할 수 없습니다."
        case .sessionNotRunning:
            return "카메라 세션이 실행 중이 아닙니다."
        case .captureFailure:
            return "사진 캡처에 실패했습니다."
        }
    }
}
