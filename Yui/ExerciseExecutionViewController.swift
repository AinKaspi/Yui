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
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var poseLandmarker: PoseLandmarker?
    private var isPoseLandmarkerSetup = false
    private let landmarksLayer = CALayer() // Слой для отображения ключевых точек
    
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
        print("viewDidLoad вызван для \(exercise.name)")
        setupUI()
        setupLoadingIndicator()
        setupCameraManager()
        setupMediaPipe()
        setupPoseProcessor()
        setupLandmarksLayer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear вызван, запускаем камеру")
        cameraManager.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear вызван, останавливаем камеру")
        cameraManager.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraManager.updatePreviewLayerFrame(view.bounds)
        landmarksLayer.frame = view.bounds // Обновляем размеры слоя для точек
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
        print("Настройка CameraManager")
        cameraManager = CameraManager()
        cameraManager.setupCamera { [weak self] previewLayer in
            guard let self = self else { return }
            print("Камера настроена, добавляем previewLayer")
            self.view.layer.insertSublayer(previewLayer, at: 0)
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating() // Останавливаем индикатор, когда камера готова
            }
        }
        cameraManager.delegate = self
    }
    
    // MARK: - Функция: Настройка MediaPipe
    private func setupMediaPipe() {
        print("Настройка MediaPipe")
        let startTime = Date()
        
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            print("Не удалось найти файл модели pose_landmarker_full.task")
            return
        }
        
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.3
        options.minTrackingConfidence = 0.3
        options.minPosePresenceConfidence = 0.3
        options.poseLandmarkerLiveStreamDelegate = self
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
            isPoseLandmarkerSetup = true
            let duration = Date().timeIntervalSince(startTime)
            print("MediaPipe успешно настроен за \(duration) секунд")
        } catch {
            print("Ошибка инициализации Pose Landmarker: \(error)")
        }
    }
    
    // MARK: - Функция: Настройка PoseProcessor
    private func setupPoseProcessor() {
        print("Настройка PoseProcessor")
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
        
        // Рисуем ключевые точки
        DispatchQueue.main.async { [weak self] in
            self?.drawLandmarks(result.landmarks.first)
        }
    }
    
    // MARK: - Функция: Отрисовка ключевых точек
    private func drawLandmarks(_ landmarks: [NormalizedLandmark]?) {
        guard let landmarks = landmarks else { return }
        
        // Очищаем старые точки
        landmarksLayer.sublayers?.removeAll()
        
        // Размеры экрана
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        
        // Размеры изображения с камеры
        let imageWidth: CGFloat = 1920.0
        let imageHeight: CGFloat = 1080.0
        
        // Учитываем ориентацию .right (поворот на 90 градусов)
        for landmark in landmarks {
            // Нормализованные координаты
            var x = CGFloat(landmark.x)
            var y = CGFloat(landmark.y)
            
            // Проверяем, что координаты в допустимом диапазоне
            if x < 0 || x > 1 || y < 0 || y > 1 {
                print("Недопустимые координаты: x=\(x), y=\(y)")
                continue
            }
            
            // Учитываем поворот на 90 градусов (для .right)
            let rotatedX = y
            let rotatedY = 1.0 - x
            
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
            print("PoseLandmarker не инициализирован")
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Не удалось получить pixelBuffer из sampleBuffer")
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("Размеры изображения: \(width)x\(height)")
        
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
