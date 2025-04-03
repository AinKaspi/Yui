import Foundation

class ExerciseListViewModel {
    private let exercises: [Exercise]
    
    init(exercises: [Exercise]) {
        self.exercises = exercises
    }
    
    func numberOfExercises() -> Int {
        return exercises.count
    }
    
    func exerciseName(at index: Int) -> String {
        return exercises[index].name
    }
    
    func exercise(at index: Int) -> Exercise {
        return exercises[index]
    }
}
