import UIKit
import AVFoundation
import os.log

class ExerciseExecutionViewController: UIViewController {
    // MARK: - Свойства
    private let viewModel: ExerciseExecutionViewModelProtocol
    private let workout: Workout // Добавляем свойство для хранения тренировки
    
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
    
    private let poseOverlayView = PoseOverlayView()
    
    // MARK: - Инициализация
    init(viewModel: ExerciseExecutionViewModelProtocol, workout: Workout) {
        self.viewModel = viewModel
        self.workout = workout
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Жизненный цикл
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("ExerciseExecutionViewController: viewDidLoad вызван", log: OSLog.default, type: .debug)
        setupUI()
        setupLoadingIndicator()
        setupPoseOverlayView()
        viewModel.setup()
        
        viewModel.cameraService.setupCamera { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let previewLayer):
                self.view.layer.insertSublayer(previewLayer, at: 0)
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                }
            case .failure(let error):
                os_log("ExerciseExecutionViewController: Ошибка настройки камеры: %@", log: OSLog.default, type: .error, String(describing: error))
                self.showCameraErrorAlert(error: error)
            }
        }
        
        setupBindings()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("ExerciseExecutionViewController: viewDidAppear вызван, запускаем камеру", log: OSLog.default, type: .debug)
        viewModel.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        os_log("ExerciseExecutionViewController: viewWillDisappear вызван, останавливаем камеру", log: OSLog.default, type: .debug)
        viewModel.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewModel.updatePreviewLayerFrame(view.bounds)
        poseOverlayView.frame = view.bounds
        viewModel.drawLandmarks(in: poseOverlayView)
    }
    
    // MARK: - Настройка UI
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(exerciseLabel)
        view.addSubview(repsLabel)
        view.addSubview(instructionLabel)
        view.addSubview(finishButton)
        
        exerciseLabel.text = viewModel.exerciseName
        repsLabel.text = viewModel.repsCount
        instructionLabel.text = viewModel.instructionText
        instructionLabel.isHidden = viewModel.isInstructionHidden
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
    
    private func setupLoadingIndicator() {
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        loadingIndicator.startAnimating()
    }
    
    private func setupPoseOverlayView() {
        poseOverlayView.frame = view.bounds
        poseOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(poseOverlayView)
        
        NSLayoutConstraint.activate([
            poseOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            poseOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            poseOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            poseOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupBindings() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.repsLabel.text = self.viewModel.repsCount
            self.instructionLabel.text = self.viewModel.instructionText
            self.instructionLabel.isHidden = self.viewModel.isInstructionHidden
            self.viewModel.drawLandmarks(in: self.poseOverlayView)
        }
    }
    
    // MARK: - Обработка ошибок камеры
    private func showCameraErrorAlert(error: CameraServiceError) {
        let message: String
        switch error {
        case .cameraNotAvailable:
            message = "Фронтальная камера недоступна на этом устройстве."
        case .inputSetupFailed(let underlyingError):
            message = "Не удалось настроить вход камеры: \(underlyingError.localizedDescription)"
        case .outputSetupFailed:
            message = "Не удалось настроить выход камеры."
        case .sessionConfigurationFailed:
            message = "Не удалось настроить сессию камеры."
        case .permissionDenied:
            message = "Доступ к камере запрещён. Пожалуйста, разрешите доступ в настройках."
        }
        
        let alert = UIAlertController(title: "Ошибка камеры", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Действия
    @objc private func finishExercise() {
        viewModel.saveResults(workout: workout)
        navigationController?.popViewController(animated: true)
    }
}
