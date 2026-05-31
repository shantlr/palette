import Foundation

struct Command: Codable, Identifiable, Sendable, Equatable {
    var id: String { name }
    let name: String
    let description: String
    let section: String?
    let script: String
    let icon: String?
    let shortcut: String?
    let tileRow: Int?
    let tileColumn: Int?

    var normalizedSection: String? {
        guard let section, !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return section.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedTilePosition: (row: Int, column: Int)? {
        guard let tileRow, let tileColumn, tileRow >= 0, tileColumn >= 0 else { return nil }
        return (tileRow, tileColumn)
    }

    func withPlacement(section: String?, row: Int, column: Int) -> Command {
        Command(
            name: name,
            description: description,
            section: section,
            script: script,
            icon: icon,
            shortcut: shortcut,
            tileRow: row,
            tileColumn: column
        )
    }

    enum CodingKeys: String, CodingKey {
        case name, description, section, script, icon, shortcut, tileRow, tileColumn
    }
}
