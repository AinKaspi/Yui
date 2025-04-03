import UIKit

class ExerciseListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let viewModel: ExerciseListViewModel
    private let cameraService: CameraService
    private let poseDetectionService: PoseDetectionService
    private let poseProcessor: PoseProcessor
    
    init(viewModel: ExerciseListViewModel, cameraService: CameraService, poseDetectionService: PoseDetectionService, poseProcessor: PoseProcessor) {
        self.viewModel = viewModel
        self.cameraService = cameraService
        self.poseDetectionService = poseDetectionService
        self.poseProcessor = poseProcessor
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Exercises"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExerciseCell")
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfExercises()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath)
        cell.textLabel?.text = viewModel.exerciseName(at: indexPath.row)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let exercise = viewModel.exercise(at: indexPath.row)
        
        let overlayView = PoseOverlayView(frame: .zero) // Создаём overlayView
        let visualizationService = VisualizationService(overlayView: overlayView)
        let controller = ExerciseExecutionViewController(
            exercise: exercise,
            cameraService: cameraService,
            poseDetectionService: poseDetectionService,
            visualizationService: visualizationService,
            delegate: nil, // Если не нужен делегат, передаём nil или убедись, что он есть
            overlayView: overlayView,
            poseProcessor: poseProcessor
        )
        navigationController?.pushViewController(controller, animated: true)
    }
}
