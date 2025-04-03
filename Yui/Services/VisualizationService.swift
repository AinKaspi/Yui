import MediaPipeTasksVision
import UIKit
import os.log

// MARK: - Структура для хранения данных о визуализации
struct VisualLandmark {
    let position: CGPoint
    let visibility: Float
    let isActive: Bool // Указывает, является ли точка активной для текущего упражнения
    let color: UIColor // Цвет точки
}

// MARK: - Протокол VisualizationServiceProtocol
protocol VisualizationServiceProtocol {
    func updatePoseLandmarks(_ landmarks: [NormalizedLandmark], activeLandmarkIndices: Set<Int>, isCorrect: Bool)
    func clearPoseLandmarks()
    func drawLandmarks(in view: PoseOverlayView)
    func animateRepetition()
}

class VisualizationService: VisualizationServiceProtocol {
    // MARK: - Свойства
    private var visualLandmarks: [VisualLandmark] = []
    private var previousLandmarks: [VisualLandmark] = [] // Для анимации
    private var animationProgress: CGFloat = 0.0
    private var isAnimatingRepetition: Bool = false
    private var isCorrectPose: Bool = true
    
    private let activeColor = UIColor.green
    private let inactiveColor = UIColor.red
    private let incorrectColor = UIColor.orange
    private let lineColor = UIColor.white
    private let animationDuration: TimeInterval = 0.3 // Длительность анимации
    
    // MARK: - Обновление лендмарков
    func updatePoseLandmarks(_ landmarks: [NormalizedLandmark], activeLandmarkIndices: Set<Int>, isCorrect: Bool) {
        os_log("VisualizationService: updatePoseLandmarks вызван", log: OSLog.default, type: .debug)
        
        // Сохраняем предыдущие позиции для анимации
        previousLandmarks = visualLandmarks
        
        // Обновляем текущие лендмарки
        visualLandmarks = landmarks.enumerated().map { (index, landmark) in
            let position = CGPoint(x: CGFloat(landmark.x), y: CGFloat(landmark.y))
            let isActive = activeLandmarkIndices.contains(index)
            let color: UIColor
            if !isCorrect {
                color = incorrectColor
            } else {
                color = isActive ? activeColor : inactiveColor
            }
            return VisualLandmark(position: position, visibility: landmark.visibility as! Float, isActive: isActive, color: color)
        }
        
        // Сбрасываем прогресс анимации
        animationProgress = 0.0
        isCorrectPose = isCorrect
    }
    
    func clearPoseLandmarks() {
        os_log("VisualizationService: clearPoseLandmarks вызван", log: OSLog.default, type: .debug)
        visualLandmarks = []
        previousLandmarks = []
        animationProgress = 0.0
        isAnimatingRepetition = false
    }
    
    // MARK: - Отрисовка
    func drawLandmarks(in view: PoseOverlayView) {
        os_log("VisualizationService: drawLandmarks вызван", log: OSLog.default, type: .debug)
        
        // Обновляем прогресс анимации
        if animationProgress < 1.0 {
            animationProgress += CGFloat(1.0 / (60.0 * animationDuration)) // 60 fps
            animationProgress = min(animationProgress, 1.0)
            view.setNeedsDisplay()
        }
        
        view.updateVisualLandmarks(
            visualLandmarks: visualLandmarks,
            previousLandmarks: previousLandmarks,
            animationProgress: animationProgress,
            isAnimatingRepetition: isAnimatingRepetition,
            isCorrectPose: isCorrectPose
        )
    }
    
    // MARK: - Анимация повторения
    func animateRepetition() {
        os_log("VisualizationService: animateRepetition вызван", log: OSLog.default, type: .debug)
        isAnimatingRepetition = true
        animationProgress = 0.0
    }
}
