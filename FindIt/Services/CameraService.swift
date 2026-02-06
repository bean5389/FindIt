@preconcurrency import AVFoundation
import UIKit
import ARKit

@Observable
final class CameraService: NSObject, @unchecked Sendable {
    // Standard camera properties
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "me.bean5389.FindIt.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    // ARKit properties for LiDAR
    let arSession = ARSession()
    private let arConfiguration: ARWorldTrackingConfiguration = {
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        return config
    }()

    private(set) var isRunning = false
    private(set) var permissionGranted = false
    private(set) var isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    /// Callback for each throttled video frame. Called on MainActor.
    var onFrame: ((CGImage) -> Void)?

    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    // Throttle: process at most ~8 fps
    private let frameInterval: TimeInterval = 1.0 / 8.0
    @ObservationIgnored
    private nonisolated(unsafe) var lastFrameTime: TimeInterval = 0

    override init() {
        super.init()
        arSession.delegate = self
    }

    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            permissionGranted = false
        }
        return permissionGranted
    }

    func configure() {
        if isLiDARAvailable {
            // ARKit doesn't need pre-configuration like AVCaptureSession for basic frame access
        } else {
            sessionQueue.async { [weak self] in
                self?.configureSession()
            }
        }
    }

    func start() {
        if isLiDARAvailable {
            arSession.run(arConfiguration, options: [.resetTracking, .removeExistingAnchors])
            DispatchQueue.main.async {
                self.isRunning = true
            }
        } else {
            sessionQueue.async { [weak self] in
                guard let self, !self.session.isRunning else { return }
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }

    func stop() {
        if isLiDARAvailable {
            arSession.pause()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        } else {
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else { return }
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }

    func capturePhoto() async -> UIImage? {
        if isLiDARAvailable {
            // Get current frame from ARSession
            guard let frame = arSession.currentFrame else { return nil }
            let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        } else {
            return await withCheckedContinuation { continuation in
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                let output = self.photoOutput
                sessionQueue.async {
                    output.capturePhoto(with: settings, delegate: self)
                }
            }
        }
    }

    /// Captures current frame with depth map (LiDAR only)
    func capturePhotoWithDepth() async -> (image: UIImage, depthMap: CVPixelBuffer)? {
        guard isLiDARAvailable, let frame = arSession.currentFrame else { return nil }
        guard let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap else { return nil }

        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)

        return (image, depthMap)
    }

    /// Performs a hit test or uses depth data to find the depth at a normalized point.
    func getDepth(at point: CGPoint) -> Float? {
        guard isLiDARAvailable, let frame = arSession.currentFrame else { return nil }
        guard let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap else { return nil }

        // Map point to depth map coordinates
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let x = Int(point.x * CGFloat(width))
        let y = Int(point.y * CGFloat(height))

        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self)
        let index = y * width + x
        return floatBuffer?[index]
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(cgImage)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage?
        if let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        } else {
            image = nil
        }

        DispatchQueue.main.async { [weak self] in
            let continuation = self?.photoContinuation
            self?.photoContinuation = nil
            continuation?.resume(returning: image)
        }
    }
}

extension CameraService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now

        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        // ARKit capturedImage is often rotated.
        let rotated = ciImage.oriented(.right)

        guard let cgImage = context.createCGImage(rotated, from: rotated.extent) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(cgImage)
        }
    }
}
