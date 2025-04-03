import UIKit
import AVFoundation
import MediaPipeTasksVision

class ExerciseExecutionViewController: UIViewController, CameraServiceDelegate, PoseDetectionDelegate {
    private let exercise: Exercise
    private let cameraService: CameraServiceProtocol
    private let poseDetectionService: PoseDetectionService
    private let visualizationService: VisualizationService
    private weak var delegate: AnyObject?
    private let overlayView: PoseOverlayView
    private let poseProcessor: PoseProcessor
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    init(
        exercise: Exercise,
        cameraService: CameraServiceProtocol,
        poseDetectionService: PoseDetectionService,
        visualizationService: VisualizationService,
        delegate: AnyObject?,
        overlayView: PoseOverlayView,
        poseProcessor: PoseProcessor
    ) {
        self.exercise = exercise
        self.cameraService = cameraService
        self.poseDetectionService = poseDetectionService
        self.visualizationService = visualizationService
        self.delegate = delegate
        self.overlayView = overlayView
        self.poseProcessor = poseProcessor
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        cameraService.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraService.stop()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        overlayView.frame = view.bounds
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)
        
        visualizationService.updateOverlay(with: nil)
    }
    
    private func setupCamera() {
        cameraService.delegate = self
        poseDetectionService.delegate = self
        cameraService.setPreviewLayer(previewLayer)
    }
    
    func didOutput(sampleBuffer: CMSampleBuffer) {
        poseDetectionService.detectPoses(in: sampleBuffer)
    }
    
    func didDetectPoses(_ landmarks: [NormalizedLandmark]?) {
        DispatchQueue.main.async {
            self.visualizationService.updateOverlay(with: landmarks)
            self.poseProcessor.processPose(landmarks: landmarks)
        }
    }
}
