import Foundation

struct Exercise: Codable {
    let name: String
    let description: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
    }
}
