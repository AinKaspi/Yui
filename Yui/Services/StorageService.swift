import Foundation

class StorageService: StorageServiceProtocol {
    func loadWorkouts() -> [(name: String, exercises: [Exercise])] {
        return [
            (name: "Workout 1", exercises: [
                Exercise(name: "Push-up", description: "Upper body exercise", type: "Strength"),
                Exercise(name: "Squat", description: "Lower body exercise", type: "Strength")
            ]),
            (name: "Workout 2", exercises: [
                Exercise(name: "Plank", description: "Core exercise", type: "Endurance"),
                Exercise(name: "Lunge", description: "Leg exercise", type: "Strength")
            ])
        ]
    }
}
