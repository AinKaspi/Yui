import Foundation
import AVFoundation
import MediaPipeTasksVision
import os.log

// MARK: - Протокол для ViewModel
protocol ExerciseExecutionViewModelProtocol {
    var exerciseName: String { get }
    var repsCount: String { get }
    var instructionText: String? { get }
    var isInstructionHidden: Bool { get }
    
    func setup()
    func startSession()
    func stopSession()
    func updateOrientation(_ orientation: UIDeviceOrientation)
    func updatePreviewLayerFrame(_ frame: CGRect)
    func drawLandmarks(in view: PoseOverlayView)
}

class ExerciseExecutionViewModel: ExerciseExecutionViewModelProtocol {
    // MARK: - Свойства
    private let exercise: Exercise
    private let cameraService: CameraServiceProtocol
    private let poseDetectionService: PoseDetectionServiceProtocol
    private let imageProcessingService: ImageProcessingServiceProtocol
    private let visualizationService: VisualizationServiceProtocol
    
    private var lastLandmarks: [NormalizedLandmark]?
    private var smoothedLandmarks: [NormalizedLandmark]?
    private var kalmanFilters: [[KalmanFilter]]?
    private var lastHipMidpoint: (x: Float, y: Float)?
    private var framesWithoutLandmarks = 0
    private let maxFramesWithoutLandmarks = 10
    private var isPersonInFrame = false
    private var framesSincePersonReentered = 0
    private let stabilizationFrames = 5
    private var lastTimestamp: Int = 0
    private var lastImageDimensions: (width: Int, height: Int) = (1080, 1920)
    private let scaleFactor: CGFloat = 1.5
    
    // Анатомические ограничения
    private let minShoulderDistance: Float = 0.15
    private let minHipDistance: Float = 0.15
    private let minArmLength: Float = 0.1
    
    // Свойства для UI
    private var poseProcessor: PoseProcessor!
    private var repCount: Int = 0
    private var currentInstruction: String? = "Подойдите ближе к камере"
    private var isInstructionVisible: Bool = true
    
    // MARK: - Инициализация
    init(
        exercise: Exercise,
        cameraService: CameraServiceProtocol,
        poseDetectionService: PoseDetectionServiceProtocol,
        imageProcessingService: ImageProcessingServiceProtocol,
        visualizationService: VisualizationServiceProtocol
    ) {
        self.exercise = exercise
        self.cameraService = cameraService
        self.poseDetectionService = poseDetectionService
        self.imageProcessingService = imageProcessingService
        self.visualizationService = visualizationService
    }
    
    // MARK: - Протокол ExerciseExecutionViewModelProtocol
    var exerciseName: String {
        return exercise.name
    }
    
    var repsCount: String {
        return "Повторения: \(repCount)"
    }
    
    var instructionText: String? {
        return currentInstruction
    }
    
    var isInstructionHidden: Bool {
        return !isInstructionVisible
    }
    
    func setup() {
        setupCamera()
        setupPoseDetection()
        setupPoseProcessor()
    }
    
    func startSession() {
        cameraService.startSession()
    }
    
    func stopSession() {
        cameraService.stopSession()
    }
    
    func updateOrientation(_ orientation: UIDeviceOrientation) {
        cameraService.updateOrientation(orientation)
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        cameraService.updatePreviewLayerFrame(frame)
    }
    
    func drawLandmarks(in view: PoseOverlayView) {
        visualizationService.updateLandmarks(smoothedLandmarks ?? lastLandmarks, in: view)
    }
    
    // MARK: - Настройка
    private func setupCamera() {
        cameraService.onFrameCaptured = { [weak self] sampleBuffer, orientation, timestamp in
            self?.processFrame(sampleBuffer: sampleBuffer, orientation: orientation, timestamp: timestamp)
        }
    }
    
    private func setupPoseDetection() {
        poseDetectionService.setup()
    }
    
    private func setupPoseProcessor() {
        poseProcessor = PoseProcessor()
        poseProcessor.onRepCountUpdated = { [weak self] count in
            self?.repCount = count
        }
    }
    
    // MARK: - Обработка кадров
    private func processFrame(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            os_log("ExerciseExecutionViewModel: Не удалось получить pixelBuffer из sampleBuffer", log: OSLog.default, type: .error)
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        lastImageDimensions = (width: width, height: height)
        os_log("ExerciseExecutionViewModel: Размеры изображения: %dx%d", log: OSLog.default, type: .debug, width, height)
        
        guard let scaledSampleBuffer = imageProcessingService.scaleImage(sampleBuffer, scaleFactor: scaleFactor) else {
            os_log("ExerciseExecutionViewModel: Не удалось масштабировать изображение", log: OSLog.default, type: .error)
            return
        }
        
        guard let image = try? MPImage(sampleBuffer: scaledSampleBuffer, orientation: orientation) else {
            os_log("ExerciseExecutionViewModel: Не удалось преобразовать CMSampleBuffer в MPImage", log: OSLog.default, type: .error)
            return
        }
        
        let timestampInMilliseconds = max(lastTimestamp + 1, Int(timestamp / 1_000_000))
        lastTimestamp = timestampInMilliseconds
        
        poseDetectionService.detectPose(in: image, timestamp: timestampInMilliseconds) { [weak self] result, error in
            self?.handlePoseDetectionResult(result: result, error: error)
        }
    }
    
    // MARK: - Обработка результатов детекции
    private func handlePoseDetectionResult(result: PoseLandmarkerResult?, error: Error?) {
        guard let result = result, error == nil else {
            os_log("ExerciseExecutionViewModel: Ошибка обработки MediaPipe: %@", log: OSLog.default, type: .error, error?.localizedDescription ?? "Неизвестная ошибка")
            handleLandmarkLoss()
            return
        }
        
        guard let landmarks = result.landmarks.first else {
            os_log("ExerciseExecutionViewModel: Нет обнаруженных ключевых точек", log: OSLog.default, type: .debug)
            handleLandmarkLoss()
            return
        }
        
        if !isPersonInFrame {
            isPersonInFrame = true
            framesSincePersonReentered = 0
        }
        
        framesWithoutLandmarks = 0
        
        let adjustedLandmarks = applyAnatomicalConstraints(landmarks)
        
        let leftHip = adjustedLandmarks[23]
        let rightHip = adjustedLandmarks[24]
        let hipMidpointX = (leftHip.x + rightHip.x) / 2
        let hipMidpointY = (leftHip.y + rightHip.y) / 2
        lastHipMidpoint = (x: hipMidpointX, y: hipMidpointY)
        
        if framesSincePersonReentered < stabilizationFrames {
            framesSincePersonReentered += 1
            os_log("ExerciseExecutionViewModel: Период стабилизации, кадр %d/%d", log: OSLog.default, type: .debug, framesSincePersonReentered, stabilizationFrames)
            
            let predictedLandmarks = predictLandmarksDuringStabilization(adjustedLandmarks)
            isInstructionVisible = false
            smoothedLandmarks = predictedLandmarks
            return
        }
        
        let smoothed = smoothLandmarksWithKalman(adjustedLandmarks)
        lastLandmarks = adjustedLandmarks
        smoothedLandmarks = smoothed
        
        poseProcessor.processPoseLandmarks(result)
        isInstructionVisible = false
    }
    
    // MARK: - Обработка потери ключевых точек
    private func handleLandmarkLoss() {
        framesWithoutLandmarks += 1
        if framesWithoutLandmarks >= maxFramesWithoutLandmarks {
            os_log("ExerciseExecutionViewModel: Долгая потеря ключевых точек, перезапускаем трекинг", log: OSLog.default, type: .debug)
            poseDetectionService.setup()
            framesWithoutLandmarks = 0
            isPersonInFrame = false
            framesSincePersonReentered = 0
            kalmanFilters = nil
        }
        
        isInstructionVisible = true
    }
    
    // MARK: - Применение анатомических ограничений
    private func applyAnatomicalConstraints(_ landmarks: [NormalizedLandmark]) -> [NormalizedLandmark] {
        var adjustedLandmarks = landmarks
        
        let leftShoulder = adjustedLandmarks[11]
        let rightShoulder = adjustedLandmarks[12]
        let shoulderDistance = sqrt(pow(leftShoulder.x - rightShoulder.x, 2) + pow(leftShoulder.y - rightShoulder.y, 2))
        if shoulderDistance < minShoulderDistance {
            let midX = (leftShoulder.x + rightShoulder.x) / 2
            let adjustedXOffset = minShoulderDistance / 2
            adjustedLandmarks[11] = NormalizedLandmark(
                x: midX - adjustedXOffset,
                y: leftShoulder.y,
                z: leftShoulder.z,
                visibility: leftShoulder.visibility,
                presence: leftShoulder.presence
            )
            adjustedLandmarks[12] = NormalizedLandmark(
                x: midX + adjustedXOffset,
                y: rightShoulder.y,
                z: rightShoulder.z,
                visibility: rightShoulder.visibility,
                presence: rightShoulder.presence
            )
        }
        
        let leftHip = adjustedLandmarks[23]
        let rightHip = adjustedLandmarks[24]
        let hipDistance = sqrt(pow(leftHip.x - rightHip.x, 2) + pow(leftHip.y - rightHip.y, 2))
        if hipDistance < minHipDistance {
            let midX = (leftHip.x + rightHip.x) / 2
            let adjustedXOffset = minHipDistance / 2
            adjustedLandmarks[23] = NormalizedLandmark(
                x: midX - adjustedXOffset,
                y: leftHip.y,
                z: leftHip.z,
                visibility: leftHip.visibility,
                presence: leftHip.presence
            )
            adjustedLandmarks[24] = NormalizedLandmark(
                x: midX + adjustedXOffset,
                y: rightHip.y,
                z: rightHip.z,
                visibility: rightHip.visibility,
                presence: rightHip.presence
            )
        }
        
        let leftElbow = adjustedLandmarks[13]
        let leftWrist = adjustedLandmarks[15]
        let shoulderToElbowDistance = sqrt(pow(leftShoulder.x - leftElbow.x, 2) + pow(leftShoulder.y - leftElbow.y, 2))
        let elbowToWristDistance = sqrt(pow(leftElbow.x - leftWrist.x, 2) + pow(leftElbow.y - leftWrist.y, 2))
        
        if shoulderToElbowDistance < minArmLength {
            let directionX = (leftElbow.x - leftShoulder.x) / (shoulderToElbowDistance == 0 ? 1 : shoulderToElbowDistance)
            let directionY = (leftElbow.y - leftShoulder.y) / (shoulderToElbowDistance == 0 ? 1 : shoulderToElbowDistance)
            adjustedLandmarks[13] = NormalizedLandmark(
                x: leftShoulder.x + directionX * minArmLength,
                y: leftShoulder.y + directionY * minArmLength,
                z: leftElbow.z,
                visibility: leftElbow.visibility,
                presence: leftElbow.presence
            )
        }
        
        if elbowToWristDistance < minArmLength {
            let directionX = (leftWrist.x - leftElbow.x) / (elbowToWristDistance == 0 ? 1 : elbowToWristDistance)
            let directionY = (leftWrist.y - leftElbow.y) / (elbowToWristDistance == 0 ? 1 : elbowToWristDistance)
            adjustedLandmarks[15] = NormalizedLandmark(
                x: leftElbow.x + directionX * minArmLength,
                y: leftElbow.y + directionY * minArmLength,
                z: leftWrist.z,
                visibility: leftWrist.visibility,
                presence: leftWrist.presence
            )
        }
        
        let rightShoulder = adjustedLandmarks[12]
        let rightElbow = adjustedLandmarks[14]
        let rightWrist = adjustedLandmarks[16]
        let rightShoulderToElbowDistance = sqrt(pow(rightShoulder.x - rightElbow.x, 2) + pow(rightShoulder.y - rightElbow.y, 2))
        let rightElbowToWristDistance = sqrt(pow(rightElbow.x - rightWrist.x, 2) + pow(rightElbow.y - rightWrist.y, 2))
        
        if rightShoulderToElbowDistance < minArmLength {
            let directionX = (rightElbow.x - rightShoulder.x) / (rightShoulderToElbowDistance == 0 ? 1 : rightShoulderToElbowDistance)
            let directionY = (rightElbow.y - rightShoulder.y) / (rightShoulderToElbowDistance == 0 ? 1 : rightShoulderToElbowDistance)
            adjustedLandmarks[14] = NormalizedLandmark(
                x: rightShoulder.x + directionX * minArmLength,
                y: rightShoulder.y + directionY * minArmLength,
                z: rightElbow.z,
                visibility: rightElbow.visibility,
                presence: rightElbow.presence
            )
        }
        
        if rightElbowToWristDistance < minArmLength {
            let directionX = (rightWrist.x - rightElbow.x) / (rightElbowToWristDistance == 0 ? 1 : rightElbowToWristDistance)
            let directionY = (rightWrist.y - rightElbow.y) / (rightElbowToWristDistance == 0 ? 1 : rightElbowToWristDistance)
            adjustedLandmarks[16] = NormalizedLandmark(
                x: rightElbow.x + directionX * minArmLength,
                y: rightElbow.y + directionY * minArmLength,
                z: rightWrist.z,
                visibility: rightWrist.visibility,
                presence: rightWrist.presence
            )
        }
        
        return adjustedLandmarks
    }
    
    // MARK: - Предсказание точек во время стабилизации
    private func predictLandmarksDuringStabilization(_ currentLandmarks: [NormalizedLandmark]) -> [NormalizedLandmark] {
        guard let last = lastLandmarks, last.count == currentLandmarks.count else {
            return currentLandmarks
        }
        
        guard let hipMidpoint = lastHipMidpoint else {
            return smoothLandmarksWithKalman(currentLandmarks)
        }
        
        let lastLeftHip = last[23]
        let lastRightHip = last[24]
        let lastHipMidpointX = (lastLeftHip.x + lastRightHip.x) / 2
        let lastHipMidpointY = (lastLeftHip.y + lastRightHip.y) / 2
        
        let deltaX = hipMidpoint.x - lastHipMidpointX
        let deltaY = hipMidpoint.y - lastHipMidpointY
        
        var predicted: [NormalizedLandmark] = []
        for i in 0..<last.count {
            let lastPoint = last[i]
            let newX = lastPoint.x + deltaX
            let newY = lastPoint.y + deltaY
            let predictedLandmark = NormalizedLandmark(
                x: newX,
                y: newY,
                z: lastPoint.z,
                visibility: lastPoint.visibility,
                presence: lastPoint.presence
            )
            predicted.append(predictedLandmark)
        }
        
        return smoothLandmarksWithKalman(predicted)
    }
    
    // MARK: - Сглаживание с помощью фильтра Калмана
    private func smoothLandmarksWithKalman(_ landmarks: [NormalizedLandmark]) -> [NormalizedLandmark] {
        guard !landmarks.isEmpty else { return landmarks }
        
        if kalmanFilters == nil {
            var filters: [[KalmanFilter]] = []
            for i in 0..<landmarks.count {
                let landmark = landmarks[i]
                let xFilter = KalmanFilter(initialState: landmark.x)
                let yFilter = KalmanFilter(initialState: landmark.y)
                let zFilter = KalmanFilter(initialState: landmark.z)
                filters.append([xFilter, yFilter, zFilter])
            }
            kalmanFilters = filters
        }
        
        var smoothed: [NormalizedLandmark] = []
        for i in 0..<landmarks.count {
            let landmark = landmarks[i]
            let filters = kalmanFilters![i]
            
            let smoothedX = filters[0].update(measurement: landmark.x)
            let smoothedY = filters[1].update(measurement: landmark.y)
            let smoothedZ = filters[2].update(measurement: landmark.z)
            
            let smoothedLandmark = NormalizedLandmark(
                x: smoothedX,
                y: smoothedY,
                z: smoothedZ,
                visibility: landmark.visibility,
                presence: landmark.presence
            )
            smoothed.append(smoothedLandmark)
        }
        
        return smoothed
    }
}
