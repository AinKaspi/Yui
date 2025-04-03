import Foundation

protocol WorkoutListViewModelProtocol {
    var workouts: [Workout] { get }
}

class WorkoutListViewModel: WorkoutListViewModelProtocol {
    private(set) var workouts: [Workout] = []
    
    init() {
        // Заглушка: загрузка тренировок
        let exercises = [
            Exercise(name: "Приседания", description: "Базовое упражнение для ног", type: "repetitive"),
            Exercise(name: "Отжимания", description: "Упражнение для верхней части тела", type: "repetitive")
        ]
        let workout = Workout(name: "Тренировка 1", exercises: exercises)
        workouts = [workout]
    }
}
