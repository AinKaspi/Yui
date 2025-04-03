import Foundation

struct Workout: Codable {
    let name: String
    let exercises: [Exercise]
    var completedReps: [String: Int]?
    var completionDate: Date?

    init(name: String, exercises: [Exercise]) {
        self.name = name
        self.exercises = exercises
        self.completedReps = nil
        self.completionDate = nil
    }

    enum CodingKeys: String, CodingKey {
        case name
        case exercises
        case completedReps
        case completionDate
    }
}
