import Foundation

protocol ExerciseListViewModelProtocol {
    var workoutName: String { get }
    var exercises: [Exercise] { get }
}

class ExerciseListViewModel: ExerciseListViewModelProtocol {
    private let workout: Workout
    
    var workoutName: String {
        return workout.name
    }
    
    var exercises: [Exercise] {
        return workout.exercises
    }
    
    init(workout: Workout) {
        self.workout = workout
    }
}
