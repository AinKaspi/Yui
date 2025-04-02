import MediaPipeTasksVision

class PoseProcessor {
    
    private var repCount = 0
    private var isSquatting = false
    private var previousHipY: Float?
    
    var onRepCountUpdated: ((Int) -> Void)?
    
    func processPoseLandmarks(_ result: PoseLandmarkerResult) {
        guard let landmarks = result.landmarks.first else { return }
        
        let requiredLandmarks = [23, 24, 25, 26]
        let allVisible = requiredLandmarks.allSatisfy { index in
            let visibility = landmarks[index].visibility?.doubleValue ?? 0.0 // Преобразуем NSNumber? в Double
            return visibility > 0.5
        }
        
        guard allVisible else {
            print("Не все ключевые точки видны")
            return
        }
        
        let leftHip = landmarks[23]
        let rightHip = landmarks[24]
        let leftKnee = landmarks[25]
        let rightKnee = landmarks[26]
        
        let hipY = (leftHip.y + rightHip.y) / 2
        let kneeY = (leftKnee.y + rightKnee.y) / 2
        
        print("hipY: \(hipY), kneeY: \(kneeY), isSquatting: \(isSquatting)")
        
        let threshold: Float = 0.1
        
        if previousHipY != nil {
            if hipY < kneeY - threshold && !isSquatting {
                isSquatting = true
                print("Начало приседания")
            } else if hipY > kneeY + threshold && isSquatting {
                isSquatting = false
                repCount += 1
                print("Конец приседания, repCount: \(repCount)")
                onRepCountUpdated?(repCount)
            }
        }
        
        self.previousHipY = hipY
    }
}
