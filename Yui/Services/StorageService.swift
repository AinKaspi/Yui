import Foundation
import os.log

// MARK: - Протокол StorageServiceProtocol
protocol StorageServiceProtocol {
    func saveWorkouts(_ workouts: [Workout])
    func loadWorkouts() -> [Workout]
}

class StorageService: StorageServiceProtocol {
    // MARK: - Свойства
    private let workoutsKey = "com.yui.workouts"
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Сохранение тренировок
    func saveWorkouts(_ workouts: [Workout]) {
        os_log("StorageService: saveWorkouts вызван", log: OSLog.default, type: .debug)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(workouts)
            userDefaults.set(data, forKey: workoutsKey)
            os_log("StorageService: Тренировки успешно сохранены", log: OSLog.default, type: .debug)
        } catch {
            os_log("StorageService: Ошибка при сохранении тренировок: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Загрузка тренировок
    func loadWorkouts() -> [Workout] {
        os_log("StorageService: loadWorkouts вызван", log: OSLog.default, type: .debug)
        guard let data = userDefaults.data(forKey: workoutsKey) else {
            os_log("StorageService: Данные о тренировках отсутствуют", log: OSLog.default, type: .debug)
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let workouts = try decoder.decode([Workout].self, from: data)
            os_log("StorageService: Тренировки успешно загружены", log: OSLog.default, type: .debug)
            return workouts
        } catch {
            os_log("StorageService: Ошибка при загрузке тренировок: %@", log: OSLog.default, type: .error, error.localizedDescription)
            return []
        }
    }
}
