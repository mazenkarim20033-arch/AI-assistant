import AVFoundation
import CoreImage
import SwiftUI

/// Owns the capture session: permission, start/stop, and single-photo capture.
/// Photos are downscaled and handed straight to the caller; nothing is saved to disk.
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status: Equatable {
        case checking, ready, denied, unavailable
    }

    @Published var status: Status = .checking
    @Published var isCapturing = false
    /// Called on the main thread with the captured photo.
    var onCapture: ((UIImage) -> Void)?

    /// Set before `start()` to also receive live video frames.
    var wantsFrames = false
    /// Called on the frame queue for every frame (e.g. to run object detection).
    var frameHandler: ((CVPixelBuffer) -> Void)?

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let frameOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "portal.camera")
    private let frameQueue = DispatchQueue(label: "portal.camera.frames")
    private let frameLock = NSLock()
    private var latestBuffer: CVPixelBuffer?
    private let ciContext = CIContext()
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.run()
                    } else {
                        self.status = .denied
                    }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
        frameLock.lock()
        latestBuffer = nil
        frameLock.unlock()
    }

    /// The newest video frame, downscaled. Only available when `wantsFrames` was set before starting.
    func latestFrame(maxDimension: CGFloat = 1280) -> UIImage? {
        frameLock.lock()
        let buffer = latestBuffer
        frameLock.unlock()
        guard let buffer else { return nil }
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage).downscaled(maxDimension: maxDimension)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.lock()
        latestBuffer = buffer
        frameLock.unlock()
        frameHandler?(buffer)
    }

    func capture() {
        guard status == .ready, !isCapturing else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        queue.async {
            if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90   // the app is portrait-only
            }
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation()
            .flatMap(UIImage.init(data:))?
            .downscaled(maxDimension: 1600)
        DispatchQueue.main.async {
            self.isCapturing = false
            if let image { self.onCapture?(image) }
        }
    }

    private func run() {
        queue.async {
            if !self.configured, !self.configure() {
                DispatchQueue.main.async { self.status = .unavailable }
                return
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.status = .ready }
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = wantsFrames ? .hd1920x1080 : .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else { return false }
        session.addInput(input)
        session.addOutput(output)

        if wantsFrames {
            frameOutput.alwaysDiscardsLateVideoFrames = true
            frameOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            if session.canAddOutput(frameOutput) {
                session.addOutput(frameOutput)
                frameOutput.setSampleBufferDelegate(self, queue: frameQueue)
                if let connection = frameOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90   // the app is portrait-only
                }
            }
        }
        configured = true
        return true
    }
}

/// Live camera preview.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90   // the app is portrait-only
            }
        }
    }
}
