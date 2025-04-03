import Foundation

// Временная структура Landmark, замените на тип из MediaPipe, если он отличается
struct Landmark {
    let x: NSNumber
    let y: NSNumber
}

class PoseProcessor {
    private var leftShoulderAngle: Double = 0.0
    private var rightShoulderAngle: Double = 0.0
    private var leftElbowAngle: Double = 0.0
    private var rightElbowAngle: Double = 0.0
    private var leftHipAngle: Double = 0.0
    private var rightHipAngle: Double = 0.0
    private var leftKneeAngle: Double = 0.0
    private var rightKneeAngle: Double = 0.0
    
    /// Вычисляет угол между тремя точками в градусах
    private func calculateAngle(point1: Landmark, point2: Landmark, point3: Landmark) -> Double {
        let vector1 = (x: Double(truncating: point1.x) - Double(truncating: point2.x),
                       y: Double(truncating: point1.y) - Double(truncating: point2.y))
        let vector2 = (x: Double(truncating: point3.x) - Double(truncating: point2.x),
                       y: Double(truncating: point3.y) - Double(truncating: point2.y))
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        guard magnitude1 > 0, magnitude2 > 0 else { return 0.0 }
        
        let cosTheta = dotProduct / (magnitude1 * magnitude2)
        let angleRadians = acos(min(max(cosTheta, -1.0), 1.0))
        return angleRadians * 180 / .pi
    }
    
    /// Обрабатывает массив ключевых точек и вычисляет углы
    func processPose(landmarks: [Landmark]) {
        guard landmarks.count >= 33 else { return }
        
        let leftShoulder = landmarks[11]  // Left shoulder
        let rightShoulder = landmarks[12] // Right shoulder
        let leftElbow = landmarks[13]     // Left elbow
        let rightElbow = landmarks[14]    // Right elbow
        let leftWrist = landmarks[15]     // Left wrist
        let rightWrist = landmarks[16]    // Right wrist
        let leftHip = landmarks[23]       // Left hip
        let rightHip = landmarks[24]      // Right hip
        let leftKnee = landmarks[25]      // Left knee
        let rightKnee = landmarks[26]     // Right knee
        let leftAnkle = landmarks[27]     // Left ankle
        let rightAnkle = landmarks[28]    // Right ankle
        
        leftShoulderAngle = calculateAngle(point1: leftElbow, point2: leftShoulder, point3: leftHip)
        rightShoulderAngle = calculateAngle(point1: rightElbow, point2: rightShoulder, point3: rightHip)
        leftElbowAngle = calculateAngle(point1: leftShoulder, point2: leftElbow, point3: leftWrist)
        rightElbowAngle = calculateAngle(point1: rightShoulder, point2: rightElbow, point3: rightWrist)
        leftHipAngle = calculateAngle(point1: leftShoulder, point2: leftHip, point3: leftKnee)
        rightHipAngle = calculateAngle(point1: rightShoulder, point2: rightHip, point3: rightKnee)
        leftKneeAngle = calculateAngle(point1: leftHip, point2: leftKnee, point3: leftAnkle)
        rightKneeAngle = calculateAngle(point1: rightHip, point2: rightKnee, point3: rightAnkle)
    }
    
    /// Оценивает общую форму тела
    func evaluatePose() -> String {
        var feedback = ""
        
        if leftShoulderAngle > 90 || rightShoulderAngle > 90 {
            feedback += "Lower your shoulders. "
        }
        
        if leftElbowAngle < 70 || rightElbowAngle < 70 {
            feedback += "Bend your elbows more. "
        }
        
        if leftHipAngle < 90 || rightHipAngle < 90 {
            feedback += "Bend at the hips more. "
        }
        
        if leftKneeAngle < 90 || rightKneeAngle < 90 {
            feedback += "Bend your knees more. "
        }
        
        return feedback.isEmpty ? "Good form!" : feedback
    }
    
    /// Оценивает форму тела для отжиманий
    func evaluatePushUpPose() -> String {
        var feedback = ""
        
        if leftShoulderAngle > 100 || rightShoulderAngle > 100 {
            feedback += "Lower your shoulders. "
        }
        
        if leftElbowAngle < 90 || rightElbowAngle < 90 {
            feedback += "Bend your elbows more. "
        }
        
        if calculateAngle(point1: leftShoulder, point2: leftHip, point3: leftKnee) < 160 ||
           calculateAngle(point1: rightShoulder, point2: rightHip, point3: rightKnee) < 160 {
            feedback += "Keep your body straight. "
        }
        
        return feedback.isEmpty ? "Good push-up form!" : feedback
    }
}
