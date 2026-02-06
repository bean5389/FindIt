import SwiftUI
import AVFoundation
import ARKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    let arSession: ARSession?

    init(session: AVCaptureSession) {
        self.session = session
        self.arSession = nil
    }

    init(arSession: ARSession) {
        self.session = nil
        self.arSession = arSession
    }

    func makeUIView(context: Context) -> UIView {
        if let arSession = arSession {
            let arView = ARSCNView()
            arView.session = arSession
            arView.autoenablesDefaultLighting = true
            return arView
        } else {
            let view = PreviewUIView()
            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            return view
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let arSession = arSession, let arView = uiView as? ARSCNView {
            arView.session = arSession
        } else if let session = session, let previewView = uiView as? PreviewUIView {
            previewView.previewLayer.session = session
        }
    }

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
