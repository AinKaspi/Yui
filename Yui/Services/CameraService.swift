import Foundation
import AVFoundation
import UIKit

protocol CameraServiceProtocol {
    func start()
    func stop()
    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer)
    var delegate: CameraServiceDelegate? { get set }
}

protocol CameraServiceDelegate: AnyObject {
    func didOutput(sampleBuffer: CMSampleBuffer)
}

class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, CameraServiceProtocol {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    weak var delegate: CameraServiceDelegate?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to find front camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Failed to create camera input: \(error)")
            return
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }
    
    func start() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer?.connection?.isVideoMirrored = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.didOutput(sampleBuffer: sampleBuffer)
    }
}
