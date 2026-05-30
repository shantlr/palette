import Foundation

@MainActor
final class CommandRegistry: ObservableObject {
    @Published var commands: [Command] = []

    let configURL: URL
    var configPath: String { configURL.path }

    init(configURL: URL? = nil) {
        self.configURL = configURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".palette/commands.json")
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            commands = Self.defaultCommands
            try save()
            return
        }
        let data = try Data(contentsOf: configURL)
        commands = try JSONDecoder().decode([Command].self, from: data)
    }

    func save() throws {
        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(commands)
        try data.write(to: configURL)
    }

    static let defaultCommands: [Command] = [
        Command(
            name: "Say Hello",
            description: "Print a greeting",
            script: "echo 'Hello from Palette!'",
            icon: "hand.wave",
            shortcut: nil
        ),
        Command(
            name: "Date",
            description: "Show current date and time",
            script: "date",
            icon: "calendar",
            shortcut: nil
        ),
        Command(
            name: "Disk Usage",
            description: "Show disk usage summary",
            script: "df -h | head -5",
            icon: "internaldrive",
            shortcut: nil
        ),
    ]
}
