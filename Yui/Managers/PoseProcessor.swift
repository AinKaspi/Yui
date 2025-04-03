import Foundation
import MediaPipeTasksVision
import os.log

class PoseProcessor {
    var onRepCountUpdated: ((Int) -> Void)?
    
    private var repCount: Int = 0
    private var isSquatting: Bool = false
    private var previousKneeAngle: Float?
    
    func processPoseLandmarks(_ result: PoseLandmarkerResult) {
        guard let landmarks = result.landmarks.first else {
            os_log("PoseProcessor: Нет ключевых точек для обработки", log: OSLog.default, type: .debug)
            return
        }
        
        let leftHip = landmarks[23]
        let leftKnee = landmarks[25]
        let leftAnkle = landmarks[27]
        
        let hipToKnee = CGPoint(x: CGFloat(leftKnee.x - leftHip.x), y: CGFloat(leftKnee.y - leftHip.y))
        let kneeToAnkle = CGPoint(x: CGFloat(leftAnkle.x - leftKnee.x), y: CGFloat(leftAnkle.y - leftKnee.y))
        
        let dotProduct = hipToKnee.x * kneeToAnkle.x + hipToKnee.y * kneeToAnkle.y
        let magnitudeHipToKnee = sqrt(hipToKnee.x * hipToKnee.x + hipToKnee.y * hipToKnee.y)
        let magnitudeKneeToAnkle = sqrt(kneeToAnkle.x * kneeToAnkle.x + kneeToAnkle.y * kneeToAnkle.y)
        
        let cosAngle = dotProduct / (magnitudeHipToKnee * magnitudeKneeToAnkle)
        let angle = acos(cosAngle) * 180 / .pi
        
        guard let previousAngle = previousKneeAngle else {
            previousKneeAngle = Float(angle)
            return
        }
        
        if angle < 90 && previousAngle >= 90 && !isSquatting {
            isSquatting = true
        } else if angle >= 90 && previousAngle < 90 && isSquatting {
            isSquatting = false
            repCount += 1
            onRepCountUpdated?(repCount)
            os_log("PoseProcessor: Обнаружено повторение, общее количество: %d", log: OSLog.default, type: .debug, repCount)
        }
        
        previousKneeAngle = Float(angle)
    }
}
