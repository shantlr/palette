import Foundation

struct Command: Codable, Identifiable, Sendable, Equatable {
    var id: String { name }
    let name: String
    let description: String
    let script: String
    let icon: String?
    let shortcut: String?

    enum CodingKeys: String, CodingKey {
        case name, description, script, icon, shortcut
    }
}
