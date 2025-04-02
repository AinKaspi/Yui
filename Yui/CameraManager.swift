import AVFoundation
import UIKit

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64)
}

class CameraManager {
    private let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var sessionQueue = DispatchQueue(label: "com.yui.cameraSessionQueue")
    
    weak var delegate: CameraManagerDelegate?
    
    func setupCamera(completion: @escaping (AVCaptureVideoPreviewLayer) -> Void) {
        print("CameraManager: Настройка камеры")
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Настройка входного устройства
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("CameraManager: Не удалось найти фронтальную камеру")
                return
            }
            self.videoDevice = device
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.videoInput = input
                }
            } catch {
                print("CameraManager: Ошибка настройки входного устройства: \(error)")
                return
            }
            
            // Настройка выхода
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.yui.videoQueue"))
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            // Настройка ориентации
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .landscapeRight
                }
            }
            
            self.captureSession.commitConfiguration()
            
            // Настройка previewLayer
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer.videoGravity = .resizeAspectFill
                print("CameraManager: Обновление frame для previewLayer: \(self.previewLayer.frame)")
                completion(self.previewLayer)
            }
        }
    }
    
    func startSession() {
        print("CameraManager: Запуск сессии")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                print("CameraManager: Сессия запущена")
            }
        }
    }
    
    func stopSession() {
        print("CameraManager: Остановка сессии")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                print("CameraManager: Сессия остановлена")
            }
        }
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewLayer.frame = frame
            print("CameraManager: Обновление frame для previewLayer: \(frame)")
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
        let orientation: UIImage.Orientation = .right // Фиксированная ориентация
        print("CameraManager: Угол поворота камеры установлен вручную: 90")
        
        let width = CVPixelBufferGetWidth(CMSampleBufferGetImageBuffer(sampleBuffer)!)
        let height = CVPixelBufferGetHeight(CMSampleBufferGetImageBuffer(sampleBuffer)!)
        print("Размеры изображения: \(width)x\(height)")
        
        delegate?.cameraManager(self, didOutput: sampleBuffer, orientation: orientation, timestamp: timestamp)
    }
}
