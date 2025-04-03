import Foundation

protocol WorkoutListViewModelProtocol {
    func numberOfWorkouts() -> Int
    func workoutName(at index: Int) -> String
    func exercisesForWorkout(at index: Int) -> [Exercise]
}

protocol StorageServiceProtocol {
    func loadWorkouts() -> [(name: String, exercises: [Exercise])]
}

class WorkoutListViewModel: WorkoutListViewModelProtocol {
    private let workouts: [(name: String, exercises: [Exercise])]
    
    init(storageService: StorageServiceProtocol) {
        self.workouts = storageService.loadWorkouts()
    }
    
    func numberOfWorkouts() -> Int {
        return workouts.count
    }
    
    func workoutName(at index: Int) -> String {
        return workouts[index].name
    }
    
    func exercisesForWorkout(at index: Int) -> [Exercise] {
        return workouts[index].exercises
    }
}
