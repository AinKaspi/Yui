import Foundation
import AVFoundation
import MediaPipeTasksVision

protocol PoseDetectionServiceProtocol {
    func detectPoses(in sampleBuffer: CMSampleBuffer)
    var delegate: PoseDetectionDelegate? { get set }
}

protocol VisualizationServiceProtocol {
    func updateOverlay(with landmarks: [NormalizedLandmark]?)
}

class ExerciseExecutionViewModel: ObservableObject {
    @Published var repCount: Int = 0
    @Published var feedback: String = ""
    
    private let exercise: Exercise
    private var cameraService: CameraServiceProtocol // Изменяем let на var
    private var poseDetectionService: PoseDetectionServiceProtocol // Изменяем let на var
    private let visualizationService: VisualizationServiceProtocol
    private let poseProcessor: PoseProcessor
    
    init(
        exercise: Exercise,
        cameraService: CameraServiceProtocol,
        poseDetectionService: PoseDetectionServiceProtocol,
        visualizationService: VisualizationServiceProtocol,
        poseProcessor: PoseProcessor
    ) {
        self.exercise = exercise
        self.cameraService = cameraService
        self.poseDetectionService = poseDetectionService
        self.visualizationService = visualizationService
        self.poseProcessor = poseProcessor
        
        setupBindings()
    }
    
    func startCamera() {
        cameraService.start()
    }
    
    func stopCamera() {
        cameraService.stop()
    }
    
    private func setupBindings() {
        cameraService.delegate = self
        poseDetectionService.delegate = self
        
        poseProcessor.onRepCountUpdated = { [weak self] count in
            DispatchQueue.main.async {
                self?.repCount = count
            }
        }
        
        poseProcessor.onFeedbackUpdated = { [weak self] feedback in
            DispatchQueue.main.async {
                self?.feedback = feedback
            }
        }
    }
}

extension ExerciseExecutionViewModel: CameraServiceDelegate {
    func didOutput(sampleBuffer: CMSampleBuffer) {
        poseDetectionService.detectPoses(in: sampleBuffer)
    }
}

extension ExerciseExecutionViewModel: PoseDetectionDelegate {
    func didDetectPoses(_ landmarks: [NormalizedLandmark]?) {
        visualizationService.updateOverlay(with: landmarks)
        poseProcessor.processPose(landmarks: landmarks)
    }
}
