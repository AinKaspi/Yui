import UIKit
import os.log

class ExerciseListViewController: UIViewController {
    // MARK: - Свойства
    private let viewModel: ExerciseListViewModel
    private let workout: Workout
    private let storageService: StorageServiceProtocol
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Инициализация
    init(viewModel: ExerciseListViewModel, workout: Workout, storageService: StorageServiceProtocol) {
        self.viewModel = viewModel
        self.workout = workout
        self.storageService = storageService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Жизненный цикл
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("ExerciseListViewController: viewDidLoad вызван", log: OSLog.default, type: .debug)
        setupUI()
    }
    
    // MARK: - Настройка UI
    private func setupUI() {
        title = viewModel.workoutName
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExerciseCell")
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource
extension ExerciseListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfExercises
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath)
        cell.textLabel?.text = viewModel.exerciseName(at: indexPath.row)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ExerciseListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let exercise = viewModel.exercise(at: indexPath.row)
        let cameraService = CameraService()
        let poseDetectionService = PoseDetectionService()
        let imageProcessingService = ImageProcessingService()
        let visualizationService = VisualizationService()
        
        let exerciseViewModel = ExerciseExecutionViewModel(
            exercise: exercise,
            cameraService: cameraService,
            poseDetectionService: poseDetectionService,
            imageProcessingService: imageProcessingService,
            visualizationService: visualizationService,
            storageService: storageService
        )
        
        let exerciseVC = ExerciseExecutionViewController(viewModel: exerciseViewModel, workout: workout)
        navigationController?.pushViewController(exerciseVC, animated: true)
    }
}
