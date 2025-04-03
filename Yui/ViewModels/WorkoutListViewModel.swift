import Foundation
import os.log

class WorkoutListViewModel {
    // MARK: - Свойства
    private var workouts: [Workout]
    private let storageService: StorageServiceProtocol
    
    // MARK: - Инициализация
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
        
        // Загружаем сохранённые тренировки
        let savedWorkouts = storageService.loadWorkouts()
        if savedWorkouts.isEmpty {
            // Если сохранённых тренировок нет, инициализируем стандартный список
            self.workouts = [
                Workout(name: "Утренняя тренировка", exercises: [
                    Exercise(name: "Приседания", description: "20 повторений", type: "repetitive"),
                    Exercise(name: "Отжимания", description: "15 повторений", type: "pushUp")
                ]),
                Workout(name: "Вечерняя тренировка", exercises: [
                    Exercise(name: "Приседания", description: "15 повторений", type: "repetitive")
                ])
            ]
            // Сохраняем стандартный список
            storageService.saveWorkouts(self.workouts)
        } else {
            self.workouts = savedWorkouts
        }
    }
    
    // MARK: - Методы для UI
    var numberOfWorkouts: Int {
        return workouts.count
    }
    
    func workoutName(at index: Int) -> String {
        let workout = workouts[index]
        if let completionDate = workout.completionDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "\(workout.name) (Завершена: \(formatter.string(from: completionDate)))"
        }
        return workout.name
    }
    
    func workout(at index: Int) -> Workout {
        return workouts[index]
    }
}
