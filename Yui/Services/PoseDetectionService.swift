import MediaPipeTasksVision
import os.log

protocol PoseDetectionServiceProtocol {
    func setup()
    func detectPose(in image: MPImage, timestamp: Int, completion: @escaping (PoseLandmarkerResult?, Error?) -> Void)
}

class PoseDetectionService: PoseDetectionServiceProtocol {
    private var poseLandmarker: PoseLandmarker?
    
    func setup() {
        os_log("PoseDetectionService: Настройка MediaPipe", log: OSLog.default, type: .debug)
        let startTime = Date()
        
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            os_log("PoseDetectionService: Не удалось найти файл модели pose_landmarker_full.task", log: OSLog.default, type: .error)
            return
        }
        
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.baseOptions.delegate = .GPU
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minTrackingConfidence = 0.7
        options.minPosePresenceConfidence = 0.7
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
            let duration = Date().timeIntervalSince(startTime)
            os_log("PoseDetectionService: MediaPipe успешно настроен за %f секунд", log: OSLog.default, type: .debug, duration)
        } catch {
            os_log("PoseDetectionService: Ошибка инициализации Pose Landmarker: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    func detectPose(in image: MPImage, timestamp: Int, completion: @escaping (PoseLandmarkerResult?, Error?) -> Void) {
        guard let poseLandmarker = poseLandmarker else {
            os_log("PoseDetectionService: PoseLandmarker не инициализирован", log: OSLog.default, type: .error)
            completion(nil, NSError(domain: "PoseDetectionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "PoseLandmarker not initialized"]))
            return
        }
        
        poseLandmarker.detectAsync(image: image, timestampInMilliseconds: timestamp) { result, error in
            completion(result, error)
        }
    }
}
