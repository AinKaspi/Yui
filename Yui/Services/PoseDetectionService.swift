import AVFoundation
import MediaPipeTasksVision
import UIKit
import os.log

// MARK: - Протокол PoseDetectionServiceProtocol
protocol PoseDetectionServiceProtocol {
    func detectPose(in sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64) -> PoseLandmarkerResult?
}

// MARK: - Класс для сглаживания координат
private struct SmoothedLandmark {
    var x: Float
    var y: Float
    var z: Float
    var visibility: Float
    
    init(landmark: NormalizedLandmark) {
        self.x = landmark.x
        self.y = landmark.y
        self.z = landmark.z
        self.visibility = landmark.visibility
    }
}

class PoseDetectionService: PoseDetectionServiceProtocol {
    // MARK: - Свойства
    private var poseLandmarker: PoseLandmarker?
    private let processingQueue = DispatchQueue(label: "com.yui.poseDetectionQueue", qos: .userInitiated)
    private var lastProcessedTimestamp: Int64 = 0
    private let minimumFrameInterval: Int64 = 33_333_333 // ~30 fps (1_000_000_000 / 30)
    private var smoothedLandmarks: [[SmoothedLandmark]] = []
    private let smoothingFactor: Float = 0.7 // Коэффициент экспоненциального сглаживания
    
    // MARK: - Инициализация
    init() {
        setupPoseLandmarker()
    }
    
    private func setupPoseLandmarker() {
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task", inDirectory: "Resources") else {
            os_log("PoseDetectionService: Не удалось найти модель pose_landmarker_full.task", log: OSLog.default, type: .error)
            return
        }
        
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.minPoseDetectionConfidence = 0.6 // Увеличиваем порог уверенности
        options.minPosePresenceConfidence = 0.6
        options.minTrackingConfidence = 0.6
        options.numPoses = 1 // Ограничиваем количество детектируемых поз до 1
        options.baseOptions.computeSettings = .init() // По умолчанию используем CPU, можно переключить на GPU
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
            os_log("PoseDetectionService: PoseLandmarker успешно инициализирован", log: OSLog.default, type: .debug)
        } catch {
            os_log("PoseDetectionService: Не удалось инициализировать PoseLandmarker: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Детекция позы
    func detectPose(in sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64) -> PoseLandmarkerResult? {
        os_log("PoseDetectionService: detectPose вызван с timestamp: %lld", log: OSLog.default, type: .debug, timestamp)
        
        // Пропускаем кадр, если предыдущий ещё не обработан (для ~30 fps)
        let timeSinceLastFrame = timestamp - lastProcessedTimestamp
        guard timeSinceLastFrame >= minimumFrameInterval else {
            os_log("PoseDetectionService: Пропущен кадр, слишком частые вызовы", log: OSLog.default, type: .debug)
            return nil
        }
        
        // Обновляем последний обработанный timestamp
        lastProcessedTimestamp = timestamp
        
        // Выполняем детекцию в фоновом потоке
        var detectionResult: PoseLandmarkerResult?
        let group = DispatchGroup()
        group.enter()
        
        processingQueue.async { [weak self] in
            guard let self = self else {
                group.leave()
                return
            }
            
            detectionResult = self.performPoseDetection(sampleBuffer: sampleBuffer, orientation: orientation, timestamp: timestamp)
            group.leave()
        }
        
        // Ждём завершения обработки
        group.wait()
        
        guard let result = detectionResult else {
            os_log("PoseDetectionService: Результат детекции отсутствует", log: OSLog.default, type: .debug)
            return nil
        }
        
        // Применяем сглаживание к ключевым точкам
        let smoothedResult = smoothPoseLandmarks(result: result)
        return smoothedResult
    }
    
    private func performPoseDetection(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64) -> PoseLandmarkerResult? {
        guard let poseLandmarker = poseLandmarker else {
            os_log("PoseDetectionService: PoseLandmarker не инициализирован", log: OSLog.default, type: .error)
            return nil
        }
        
        guard let image = imageFromSampleBuffer(sampleBuffer, orientation: orientation) else {
            os_log("PoseDetectionService: Не удалось преобразовать CMSampleBuffer в UIImage", log: OSLog.default, type: .error)
            return nil
        }
        
        do {
            let result = try poseLandmarker.detect(
                image: image,
                timestampInMilliseconds: Int(timestamp / 1_000_000)
            )
            os_log("PoseDetectionService: Поза успешно обнаружена", log: OSLog.default, type: .debug)
            return result
        } catch {
            os_log("PoseDetectionService: Ошибка при детекции позы: %@", log: OSLog.default, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Преобразование CMSampleBuffer в UIImage
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    // MARK: - Сглаживание ключевых точек
    private func smoothPoseLandmarks(result: PoseLandmarkerResult) -> PoseLandmarkerResult {
        guard !result.landmarks.isEmpty else {
            smoothedLandmarks.removeAll()
            return result
        }
        
        let currentLandmarks = result.landmarks[0] // Берем первую позу (numPoses = 1)
        
        // Инициализируем smoothedLandmarks, если это первый результат
        if smoothedLandmarks.isEmpty {
            smoothedLandmarks = currentLandmarks.map { SmoothedLandmark(landmark: $0) }
        }
        
        // Применяем экспоненциальное сглаживание
        for (index, landmark) in currentLandmarks.enumerated() {
            let smoothed = smoothedLandmarks[index]
            smoothedLandmarks[index].x = smoothed.x * smoothingFactor + landmark.x * (1 - smoothingFactor)
            smoothedLandmarks[index].y = smoothed.y * smoothingFactor + landmark.y * (1 - smoothingFactor)
            smoothedLandmarks[index].z = smoothed.z * smoothingFactor + landmark.z * (1 - smoothingFactor)
            smoothedLandmarks[index].visibility = smoothed.visibility * smoothingFactor + landmark.visibility * (1 - smoothingFactor)
        }
        
        // Создаём новый результат с сглаженными ключевыми точками
        let smoothedNormalizedLandmarks = smoothedLandmarks.map { landmark in
            NormalizedLandmark(
                x: landmark.x,
                y: landmark.y,
                z: landmark.z,
                visibility: landmark.visibility
            )
        }
        
        return PoseLandmarkerResult(
            landmarks: [smoothedNormalizedLandmarks],
            worldLandmarks: result.worldLandmarks,
            timestampMs: result.timestampMs
        )
    }
}
