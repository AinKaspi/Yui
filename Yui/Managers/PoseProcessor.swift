import Foundation
import MediaPipeTasksVision

class PoseProcessor {
    var currentRepCount: Int = 0
    var onRepCountUpdated: ((Int) -> Void)?
    var onFeedbackUpdated: ((String) -> Void)?
    
    func processPose(landmarks: [NormalizedLandmark]?) {
        // Простая логика для примера
        guard let landmarks = landmarks, landmarks.count >= 33 else { return }
        currentRepCount += 1
        onRepCountUpdated?(currentRepCount)
        onFeedbackUpdated?("Pose processed")
    }
}
