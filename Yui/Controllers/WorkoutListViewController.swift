import UIKit
import os.log

class WorkoutListViewController: UIViewController {
    // MARK: - Свойства
    private let viewModel: WorkoutListViewModel
    private let storageService: StorageServiceProtocol
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Инициализация
    init(viewModel: WorkoutListViewModel, storageService: StorageServiceProtocol) {
        self.viewModel = viewModel
        self.storageService = storageService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Жизненный цикл
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("WorkoutListViewController: viewDidLoad вызван", log: OSLog.default, type: .debug)
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData() // Обновляем таблицу при возвращении
    }
    
    // MARK: - Настройка UI
    private func setupUI() {
        title = "Тренировки"
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "WorkoutCell")
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource
extension WorkoutListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfWorkouts
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WorkoutCell", for: indexPath)
        cell.textLabel?.text = viewModel.workoutName(at: indexPath.row)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension WorkoutListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let workout = viewModel.workout(at: indexPath.row)
        let exerciseListViewModel = ExerciseListViewModel(workout: workout)
        let exerciseListVC = ExerciseListViewController(viewModel: exerciseListViewModel, workout: workout, storageService: storageService)
        navigationController?.pushViewController(exerciseListVC, animated: true)
    }
}
