import Foundation

@MainActor
final class CommandRegistry: ObservableObject {
    @Published var commands: [Command] = []

    let configURL: URL
    var configPath: String { configURL.path }

    private var watchTimer: Timer?
    private var lastLoadedData: Data?

    private struct TilePosition: Hashable {
        let row: Int
        let column: Int
    }

    init(configURL: URL? = nil) {
        self.configURL = configURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".palette/commands.json")
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            commands = Self.normalizedCommands(from: Self.defaultCommands)
            notifyCommandsChanged()
            try save()
            return
        }
        let data = try Data(contentsOf: configURL)
        let decodedCommands = try JSONDecoder().decode([Command].self, from: data)
        commands = Self.normalizedCommands(from: decodedCommands)
        lastLoadedData = data
        notifyCommandsChanged()
    }

    func save() throws {
        let normalizedCommands = Self.normalizedCommands(from: commands)
        if normalizedCommands != commands {
            commands = normalizedCommands
        }

        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalizedCommands)
        try data.write(to: configURL)
        lastLoadedData = data
        notifyCommandsChanged()
    }

    func startWatching() throws {
        stopWatching()

        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? self?.reloadIfChanged()
            }
        }
    }

    func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
    }

    func reloadIfChanged() throws {
        if !FileManager.default.fileExists(atPath: configURL.path) {
            return
        }

        let data = try Data(contentsOf: configURL)
        guard data != lastLoadedData else { return }

        let decodedCommands = try JSONDecoder().decode([Command].self, from: data)
        commands = Self.normalizedCommands(from: decodedCommands)
        lastLoadedData = data
        notifyCommandsChanged()
    }

    func placeCommand(id: String, in section: String?, row: Int, column: Int) throws {
        var updatedCommands = Self.normalizedCommands(from: commands)
        guard let sourceIndex = updatedCommands.firstIndex(where: { $0.id == id }) else { return }

        let sourceCommand = updatedCommands[sourceIndex]
        guard let sourcePosition = sourceCommand.normalizedTilePosition else { return }

        let targetSection = Self.normalizeSection(section)
        let targetIndex = updatedCommands.firstIndex {
            $0.id != id &&
            $0.normalizedSection == targetSection &&
            $0.tileRow == row &&
            $0.tileColumn == column
        }

        updatedCommands[sourceIndex] = sourceCommand.withPlacement(section: targetSection, row: row, column: column)

        if let targetIndex {
            let targetCommand = updatedCommands[targetIndex]
            updatedCommands[targetIndex] = targetCommand.withPlacement(
                section: sourceCommand.normalizedSection,
                row: sourcePosition.row,
                column: sourcePosition.column
            )
        }

        commands = Self.normalizedCommands(from: updatedCommands)
        notifyCommandsChanged()
        try save()
    }

    private static func normalizedCommands(from commands: [Command]) -> [Command] {
        var occupiedPositions: [String: Set<TilePosition>] = [:]
        var normalized: [Command] = []

        for command in commands {
            let section = normalizeSection(command.section)
            let sectionKey = storageKey(for: section)
            var sectionPositions = occupiedPositions[sectionKey, default: []]

            if let position = command.normalizedTilePosition.map({ TilePosition(row: $0.row, column: $0.column) }),
               !sectionPositions.contains(position) {
                sectionPositions.insert(position)
                occupiedPositions[sectionKey] = sectionPositions
                normalized.append(command.withPlacement(section: section, row: position.row, column: position.column))
                continue
            }

            let nextPosition = nextAvailablePosition(occupied: sectionPositions)
            sectionPositions.insert(nextPosition)
            occupiedPositions[sectionKey] = sectionPositions
            normalized.append(command.withPlacement(section: section, row: nextPosition.row, column: nextPosition.column))
        }

        return normalized
    }

    private static func nextAvailablePosition(occupied: Set<TilePosition>, columns: Int = 6) -> TilePosition {
        var row = 0
        var column = 0

        while occupied.contains(TilePosition(row: row, column: column)) {
            column += 1
            if column == columns {
                column = 0
                row += 1
            }
        }

        return TilePosition(row: row, column: column)
    }

    private static func storageKey(for section: String?) -> String {
        section ?? "__default__"
    }

    private static func normalizeSection(_ section: String?) -> String? {
        guard let section, !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return section.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func notifyCommandsChanged() {
        NotificationCenter.default.post(name: .paletteCommandsChanged, object: nil)
    }

    static let defaultCommands: [Command] = [
        Command(
            name: "Say Hello",
            description: "Print a greeting",
            section: nil,
            script: "echo 'Hello from Palette!'",
            icon: "hand.wave",
            shortcut: nil,
            tileRow: 0,
            tileColumn: 0
        ),
        Command(
            name: "Date",
            description: "Show current date and time",
            section: nil,
            script: "date",
            icon: "calendar",
            shortcut: nil,
            tileRow: 0,
            tileColumn: 1
        ),
        Command(
            name: "Disk Usage",
            description: "Show disk usage summary",
            section: nil,
            script: "df -h | head -5",
            icon: "internaldrive",
            shortcut: nil,
            tileRow: 0,
            tileColumn: 2
        ),
    ]
}
