import AVFoundation
import UIKit
import os.log

// MARK: - Ошибки CameraService
enum CameraServiceError: Error {
    case cameraNotAvailable
    case inputSetupFailed(Error)
    case outputSetupFailed
    case sessionConfigurationFailed
    case permissionDenied
}

// MARK: - Протокол CameraServiceProtocol
protocol CameraServiceProtocol {
    var onFrameCaptured: ((CMSampleBuffer, UIImage.Orientation, Int64) -> Void)? { get set }
    var onError: ((CameraServiceError) -> Void)? { get set }
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    
    func setupCamera(completion: @escaping (Result<AVCaptureVideoPreviewLayer, CameraServiceError>) -> Void)
    func startSession()
    func stopSession()
    func pauseSession()
    func resumeSession()
    func updateOrientation(_ orientation: UIDeviceOrientation)
    func updatePreviewLayerFrame(_ frame: CGRect)
    func configureCameraSettings(frameRate: Float?, resolution: AVCaptureSession.Preset?)
}

class CameraService: NSObject, CameraServiceProtocol, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Свойства
    var onFrameCaptured: ((CMSampleBuffer, UIImage.Orientation, Int64) -> Void)?
    var onError: ((CameraServiceError) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.yui.camera.sessionQueue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private var deviceOrientation: UIDeviceOrientation = .portrait
    private var isSessionPaused: Bool = false
    
    // MARK: - Инициализация
    override init() {
        super.init()
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    // MARK: - Настройка камеры
    func setupCamera(completion: @escaping (Result<AVCaptureVideoPreviewLayer, CameraServiceError>) -> Void) {
        // Проверка доступа к камере
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in
                self?.configureSession(completion: completion)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.sessionQueue.async {
                        self.configureSession(completion: completion)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.permissionDenied))
                        self.onError?(.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(.failure(.permissionDenied))
                self.onError?(.permissionDenied)
            }
        @unknown default:
            DispatchQueue.main.async {
                completion(.failure(.permissionDenied))
                self.onError?(.permissionDenied)
            }
        }
    }
    
    private func configureSession(completion: @escaping (Result<AVCaptureVideoPreviewLayer, CameraServiceError>) -> Void) {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            os_log("CameraService: Не удалось найти фронтальную камеру", log: OSLog.default, type: .error)
            DispatchQueue.main.async {
                completion(.failure(.cameraNotAvailable))
                self.onError?(.cameraNotAvailable)
            }
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            self.videoDeviceInput = videoDeviceInput
        } catch {
            os_log("CameraService: Не удалось создать AVCaptureDeviceInput: %@", log: OSLog.default, type: .error, error.localizedDescription)
            DispatchQueue.main.async {
                completion(.failure(.inputSetupFailed(error)))
                self.onError?(.inputSetupFailed(error))
            }
            return
        }
        
        captureSession.beginConfiguration()
        
        // Настройка входа
        if captureSession.canAddInput(videoDeviceInput!) {
            captureSession.addInput(videoDeviceInput!)
        } else {
            os_log("CameraService: Не удалось добавить videoDeviceInput в сессию", log: OSLog.default, type: .error)
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                completion(.failure(.sessionConfigurationFailed))
                self.onError?(.sessionConfigurationFailed)
            }
            return
        }
        
        // Настройка выхода
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.yui.camera.videoQueue"))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        } else {
            os_log("CameraService: Не удалось добавить videoDataOutput в сессию", log: OSLog.default, type: .error)
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                completion(.failure(.sessionConfigurationFailed))
                self.onError?(.sessionConfigurationFailed)
            }
            return
        }
        
        // Настройка ориентации видео
        if let connection = videoDataOutput.connection(with: .video) {
            connection.isEnabled = true
            connection.videoOrientation = .portrait
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.main.async {
            completion(.success(self.previewLayer))
        }
    }
    
    // MARK: - Управление сессией
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                self.isSessionPaused = false
                os_log("CameraService: Сессия камеры запущена", log: OSLog.default, type: .debug)
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                self.isSessionPaused = false
                os_log("CameraService: Сессия камеры остановлена", log: OSLog.default, type: .debug)
            }
        }
    }
    
    func pauseSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning && !self.isSessionPaused {
                self.captureSession.stopRunning()
                self.isSessionPaused = true
                os_log("CameraService: Сессия камеры приостановлена", log: OSLog.default, type: .debug)
            }
        }
    }
    
    func resumeSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning && self.isSessionPaused {
                self.captureSession.startRunning()
                self.isSessionPaused = false
                os_log("CameraService: Сессия камеры возобновлена", log: OSLog.default, type: .debug)
            }
        }
    }
    
    // MARK: - Обновление параметров
    func updateOrientation(_ orientation: UIDeviceOrientation) {
        deviceOrientation = orientation
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            switch orientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                connection.videoOrientation = .landscapeRight
            case .landscapeRight:
                connection.videoOrientation = .landscapeLeft
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        previewLayer.frame = frame
    }
    
    func configureCameraSettings(frameRate: Float?, resolution: AVCaptureSession.Preset?) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDeviceInput?.device else { return }
            
            self.captureSession.beginConfiguration()
            
            // Настройка разрешения
            if let resolution = resolution, self.captureSession.canSetSessionPreset(resolution) {
                self.captureSession.sessionPreset = resolution
                os_log("CameraService: Установлено разрешение: %@", log: OSLog.default, type: .debug, resolution.rawValue)
            }
            
            // Настройка частоты кадров
            if let frameRate = frameRate {
                do {
                    try device.lockForConfiguration()
                    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
                    device.activeVideoMinFrameDuration = frameDuration
                    device.activeVideoMaxFrameDuration = frameDuration
                    device.unlockForConfiguration()
                    os_log("CameraService: Установлена частота кадров: %f fps", log: OSLog.default, type: .debug, frameRate)
                } catch {
                    os_log("CameraService: Не удалось установить частоту кадров: %@", log: OSLog.default, type: .error, error.localizedDescription)
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
        let orientation: UIImage.Orientation
        switch deviceOrientation {
        case .portrait:
            orientation = .right
        case .portraitUpsideDown:
            orientation = .left
        case .landscapeLeft:
            orientation = .up
        case .landscapeRight:
            orientation = .down
        default:
            orientation = .right
        }
        
        onFrameCaptured?(sampleBuffer, orientation, timestamp)
    }
}
