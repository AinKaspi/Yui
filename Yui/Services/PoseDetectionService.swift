import Foundation
import MediaPipeTasksVision

protocol PoseDetectionDelegate: AnyObject {
    func didDetectPoses(_ landmarks: [NormalizedLandmark]?)
}

class PoseDetectionService: NSObject, PoseLandmarkerLiveStreamDelegate {
    private let poseLandmarker: PoseLandmarker
    weak var delegate: PoseDetectionDelegate? // Уже опциональный, проверяем

    init(delegate: PoseDetectionDelegate? = nil) throws { // Делаем delegate опциональным с дефолтным nil
        let options = PoseLandmarkerOptions()
        options.runningMode = .liveStream
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
        poseLandmarker.delegate = self
    }
    
    func detectPoses(in sampleBuffer: CMSampleBuffer) {
        do {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Failed to get image buffer")
                delegate?.didDetectPoses(nil)
                return
            }
            let mpImage = try MPImage(pixelBuffer: imageBuffer)
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
            
            try poseLandmarker.detectAsync(
                image: mpImage,
                timestampInMilliseconds: Int(timestamp)
            )
        } catch {
            print("Pose detection failed: \(error)")
            delegate?.didDetectPoses(nil)
        }
    }
    
    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        if let error = error {
            print("Pose detection error: \(error)")
            delegate?.didDetectPoses(nil)
            return
        }
        let landmarks = result?.landmarks.first
        delegate?.didDetectPoses(landmarks)
    }
}
