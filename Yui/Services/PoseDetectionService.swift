import Foundation
import MediaPipeTasksVision

protocol PoseDetectionDelegate: AnyObject {
    func didDetectPoses(_ landmarks: [NormalizedLandmark]?)
}

class PoseDetectionService {
    private let poseLandmarker: PoseLandmarker
    weak var delegate: PoseDetectionDelegate?

    init(delegate: PoseDetectionDelegate) throws {
        let options = PoseLandmarkerOptions()
        options.runningMode = .liveStream // Оставляем, но это не влияет на detect
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            fatalError("Model file 'pose_landmarker_full.task' not found in bundle.")
        }
        options.baseOptions.modelAssetPath = modelPath
        
        self.delegate = delegate
        poseLandmarker = try PoseLandmarker(options: options)
    }
    
    func detectPoses(in sampleBuffer: CMSampleBuffer) {
        do {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Failed to get image buffer")
                delegate?.didDetectPoses(nil)
                return
            }
            let mpImage = try MPImage(pixelBuffer: imageBuffer)
            let result = try poseLandmarker.detect(image: mpImage)
            let landmarks = result.landmarks.first
            delegate?.didDetectPoses(landmarks)
        } catch {
            print("Pose detection failed: \(error)")
            delegate?.didDetectPoses(nil)
        }
    }
}
