import MediaPipeTasksVision

class PoseProcessor {
    
    private var repCount = 0
    private var isSquatting = false
    private var previousHipY: Float?
    private var previousKneeY: Float?
    
    var onRepCountUpdated: ((Int) -> Void)?
    
    func processPoseLandmarks(_ result: PoseLandmarkerResult) {
        guard let landmarks = result.landmarks.first else {
            print("PoseProcessor: Нет обнаруженных ключевых точек")
            return
        }
        
        let requiredLandmarks = [23, 24, 25, 26]
        var allVisible = true
        for index in requiredLandmarks {
            let visibility = landmarks[index].visibility?.doubleValue ?? 0.0
            let x = landmarks[index].x
            let y = landmarks[index].y
            print("PoseProcessor: Точка \(index) - x: \(x), y: \(y), visibility: \(visibility)")
            if visibility < 0.5 {
                print("PoseProcessor: Ключевая точка \(index) не видна, visibility: \(visibility)")
                allVisible = false
            }
        }
        
        guard allVisible else {
            print("PoseProcessor: Не все ключевые точки видны")
            return
        }
        
        let leftHip = landmarks[23]
        let rightHip = landmarks[24]
        let leftKnee = landmarks[25]
        let rightKnee = landmarks[26]
        
        let hipY = (leftHip.y + rightHip.y) / 2
        let kneeY = (leftKnee.y + rightKnee.y) / 2
        
        print("hipY: \(hipY), kneeY: \(kneeY), isSquatting: \(isSquatting)")
        
        let threshold: Float = 0.05
        
        if previousHipY != nil && previousKneeY != nil {
            // В нижней точке приседания hipY больше kneeY
            if hipY > kneeY + threshold && !isSquatting {
                isSquatting = true
                print("Начало приседания")
            }
            // В верхней точке приседания hipY меньше kneeY
            else if hipY < kneeY - threshold && isSquatting {
                isSquatting = false
                repCount += 1
                print("Конец приседания, repCount: \(repCount)")
                onRepCountUpdated?(repCount)
            }
        }
        
        self.previousHipY = hipY
        self.previousKneeY = kneeY
    }
}
