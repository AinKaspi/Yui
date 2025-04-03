import UIKit
import MediaPipeTasksVision
import os.log

protocol VisualizationServiceProtocol {
    func updateLandmarks(_ landmarks: [NormalizedLandmark]?, in view: PoseOverlayView)
}

class VisualizationService: VisualizationServiceProtocol {
    func updateLandmarks(_ landmarks: [NormalizedLandmark]?, in view: PoseOverlayView) {
        view.updateLandmarks(landmarks)
    }
}
