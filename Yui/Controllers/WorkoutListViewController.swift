import UIKit

class WorkoutListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let viewModel: WorkoutListViewModelProtocol
    private let cameraService: CameraService
    private let poseDetectionService: PoseDetectionService
    private let poseProcessor: PoseProcessor
    
    init(
        viewModel: WorkoutListViewModelProtocol,
        cameraService: CameraService,
        poseDetectionService: PoseDetectionService,
        poseProcessor: PoseProcessor
    ) {
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
        title = "Workouts"
        
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "WorkoutCell")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfWorkouts()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WorkoutCell", for: indexPath)
        cell.textLabel?.text = viewModel.workoutName(at: indexPath.row)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let exercises = viewModel.exercisesForWorkout(at: indexPath.row)
        let exerciseListViewModel = ExerciseListViewModel(exercises: exercises)
        
        let controller = ExerciseListViewController(
            viewModel: exerciseListViewModel,
            cameraService: cameraService,
            poseDetectionService: poseDetectionService,
            poseProcessor: poseProcessor
        )
        navigationController?.pushViewController(controller, animated: true)
    }
}
