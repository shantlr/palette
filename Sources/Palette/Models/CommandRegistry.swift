import Foundation

@MainActor
final class CommandRegistry: ObservableObject {
    @Published var commands: [Command] = []

    let configURL: URL
    var configPath: String { configURL.path }

    private var watchTimer: Timer?
    private var lastLoadedData: Data?

    init(configURL: URL? = nil) {
        self.configURL = configURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".palette/commands.json")
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            commands = Self.defaultCommands
            notifyCommandsChanged()
            try save()
            return
        }
        let data = try Data(contentsOf: configURL)
        commands = try JSONDecoder().decode([Command].self, from: data)
        lastLoadedData = data
        notifyCommandsChanged()
    }

    func save() throws {
        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(commands)
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

        commands = try JSONDecoder().decode([Command].self, from: data)
        lastLoadedData = data
        notifyCommandsChanged()
    }

    func moveCommand(id: String, before targetID: String?) throws {
        var updatedCommands = commands
        guard let sourceIndex = updatedCommands.firstIndex(where: { $0.id == id }) else { return }

        let command = updatedCommands.remove(at: sourceIndex)

        if let targetID,
           let targetIndex = updatedCommands.firstIndex(where: { $0.id == targetID }) {
            updatedCommands.insert(command, at: targetIndex)
        } else {
            updatedCommands.append(command)
        }

        commands = updatedCommands
        notifyCommandsChanged()

        try save()
    }

    private func notifyCommandsChanged() {
        NotificationCenter.default.post(name: .paletteCommandsChanged, object: nil)
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
