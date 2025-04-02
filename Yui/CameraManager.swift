import AVFoundation
import UIKit // Добавляем импорт UIKit

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64)
}

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    weak var delegate: CameraManagerDelegate?
    
    override init() {
        super.init()
    }
    
    func setupCamera(completion: @escaping (AVCaptureVideoPreviewLayer) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else {
                print("Доступ к камере не предоставлен")
                return
            }
            
            self?.captureSession.sessionPreset = .high
            
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: frontCamera) else {
                print("Не удалось найти фронтальную камеру")
                return
            }
            
            if self?.captureSession.canAddInput(input) == true {
                self?.captureSession.addInput(input)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)]
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if self?.captureSession.canAddOutput(videoOutput) == true {
                self?.captureSession.addOutput(videoOutput)
            }
            
            if let connection = videoOutput.connection(with: .video) {
                connection.isVideoMirrored = true
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer?.videoGravity = .resizeAspectFill
                if let previewLayer = self.previewLayer {
                    completion(previewLayer)
                }
            }
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        previewLayer?.frame = frame
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampInSeconds = CMTimeGetSeconds(timestamp)
        guard !timestampInSeconds.isNaN, timestampInSeconds >= 0 else {
            print("Некорректная временная метка: \(timestampInSeconds)")
            return
        }
        let timestampInMilliseconds = Int64(timestampInSeconds * 1000)
        
        let orientation = getImageOrientation(from: connection)
        delegate?.cameraManager(self, didOutput: sampleBuffer, orientation: orientation, timestamp: timestampInMilliseconds)
    }
    
    private func getImageOrientation(from connection: AVCaptureConnection) -> UIImage.Orientation {
        let rotationAngle = connection.videoRotationAngle
        switch rotationAngle {
        case 90:
            return .right
        case 270:
            return .left
        case 0:
            return .up
        case 180:
            return .down
        default:
            return .right
        }
    }
}
