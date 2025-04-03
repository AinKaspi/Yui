import MediaPipeTasksVision
import os.log

// MARK: - Типы упражнений
enum ExerciseType: String {
    case squat = "repetitive" // Приседания
    case pushUp = "pushUp"    // Отжимания
    // Можно добавить другие типы упражнений
}

// MARK: - Ошибки выполнения упражнения
enum ExerciseFeedback: String {
    case none = ""
    case kneesTooFarForward = "Не выводите колени вперёд"
    case backNotStraight = "Держите спину прямо"
    case elbowsNotLocked = "Выпрямите локти"
}

// MARK: - Протокол для обработки упражнений
protocol ExerciseAnalyzer {
    func analyze(landmarks: [NormalizedLandmark]) -> (completedRep: Bool, feedback: ExerciseFeedback)
    func reset()
}

// MARK: - Анализатор приседаний
class SquatAnalyzer: ExerciseAnalyzer {
    private var isGoingDown: Bool = false
    private var previousHipY: Float?
    private let hipThreshold: Float = 0.05 // Порог изменения Y-координаты таза для фиксации движения
    
    func analyze(landmarks: [NormalizedLandmark]) -> (completedRep: Bool, feedback: ExerciseFeedback) {
        // Лендмарки: 23 (левый таз), 25 (левое колено), 27 (левая лодыжка), 11 (левое плечо), 12 (правое плечо)
        let leftHip = landmarks[23]
        let leftKnee = landmarks[25]
        let leftAnkle = landmarks[27]
        let leftShoulder = landmarks[11]
        let rightShoulder = landmarks[12]
        
        // 1. Проверка корректности осанки (угол спины)
        let backAngle = calculateAngle(point1: leftShoulder, point2: leftHip, point3: leftKnee)
        let backFeedback: ExerciseFeedback = backAngle > 30 ? .backNotStraight : .none
        
        // 2. Проверка положения коленей (не должны быть слишком далеко вперёд)
        let kneeOverAnkleDistance = abs(leftKnee.x - leftAnkle.x)
        let kneeFeedback: ExerciseFeedback = kneeOverAnkleDistance > 0.1 ? .kneesTooFarForward : .none
        
        // 3. Подсчёт повторений на основе Y-координаты таза
        let currentHipY = leftHip.y
        var completedRep = false
        
        if let previousHipY = previousHipY {
            if currentHipY > previousHipY + hipThreshold && !isGoingDown {
                isGoingDown = true
                os_log("PoseProcessor: Движение вниз (приседание)", log: OSLog.default, type: .debug)
            } else if currentHipY < previousHipY - hipThreshold && isGoingDown {
                isGoingDown = false
                completedRep = true
                os_log("PoseProcessor: Повторение зафиксировано (приседание)", log: OSLog.default, type: .debug)
            }
        }
        
        self.previousHipY = currentHipY
        
        // Возвращаем результат анализа
        let feedback: ExerciseFeedback = backFeedback != .none ? backFeedback : kneeFeedback
        return (completedRep, feedback)
    }
    
    func reset() {
        isGoingDown = false
        previousHipY = nil
    }
}

// MARK: - Анализатор отжиманий
class PushUpAnalyzer: ExerciseAnalyzer {
    private var isGoingDown: Bool = false
    private var previousElbowAngle: Float?
    private let elbowAngleThreshold: Float = 90 // Порог угла локтя для фиксации отжимания
    
    func analyze(landmarks: [NormalizedLandmark]) -> (completedRep: Bool, feedback: ExerciseFeedback) {
        // Лендмарки: 13 (левый локоть), 11 (левое плечо), 15 (левое запястье), 12 (правое плечо), 24 (правый таз)
        let leftElbow = landmarks[13]
        let leftShoulder = landmarks[11]
        let leftWrist = landmarks[15]
        let rightShoulder = landmarks[12]
        let rightHip = landmarks[24]
        
        // 1. Проверка корректности осанки (угол спины)
        let backAngle = calculateAngle(point1: rightShoulder, point2: rightHip, point3: rightShoulder)
        let backFeedback: ExerciseFeedback = backAngle > 20 ? .backNotStraight : .none
        
        // 2. Проверка угла локтя
        let elbowAngle = calculateAngle(point1: leftShoulder, point2: leftElbow, point3: leftWrist)
        let elbowFeedback: ExerciseFeedback = elbowAngle > 160 && !isGoingDown ? .elbowsNotLocked : .none
        
        // 3. Подсчёт повторений на основе угла локтя
        var completedRep = false
        
        if let previousElbowAngle = previousElbowAngle {
            if elbowAngle < elbowAngleThreshold && !isGoingDown {
                isGoingDown = true
                os_log("PoseProcessor: Движение вниз (отжимание)", log: OSLog.default, type: .debug)
            } else if elbowAngle > 160 && isGoingDown {
                isGoingDown = false
                completedRep = true
                os_log("PoseProcessor: Повторение зафиксировано (отжимание)", log: OSLog.default, type: .debug)
            }
        }
        
        self.previousElbowAngle = elbowAngle
        
        // Возвращаем результат анализа
        let feedback: ExerciseFeedback = backFeedback != .none ? backFeedback : elbowFeedback
        return (completedRep, feedback)
    }
    
    func reset() {
        isGoingDown = false
        previousElbowAngle = nil
    }
}

// MARK: - Основной класс PoseProcessor
class PoseProcessor {
    // MARK: - Свойства
    private var repCount: Int = 0
    private var analyzer: ExerciseAnalyzer
    private var feedback: ExerciseFeedback = .none
    
    var onRepCountUpdated: ((Int) -> Void)?
    var onFeedbackUpdated: ((String) -> Void)?
    
    // MARK: - Инициализация
    init(exerciseType: ExerciseType = .squat) {
        switch exerciseType {
        case .squat:
            self.analyzer = SquatAnalyzer()
        case .pushUp:
            self.analyzer = PushUpAnalyzer()
        }
    }
    
    // MARK: - Обработка позы
    func processPoseLandmarks(_ result: PoseLandmarkerResult) {
        os_log("PoseProcessor: processPoseLandmarks вызван", log: OSLog.default, type: .debug)
        
        guard let landmarks = result.landmarks.first else {
            os_log("PoseProcessor: Лендмарки отсутствуют", log: OSLog.default, type: .debug)
            feedback = .none
            onFeedbackUpdated?(feedback.rawValue)
            return
        }
        
        // Анализируем позу
        let (completedRep, newFeedback) = analyzer.analyze(landmarks: landmarks)
        
        // Обновляем количество повторений
        if completedRep {
            repCount += 1
            onRepCountUpdated?(repCount)
            os_log("PoseProcessor: Повторение зафиксировано, общее количество: %d", log: OSLog.default, type: .debug, repCount)
        }
        
        // Обновляем обратную связь
        if feedback != newFeedback {
            feedback = newFeedback
            onFeedbackUpdated?(feedback.rawValue)
            os_log("PoseProcessor: Обновлена обратная связь: %@", log: OSLog.default, type: .debug, feedback.rawValue)
        }
    }
    
    // MARK: - Сброс состояния
    func reset() {
        repCount = 0
        feedback = .none
        analyzer.reset()
        onRepCountUpdated?(repCount)
        onFeedbackUpdated?(feedback.rawValue)
    }
    
    // MARK: - Вспомогательные методы
    private func calculateAngle(point1: NormalizedLandmark, point2: NormalizedLandmark, point3: NormalizedLandmark) -> Float {
        let vector1 = (x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = (x: point3.x - point2.x, y: point3.y - point2.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        guard magnitude1 > 0, magnitude2 > 0 else { return 0 }
        
        let cosTheta = dotProduct / (magnitude1 * magnitude2)
        let angleRad = acos(min(max(cosTheta, -1), 1))
        return angleRad * 180 / .pi // Переводим в градусы
    }
}
