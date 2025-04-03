import Foundation

// MARK: - Модель упражнения
struct Exercise: Codable {
    let name: String
    let description: String
    let type: String
}

// MARK: - Модель тренировки с результатами
struct Workout: Codable {
    let name: String
    let exercises: [Exercise]
    var completedReps: [String: Int]? // [Название упражнения: Количество повторений]
    var completionDate: Date? // Дата завершения тренировки
    
    // Инициализатор для создания новой тренировки
    init(name: String, exercises: [Exercise]) {
        self.name = name
        self.exercises = exercises
        self.completedReps = nil
        self.completionDate = nil
    }
}
