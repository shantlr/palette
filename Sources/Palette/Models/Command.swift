import Foundation

struct Command: Codable, Identifiable, Sendable, Equatable {
    var id: String { name }
    let name: String
    let description: String
    let section: String?
    let script: String
    let icon: String?
    let shortcut: String?

    var normalizedSection: String? {
        guard let section, !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return section.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey {
        case name, description, section, script, icon, shortcut
    }
}
