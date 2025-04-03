import AVFoundation
import os.log

protocol CameraServiceProtocol {
    func setupCamera(completion: @escaping (AVCaptureVideoPreviewLayer) -> Void)
    func startSession()
    func stopSession()
    func updatePreviewLayerFrame(_ frame: CGRect)
    func updateOrientation(_ orientation: UIDeviceOrientation)
    func switchResolution(to preset: AVCaptureSession.Preset)
}

class CameraService: NSObject, CameraServiceProtocol {
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    private var currentOrientation: UIImage.Orientation = .right
    private let sessionQueue = DispatchQueue(label: "com.cameraService.sessionQueue")
    private let bufferQueue = DispatchQueue(label: "com.cameraService.bufferQueue", qos: .userInitiated)
    private var isRunning = false
    
    var onFrameCaptured: ((CMSampleBuffer, UIImage.Orientation, Int64) -> Void)?
    
    private var currentPreset: AVCaptureSession.Preset = .hd1280x720
    
    override init() {
        super.init()
    }
    
    func setupCamera(completion: @escaping (AVCaptureVideoPreviewLayer) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                os_log("CameraService: Не удалось найти фронтальную камеру", log: OSLog.default, type: .error)
                return
            }
            self.currentDevice = device
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }
            } catch {
                os_log("CameraService: Ошибка настройки входного устройства: %@", log: OSLog.default, type: .error, error.localizedDescription)
                return
            }
            
            if self.captureSession.canSetSessionPreset(self.currentPreset) {
                self.captureSession.sessionPreset = self.currentPreset
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: self.bufferQueue)
            
            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }
            
            if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            self.captureSession.commitConfiguration()
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer = previewLayer
            
            DispatchQueue.main.async {
                completion(previewLayer)
            }
        }
    }
    
    func switchResolution(to preset: AVCaptureSession.Preset) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.captureSession.canSetSessionPreset(preset) else {
                os_log("CameraService: Не удалось установить разрешение %@", log: OSLog.default, type: .error, preset.rawValue)
                return
            }
            
            self.captureSession.beginConfiguration()
            self.currentPreset = preset
            self.captureSession.sessionPreset = preset
            self.captureSession.commitConfiguration()
            os_log("CameraService: Разрешение изменено на %@", log: OSLog.default, type: .debug, preset.rawValue)
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            self.captureSession.startRunning()
            self.isRunning = true
            os_log("CameraService: Сессия запущена", log: OSLog.default, type: .debug)
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.captureSession.stopRunning()
            self.isRunning = false
            os_log("CameraService: Сессия остановлена", log: OSLog.default, type: .debug)
        }
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let previewLayer = self.previewLayer else { return }
            previewLayer.frame = frame
            os_log("CameraService: Обновление frame для previewLayer: %@", log: OSLog.default, type: .debug, NSStringFromCGRect(frame))
        }
    }
    
    func updateOrientation(_ orientation: UIDeviceOrientation) {
        switch orientation {
        case .portrait:
            currentOrientation = .right
        case .portraitUpsideDown:
            currentOrientation = .left
        case .landscapeLeft:
            currentOrientation = .up
        case .landscapeRight:
            currentOrientation = .down
        default:
            currentOrientation = .right
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self, let connection = self.videoOutput?.connection(with: .video), connection.isVideoOrientationSupported else { return }
            switch self.currentOrientation {
            case .right:
                connection.videoOrientation = .portrait
            case .left:
                connection.videoOrientation = .portraitUpsideDown
            case .up:
                connection.videoOrientation = .landscapeRight
            case .down:
                connection.videoOrientation = .landscapeLeft
            default:
                connection.videoOrientation = .portrait
            }
            os_log("CameraService: Ориентация устройства: %@", log: OSLog.default, type: .debug, String(describing: self.currentOrientation))
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            os_log("CameraService: Не удалось получить pixelBuffer", log: OSLog.default, type: .error)
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        os_log("CameraService: Размеры изображения: %dx%d", log: OSLog.default, type: .debug, width, height)
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
        onFrameCaptured?(sampleBuffer, currentOrientation, timestamp)
    }
}
