import AVFoundation
import UIKit
import MediaPipeTasksVision
import os.log

protocol ExerciseExecutionViewModelProtocol {
    var exerciseName: String { get }
    var repsCount: String { get }
    var instructionText: String { get }
    var isInstructionHidden: Bool { get }
    var cameraService: CameraServiceProtocol { get }
    
    func setup()
    func startSession()
    func stopSession()
    func updatePreviewLayerFrame(_ frame: CGRect)
    func drawLandmarks(in view: PoseOverlayView)
    func saveResults(workout: Workout) // Новый метод для сохранения результатов
}

class ExerciseExecutionViewModel: ExerciseExecutionViewModelProtocol {
    // MARK: - Свойства
    private let exercise: Exercise
    private let poseProcessor: PoseProcessor
    private let poseOverlayView: PoseOverlayView?
    private let storageService: StorageServiceProtocol
    
    let cameraService: CameraServiceProtocol
    private let poseDetectionService: PoseDetectionServiceProtocol
    private let imageProcessingService: ImageProcessingServiceProtocol
    private let visualizationService: VisualizationServiceProtocol
    
    private var isTracking: Bool = false
    private var isCorrectPose: Bool = true
    
    var exerciseName: String {
        return exercise.name
    }
    
    var repsCount: String {
        return "Повторения: \(poseProcessor.repCount)"
    }
    
    var instructionText: String = "Подойдите ближе к камере"
    
    var isInstructionHidden: Bool {
        return isTracking
    }
    
    // MARK: - Инициализация
    init(exercise: Exercise,
         cameraService: CameraServiceProtocol,
         poseDetectionService: PoseDetectionServiceProtocol,
         imageProcessingService: ImageProcessingServiceProtocol,
         visualizationService: VisualizationServiceProtocol,
         storageService: StorageServiceProtocol) {
        self.exercise = exercise
        self.cameraService = cameraService
        self.poseDetectionService = poseDetectionService
        self.imageProcessingService = imageProcessingService
        self.visualizationService = visualizationService
        self.storageService = storageService
        self.poseProcessor = PoseProcessor(exerciseType: ExerciseType(rawValue: exercise.type) ?? .squat)
        self.poseOverlayView = nil
    }
    
    // MARK: - Настройка
    func setup() {
        os_log("ExerciseExecutionViewModel: setup вызван", log: OSLog.default, type: .debug)
        cameraService.onFrameCaptured = { [weak self] sampleBuffer, orientation, timestamp in
            guard let self = self else { return }
            
            // Нормализация изображения
            guard let normalizedBuffer = self.imageProcessingService.normalizeImage(sampleBuffer) else {
                os_log("ExerciseExecutionViewModel: Не удалось нормализовать изображение", log: OSLog.default, type: .error)
                return
            }
            
            // Детекция позы
            if let result = self.poseDetectionService.detectPose(in: normalizedBuffer, orientation: orientation, timestamp: timestamp) {
                self.isTracking = true
                self.poseProcessor.processPoseLandmarks(result)
                
                // Определяем активные лендмарки в зависимости от типа упражнения
                let activeLandmarkIndices: Set<Int>
                switch ExerciseType(rawValue: self.exercise.type) ?? .squat {
                case .squat:
                    activeLandmarkIndices = [23, 24, 25, 26, 27, 28] // Таз, колени, лодыжки
                case .pushUp:
                    activeLandmarkIndices = [11, 12, 13, 14, 15, 16] // Плечи, локти, запястья
                }
                
                self.visualizationService.updatePoseLandmarks(result.landmarks.first ?? [], activeLandmarkIndices: activeLandmarkIndices, isCorrect: self.isCorrectPose)
            } else {
                self.isTracking = false
                self.instructionText = "Подойдите ближе к камере"
                self.visualizationService.clearPoseLandmarks()
            }
        }
        
        poseProcessor.onRepCountUpdated = { [weak self] count in
            guard let self = self else { return }
            os_log("ExerciseExecutionViewModel: Обновлено количество повторений: %d", log: OSLog.default, type: .debug, count)
            self.visualizationService.animateRepetition()
        }
        
        poseProcessor.onFeedbackUpdated = { [weak self] feedback in
            guard let self = self else { return }
            if !feedback.isEmpty {
                self.instructionText = feedback
                self.isTracking = false
                self.isCorrectPose = false
            } else {
                self.isTracking = true
                self.instructionText = ""
                self.isCorrectPose = true
            }
            os_log("ExerciseExecutionViewModel: Обновлена обратная связь: %@", log: OSLog.default, type: .debug, feedback)
        }
    }
    
    // MARK: - Управление сессией
    func startSession() {
        os_log("ExerciseExecutionViewModel: startSession вызван", log: OSLog.default, type: .debug)
        cameraService.startSession()
    }
    
    func stopSession() {
        os_log("ExerciseExecutionViewModel: stopSession вызван", log: OSLog.default, type: .debug)
        cameraService.stopSession()
    }
    
    // MARK: - Сохранение результатов
    func saveResults(workout: Workout) {
        os_log("ExerciseExecutionViewModel: saveResults вызван", log: OSLog.default, type: .debug)
        
        // Загружаем существующие тренировки
        var workouts = storageService.loadWorkouts()
        
        // Находим индекс текущей тренировки
        guard let workoutIndex = workouts.firstIndex(where: { $0.name == workout.name }) else {
            os_log("ExerciseExecutionViewModel: Тренировка не найдена", log: OSLog.default, type: .error)
            return
        }
        
        // Обновляем результаты
        var updatedWorkout = workouts[workoutIndex]
        updatedWorkout.completedReps = [exercise.name: poseProcessor.repCount]
        updatedWorkout.completionDate = Date()
        
        // Сохраняем обновлённый список тренировок
        workouts[workoutIndex] = updatedWorkout
        storageService.saveWorkouts(workouts)
        
        os_log("ExerciseExecutionViewModel: Результаты сохранены для тренировки: %@", log: OSLog.default, type: .debug, workout.name)
    }
    
    // MARK: - Обновление UI
    func updatePreviewLayerFrame(_ frame: CGRect) {
        cameraService.updatePreviewLayerFrame(frame)
    }
    
    func drawLandmarks(in view: PoseOverlayView) {
        visualizationService.drawLandmarks(in: view)
    }
}
