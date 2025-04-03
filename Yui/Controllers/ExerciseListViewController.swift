import UIKit
import os.log

class ExerciseListViewController: UIViewController {
    private let workout: Workout
    private var exercises: [Exercise] = []
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    init(workout: Workout) {
        self.workout = workout
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("ExerciseListViewController: viewDidLoad вызван для тренировки %@", log: OSLog.default, type: .debug, workout.name)
        exercises = workout.exercises
        setupUI()
    }
    
    private func setupUI() {
        title = workout.name
        view.backgroundColor = .systemBackground
        
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

// MARK: - UITableViewDataSource, UITableViewDelegate
extension ExerciseListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exercises.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath)
        cell.textLabel?.text = exercises[indexPath.row].name
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let exercise = exercises[indexPath.row]
        
        // Создание сервисов
        let cameraService = CameraService()
        let poseDetectionService = PoseDetectionService()
        let imageProcessingService = ImageProcessingService()
        let visualizationService = VisualizationService()
        
        // Создание ViewModel
        let viewModel = ExerciseExecutionViewModel(
            exercise: exercise,
            cameraService: cameraService,
            poseDetectionService: poseDetectionService,
            imageProcessingService: imageProcessingService,
            visualizationService: visualizationService
        )
        
        // Создание ViewController
        let controller = ExerciseExecutionViewController(viewModel: viewModel)
        navigationController?.pushViewController(controller, animated: true)
    }
}
