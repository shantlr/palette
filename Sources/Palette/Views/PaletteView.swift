import SwiftUI

enum PaletteMode: Equatable {
    case browse
    case adding
    case editing(Command)
    case settings
}

struct PaletteView: View {
    @ObservedObject var registry: CommandRegistry
    let runner: CommandRunner
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var lastResult: CommandResult?
    @State private var isRunning = false
    @State private var mode: PaletteMode = .browse

    private let columns = 4

    private var addCardIndex: Int { filteredCommands.count }
    private var totalItems: Int { filteredCommands.count + 1 }

    var filteredCommands: [Command] {
        if searchText.isEmpty { return registry.commands }
        return registry.commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
    }

    var body: some View {
        Group {
            switch mode {
            case .browse:
                browseView
            case .adding:
                CommandFormView(
                    onSave: { command in
                        registry.commands.append(command)
                        try? registry.save()
                        mode = .browse
                    },
                    onCancel: { mode = .browse }
                )
            case .editing(let command):
                CommandFormView(
                    existing: command,
                    onSave: { updated in
                        if let idx = registry.commands.firstIndex(where: { $0.id == command.id }) {
                            registry.commands[idx] = updated
                        }
                        try? registry.save()
                        mode = .browse
                    },
                    onCancel: { mode = .browse },
                    onDelete: {
                        registry.commands.removeAll { $0.id == command.id }
                        try? registry.save()
                        mode = .browse
                    }
                )
            case .settings:
                SettingsView(
                    configPath: registry.configPath,
                    onBack: { mode = .browse }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .paletteEscapeKey)) { _ in
            if mode == .browse {
                onDismiss()
            } else {
                mode = .browse
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .paletteWillOpen)) { _ in
            searchText = ""
            selectedIndex = 0
            lastResult = nil
            mode = .browse
        }
        .onChange(of: mode) { _, newMode in
            let modeStr = newMode == .browse ? "browse" : "other"
            NotificationCenter.default.post(name: .paletteModeChanged, object: modeStr)
        }
    }

    private var browseView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit { activateSelected() }

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    mode = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.hover)
            }
            .padding(16)

            Divider()

            // Command grid
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandCard(command: command, isSelected: index == selectedIndex) {
                                mode = .editing(command)
                            }
                            .id(index)
                            .onTapGesture {
                                selectedIndex = index
                                runSelected()
                            }
                        }

                        // Add card at end
                        AddCommandCard(isSelected: selectedIndex == addCardIndex)
                            .id(addCardIndex)
                            .onTapGesture {
                                mode = .adding
                            }
                    }
                    .padding(12)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    proxy.scrollTo(newValue)
                }
            }

            // Output area
            if let result = lastResult {
                Divider()
                OutputView(result: result)
                    .padding(.vertical, 8)
            }
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
            lastResult = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .paletteArrowKey)) { note in
            guard mode == .browse, let dir = note.object as? String else { return }
            switch dir {
            case "left":
                if selectedIndex > 0 { selectedIndex -= 1 }
            case "right":
                if selectedIndex < totalItems - 1 { selectedIndex += 1 }
            case "up":
                let newIndex = selectedIndex - columns
                if newIndex >= 0 { selectedIndex = newIndex }
            case "down":
                let newIndex = selectedIndex + columns
                if newIndex < totalItems { selectedIndex = newIndex }
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .paletteEnterKey)) { _ in
            guard mode == .browse else { return }
            activateSelected()
        }
    }

    private func activateSelected() {
        if selectedIndex == addCardIndex {
            mode = .adding
        } else {
            runSelected()
        }
    }

    private func runSelected() {
        guard !filteredCommands.isEmpty else { return }
        let command = filteredCommands[selectedIndex]
        isRunning = true
        Task {
            do {
                let result = try await runner.run(command)
                await MainActor.run {
                    lastResult = result
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    lastResult = CommandResult(output: "", error: error.localizedDescription, exitCode: -1)
                    isRunning = false
                }
            }
        }
    }
}
