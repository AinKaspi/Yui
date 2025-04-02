import UIKit
import AVFoundation
import MediaPipeTasksVision
import os.log

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
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "Подойдите ближе к камере"
        label.isHidden = true
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
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var poseLandmarker: PoseLandmarker?
    private var isPoseLandmarkerSetup = false
    private let landmarksLayer = CALayer()
    
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
        os_log("ExerciseExecutionViewController: viewDidLoad вызван для %@", log: OSLog.default, type: .debug, exercise.name)
        setupUI()
        setupLoadingIndicator()
        setupCameraManager()
        setupMediaPipe()
        setupPoseProcessor()
        setupLandmarksLayer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("ExerciseExecutionViewController: viewDidAppear вызван, запускаем камеру", log: OSLog.default, type: .debug)
        cameraManager.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        os_log("ExerciseExecutionViewController: viewWillDisappear вызван, останавливаем камеру", log: OSLog.default, type: .debug)
        cameraManager.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraManager.updatePreviewLayerFrame(view.bounds)
        landmarksLayer.frame = view.bounds
    }
    
    // MARK: - Функция: Настройка UI
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(exerciseLabel)
        view.addSubview(repsLabel)
        view.addSubview(instructionLabel)
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
            
            instructionLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            finishButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            finishButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            finishButton.widthAnchor.constraint(equalToConstant: 200),
            finishButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Функция: Настройка индикатора загрузки
    private func setupLoadingIndicator() {
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        loadingIndicator.startAnimating()
    }
    
    // MARK: - Функция: Настройка слоя для ключевых точек
    private func setupLandmarksLayer() {
        landmarksLayer.frame = view.bounds
        landmarksLayer.backgroundColor = UIColor.clear.cgColor
        view.layer.addSublayer(landmarksLayer)
    }
    
    // MARK: - Функция: Настройка CameraManager
    private func setupCameraManager() {
        os_log("ExerciseExecutionViewController: Настройка CameraManager", log: OSLog.default, type: .debug)
        cameraManager = CameraManager()
        cameraManager.setupCamera { [weak self] previewLayer in
            guard let self = self else { return }
            os_log("ExerciseExecutionViewController: Камера настроена, добавляем previewLayer", log: OSLog.default, type: .debug)
            self.view.layer.insertSublayer(previewLayer, at: 0)
            self.cameraManager.updatePreviewLayerFrame(self.view.bounds)
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
            }
        }
        cameraManager.delegate = self
    }
    
    // MARK: - Функция: Настройка MediaPipe
    private func setupMediaPipe() {
        os_log("ExerciseExecutionViewController: Настройка MediaPipe", log: OSLog.default, type: .debug)
        let startTime = Date()
        
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            os_log("ExerciseExecutionViewController: Не удалось найти файл модели pose_landmarker_full.task", log: OSLog.default, type: .error)
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
        
        // Указываем размеры изображения для корректной нормализации
        options.baseOptions.imageWidth = 1920
        options.baseOptions.imageHeight = 1080
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
            isPoseLandmarkerSetup = true
            let duration = Date().timeIntervalSince(startTime)
            os_log("ExerciseExecutionViewController: MediaPipe успешно настроен за %f секунд", log: OSLog.default, type: .debug, duration)
        } catch {
            os_log("ExerciseExecutionViewController: Ошибка инициализации Pose Landmarker: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Функция: Настройка PoseProcessor
    private func setupPoseProcessor() {
        os_log("ExerciseExecutionViewController: Настройка PoseProcessor", log: OSLog.default, type: .debug)
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
            os_log("ExerciseExecutionViewController: Ошибка обработки MediaPipe: %@", log: OSLog.default, type: .error, error?.localizedDescription ?? "Неизвестная ошибка")
            DispatchQueue.main.async { [weak self] in
                self?.instructionLabel.isHidden = false
            }
            return
        }
        
        poseProcessor.processPoseLandmarks(result)
        
        DispatchQueue.main.async { [weak self] in
            self?.instructionLabel.isHidden = true
            self?.drawLandmarks(result.landmarks.first)
        }
    }
    
    // MARK: - Функция: Отрисовка ключевых точек
    private func drawLandmarks(_ landmarks: [NormalizedLandmark]?) {
        guard let landmarks = landmarks else {
            os_log("ExerciseExecutionViewController: Нет ключевых точек для отрисовки", log: OSLog.default, type: .debug)
            landmarksLayer.sublayers?.removeAll()
            return
        }
        
        landmarksLayer.sublayers?.removeAll()
        
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        
        for landmark in landmarks {
            // Фильтруем точки с низкой видимостью
            let visibility = landmark.visibility?.floatValue ?? 0.0
            if visibility < 0.5 {
                continue
            }
            
            let x = CGFloat(landmark.x)
            let y = CGFloat(landmark.y)
            
            // Пропускаем некорректные координаты
            if x < 0 || x > 1 || y < 0 || y > 1 {
                os_log("ExerciseExecutionViewController: Недопустимые координаты: x=%f, y=%f", log: OSLog.default, type: .debug, x, y)
                continue
            }
            
            // Учитываем зеркальность фронтальной камеры
            let rotatedX = 1.0 - x // Зеркалим по горизонтали
            let rotatedY = y
            
            // Масштабируем к размерам экрана
            let scaledX = rotatedX * screenWidth
            let scaledY = rotatedY * screenHeight
            
            let pointLayer = CALayer()
            pointLayer.bounds = CGRect(x: 0, y: 0, width: 5, height: 5)
            pointLayer.position = CGPoint(x: scaledX, y: scaledY)
            pointLayer.backgroundColor = UIColor.red.cgColor
            landmarksLayer.addSublayer(pointLayer)
        }
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
            os_log("ExerciseExecutionViewController: PoseLandmarker не инициализирован", log: OSLog.default, type: .error)
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            os_log("ExerciseExecutionViewController: Не удалось получить pixelBuffer из sampleBuffer", log: OSLog.default, type: .error)
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        os_log("ExerciseExecutionViewController: Размеры изображения: %dx%d", log: OSLog.default, type: .debug, width, height)
        
        guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
            os_log("ExerciseExecutionViewController: Не удалось преобразовать CMSampleBuffer в MPImage", log: OSLog.default, type: .error)
            return
        }
        
        do {
            let timestampInMilliseconds = Int(timestamp)
            try poseLandmarker?.detectAsync(image: image, timestampInMilliseconds: timestampInMilliseconds)
        } catch {
            os_log("ExerciseExecutionViewController: Ошибка обработки кадра: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
}
