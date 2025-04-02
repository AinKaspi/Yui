import UIKit
import AVFoundation
import MediaPipeTasksVision

class ExerciseExecutionViewController: UIViewController, PoseLandmarkerLiveStreamDelegate {
    
    // MARK: - Свойства
    private let exercise: Exercise
    private var cameraManager: CameraManager!
    private var poseProcessor: PoseProcessor!
    
    private let exerciseLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let repsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let finishButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Завершить", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var poseLandmarker: PoseLandmarker?
    private var isPoseLandmarkerSetup = false
    
    // MARK: - Инициализация
    init(exercise: Exercise) {
        self.exercise = exercise
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Жизненный цикл
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCameraManager()
        setupMediaPipe()
        setupPoseProcessor()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraManager.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraManager.updatePreviewLayerFrame(view.bounds)
    }
    
    // MARK: - Функция: Настройка UI
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(exerciseLabel)
        view.addSubview(repsLabel)
        view.addSubview(finishButton)
        
        exerciseLabel.text = exercise.name
        repsLabel.text = "Повторения: 0"
        finishButton.addTarget(self, action: #selector(finishExercise), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            exerciseLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            exerciseLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            exerciseLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            repsLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            repsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            repsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            finishButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            finishButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            finishButton.widthAnchor.constraint(equalToConstant: 200),
            finishButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Функция: Настройка CameraManager
    private func setupCameraManager() {
        cameraManager = CameraManager()
        cameraManager.setupCamera { [weak self] previewLayer in
            guard let self = self else { return }
            self.view.layer.insertSublayer(previewLayer, at: 0)
        }
        cameraManager.delegate = self
    }
    
    // MARK: - Функция: Настройка MediaPipe
    private func setupMediaPipe() {
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            print("Не удалось найти файл модели pose_landmarker_full.task")
            return
        }
        
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.poseLandmarkerLiveStreamDelegate = self
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
            isPoseLandmarkerSetup = true
        } catch {
            print("Ошибка инициализации Pose Landmarker: \(error)")
        }
    }
    
    // MARK: - Функция: Настройка PoseProcessor
    private func setupPoseProcessor() {
        poseProcessor = PoseProcessor()
        poseProcessor.onRepCountUpdated = { [weak self] count in
            DispatchQueue.main.async {
                self?.repsLabel.text = "Повторения: \(count)"
            }
        }
    }
    
    // MARK: - PoseLandmarkerLiveStreamDelegate
    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        guard let result = result, error == nil else {
            print("Ошибка обработки MediaPipe: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            return
        }
        
        poseProcessor.processPoseLandmarks(result)
    }
    
    // MARK: - Функция: Завершение упражнения
    @objc private func finishExercise() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - CameraManagerDelegate
extension ExerciseExecutionViewController: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestamp: Int64) {
        guard isPoseLandmarkerSetup, poseLandmarker != nil else {
            print("PoseLandmarker не инициализирован")
            return
        }
        
        guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
            print("Не удалось преобразовать CMSampleBuffer в MPImage")
            return
        }
        
        do {
            let timestampInMilliseconds = Int(timestamp)
            try poseLandmarker?.detectAsync(image: image, timestampInMilliseconds: timestampInMilliseconds)
        } catch {
            print("Ошибка обработки кадра: \(error)")
        }
    }
}
