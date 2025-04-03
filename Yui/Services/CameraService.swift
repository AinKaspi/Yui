import AVFoundation
import os.log
import UIKit

enum CameraServiceError: Error {
    case cameraNotAvailable
    case inputSetupFailed(Error)
    case outputSetupFailed
    case sessionConfigurationFailed
    case permissionDenied
}

protocol CameraServiceProtocol {
    var onFrameCaptured: ((CMSampleBuffer, UIImage.Orientation, Int64) -> Void)? { get set }
    
    func setupCamera(completion: @escaping (Result<AVCaptureVideoPreviewLayer, CameraServiceError>) -> Void)
    func startSession()
    func stopSession()
    func updatePreviewLayerFrame(_ frame: CGRect)
}

class CameraService: NSObject, CameraServiceProtocol {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.yui.cameraSessionQueue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var onFrameCaptured: ((CMSampleBuffer, UIImage.Orientation, Int64) -> Void)?
    
    override init() {
        super.init()
        checkCameraAuthorization()
    }
    
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    os_log("CameraService: Доступ к камере запрещён", log: OSLog.default, type: .error)
                }
            }
        default:
            os_log("CameraService: Доступ к камере запрещён", log: OSLog.default, type: .error)
        }
    }
    
    func setupCamera(completion: @escaping (Result<AVCaptureVideoPreviewLayer, CameraServiceError>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                os_log("CameraService: Фронтальная камера недоступна", log: OSLog.default, type: .error)
                completion(.failure(.cameraNotAvailable))
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: frontCamera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                } else {
                    os_log("CameraService: Не удалось добавить вход камеры", log: OSLog.default, type: .error)
                    completion(.failure(.inputSetupFailed(CameraServiceError.cameraNotAvailable)))
                    return
                }
            } catch {
                os_log("CameraService: Ошибка настройки входа камеры: %@", log: OSLog.default, type: .error, error.localizedDescription)
                completion(.failure(.inputSetupFailed(error)))
                return
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.yui.videoOutputQueue"))
            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
                self.videoOutput = videoOutput
            } else {
                os_log("CameraService: Не удалось добавить выход камеры", log: OSLog.default, type: .error)
                completion(.failure(.outputSetupFailed))
                return
            }
            
            self.captureSession.commitConfiguration()
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer = previewLayer
            
            DispatchQueue.main.async {
                completion(.success(previewLayer))
            }
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                os_log("CameraService: Сессия камеры запущена", log: OSLog.default, type: .debug)
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                os_log("CameraService: Сессия камеры остановлена", log: OSLog.default, type: .debug)
            }
        }
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        guard let previewLayer = previewLayer else {
            os_log("CameraService: PreviewLayer не инициализирован", log: OSLog.default, type: .error)
            return
        }
        DispatchQueue.main.async { [weak self] in
            previewLayer.frame = frame
            os_log("CameraService: PreviewLayer обновлён с новым фреймом: %@", log: OSLog.default, type: .debug, String(describing: frame)) // Заменяем NSStringFromCGRect
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let orientation: UIImage.Orientation = .leftMirrored
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
        
        onFrameCaptured?(sampleBuffer, orientation, timestamp)
    }
}
