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
    @State private var gridRefreshID = UUID()
    @State private var draggedCommandID: String?
    @State private var dropTargetCellID: String?
    private let columns = 6

    private var addCardIndex: Int { displayedCommands.count }
    private var totalItems: Int { displayedCommands.count + 1 }
    private var canReorder: Bool { searchText.isEmpty && mode == .browse }

    var filteredCommands: [Command] {
        if searchText.isEmpty { return registry.commands }
        return registry.commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            ($0.normalizedSection?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var displayedCommands: [Command] {
        let sectionOrder = Dictionary(uniqueKeysWithValues: groupedSectionOrder.enumerated().map { ($0.element, $0.offset) })

        return filteredCommands.sorted { lhs, rhs in
            let lhsSection = storageKey(for: lhs.normalizedSection)
            let rhsSection = storageKey(for: rhs.normalizedSection)
            let lhsOrder = sectionOrder[lhsSection] ?? Int.max
            let rhsOrder = sectionOrder[rhsSection] ?? Int.max

            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

            let lhsPosition = tilePosition(for: lhs)
            let rhsPosition = tilePosition(for: rhs)

            if lhsPosition.row != rhsPosition.row { return lhsPosition.row < rhsPosition.row }
            if lhsPosition.column != rhsPosition.column { return lhsPosition.column < rhsPosition.column }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var groupedSectionOrder: [String] {
        var seen: Set<String> = []
        var orderedSections: [String] = []

        for command in registry.commands {
            let key = storageKey(for: command.normalizedSection)
            if seen.insert(key).inserted {
                orderedSections.append(key)
            }
        }

        return orderedSections
    }

    private var groupedCommands: [(section: String?, commands: [Command])] {
        var grouped: [(section: String?, commands: [Command])] = []

        for command in displayedCommands {
            let section = command.normalizedSection

            if let index = grouped.firstIndex(where: { $0.section == section }) {
                grouped[index].commands.append(command)
            } else {
                grouped.append((section, [command]))
            }
        }

        return grouped
    }

    private func commandIndex(for command: Command) -> Int? {
        displayedCommands.firstIndex(where: { $0.id == command.id })
    }

    private var visibleRows: [[Int]] {
        var rows: [[Int]] = []

        for group in groupedCommands {
            let groupedByRow = Dictionary(grouping: group.commands) { command in
                command.normalizedTilePosition?.row ?? 0
            }

            for row in groupedByRow.keys.sorted() {
                let indices = groupedByRow[row, default: []]
                    .sorted { lhs, rhs in
                        (lhs.normalizedTilePosition?.column ?? 0) < (rhs.normalizedTilePosition?.column ?? 0)
                    }
                    .compactMap(commandIndex(for:))

                if !indices.isEmpty {
                    rows.append(indices)
                }
            }
        }

        rows.append([addCardIndex])
        return rows
    }

    private func selectionPosition(for index: Int) -> (row: Int, column: Int)? {
        for (rowIndex, row) in visibleRows.enumerated() {
            if let columnIndex = row.firstIndex(of: index) {
                return (rowIndex, columnIndex)
            }
        }

        return nil
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
        .onChange(of: lastResult != nil) { _, hasOutput in
            NotificationCenter.default.post(name: .paletteOutputVisibilityChanged, object: hasOutput)
        }
        .onChange(of: mode) { _, newMode in
            let modeStr = newMode == .browse ? "browse" : "other"
            NotificationCenter.default.post(name: .paletteModeChanged, object: modeStr)
        }
        .onReceive(NotificationCenter.default.publisher(for: .paletteCommandsChanged)) { _ in
            gridRefreshID = UUID()
            if selectedIndex >= totalItems {
                selectedIndex = max(0, totalItems - 1)
            }
        }
        .onChange(of: mode) { _, _ in
            draggedCommandID = nil
            dropTargetCellID = nil
        }
    }

    private var browseView: some View {
        VStack(spacing: 0) {
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(groupedCommands.enumerated()), id: \.offset) { _, group in
                            VStack(alignment: .leading, spacing: 6) {
                                if let section = group.section {
                                    HStack(spacing: 10) {
                                        Text(section)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Rectangle()
                                            .fill(Color.white.opacity(0.08))
                                            .frame(height: 1)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.top, 2)
                                }

                                sectionGrid(for: group)
                            }
                        }

                        LazyVGrid(columns: gridColumns, spacing: 8) {
                            AddCommandCard(isSelected: selectedIndex == addCardIndex)
                                .id(addCardIndex)
                                .onTapGesture {
                                    mode = .adding
                                }
                        }
                    }
                    .id(gridRefreshID)
                    .padding(10)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    proxy.scrollTo(newValue)
                }
            }

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
                moveSelectionVertically(-1)
            case "down":
                moveSelectionVertically(1)
            default:
                break
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
        guard !displayedCommands.isEmpty, selectedIndex < displayedCommands.count else { return }
        let command = displayedCommands[selectedIndex]
        isRunning = true
        Task {
            do {
                let result = try await runner.run(command)
                await MainActor.run {
                    lastResult = shouldShowResult(result) ? result : nil
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

    @ViewBuilder
    private func sectionGrid(for group: (section: String?, commands: [Command])) -> some View {
        let cells = gridCells(for: group)
        let isDragging = draggedCommandID != nil

        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(cells) { cell in
                if let command = cell.command, let index = commandIndex(for: command) {
                    CommandCard(
                        command: command,
                        isSelected: index == selectedIndex,
                        isDropTarget: dropTargetCellID == cell.id,
                        isDragging: draggedCommandID == command.id
                    ) {
                        mode = .editing(command)
                    }
                    .id(index)
                    .onDrag {
                        draggedCommandID = command.id
                        dropTargetCellID = cell.id
                        return NSItemProvider(object: command.id as NSString)
                    } preview: {
                        CommandCard(command: command, isSelected: index == selectedIndex) {
                            mode = .editing(command)
                        }
                        .frame(width: 102)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        handleDrop(items: items, targetSection: cell.section, targetRow: cell.row, targetColumn: cell.column)
                    } isTargeted: { isTargeted in
                        updateDropTarget(isTargeted: isTargeted, cellID: cell.id)
                    }
                    .onTapGesture {
                        selectedIndex = index
                        runSelected()
                    }
                } else {
                    EmptyCommandCell(isDropTarget: dropTargetCellID == cell.id, isVisible: isDragging)
                        .dropDestination(for: String.self) { items, _ in
                            handleDrop(items: items, targetSection: cell.section, targetRow: cell.row, targetColumn: cell.column)
                        } isTargeted: { isTargeted in
                            updateDropTarget(isTargeted: isTargeted, cellID: cell.id)
                        }
                }
            }
        }
    }

    private func handleDrop(items: [String], targetSection: String?, targetRow: Int, targetColumn: Int) -> Bool {
        guard canReorder, let draggedCommandID = items.first else { return false }
        guard let draggedCommand = registry.commands.first(where: { $0.id == draggedCommandID }) else { return false }
        guard draggedCommand.normalizedSection != targetSection || draggedCommand.tileRow != targetRow || draggedCommand.tileColumn != targetColumn else {
            return false
        }

        do {
            try registry.placeCommand(id: draggedCommandID, in: targetSection, row: targetRow, column: targetColumn)
            self.draggedCommandID = nil
            dropTargetCellID = nil

            if let newIndex = displayedCommands.firstIndex(where: { $0.id == draggedCommandID }) {
                selectedIndex = newIndex
            }

            return true
        } catch {
            self.draggedCommandID = nil
            dropTargetCellID = nil
            return false
        }
    }

    private func gridCells(for group: (section: String?, commands: [Command])) -> [GridCell] {
        let sectionCommands = registry.commands
            .filter { $0.normalizedSection == group.section }
            .compactMap { command -> (command: Command, row: Int, column: Int)? in
                guard let position = command.normalizedTilePosition else { return nil }
                return (command, position.row, position.column)
            }

        let visibleCommands = group.commands
            .compactMap { command -> (command: Command, row: Int, column: Int)? in
                guard let position = command.normalizedTilePosition else { return nil }
                return (command, position.row, position.column)
            }

        let commandLookup = Dictionary(uniqueKeysWithValues: visibleCommands.map {
            (gridCellID(section: group.section, row: $0.row, column: $0.column), $0.command)
        })
        let maxRow = sectionCommands.map(\.row).max() ?? 0
        let minimumRows = max(1, Int(ceil(Double(max(sectionCommands.count, 1)) / Double(columns))))
        let rowCount = max(maxRow + (draggedCommandID == nil ? 1 : 2), minimumRows)

        return (0..<rowCount).flatMap { row in
            (0..<columns).map { column in
                let id = gridCellID(section: group.section, row: row, column: column)
                return GridCell(id: id, section: group.section, row: row, column: column, command: commandLookup[id])
            }
        }
    }

    private func updateDropTarget(isTargeted: Bool, cellID: String) {
        withAnimation(.easeInOut(duration: 0.12)) {
            dropTargetCellID = isTargeted ? cellID : (dropTargetCellID == cellID ? nil : dropTargetCellID)
        }
    }

    private func moveSelectionVertically(_ direction: Int) {
        guard let position = selectionPosition(for: selectedIndex) else { return }

        let targetRow = position.row + direction
        guard visibleRows.indices.contains(targetRow) else { return }

        let row = visibleRows[targetRow]
        selectedIndex = row[min(position.column, row.count - 1)]
    }

    private func shouldShowResult(_ result: CommandResult) -> Bool {
        if result.exitCode != 0 { return true }
        if !result.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func tilePosition(for command: Command) -> (row: Int, column: Int) {
        command.normalizedTilePosition ?? (Int.max, Int.max)
    }

    private func storageKey(for section: String?) -> String {
        section ?? "__default__"
    }

    private func gridCellID(section: String?, row: Int, column: Int) -> String {
        "\(storageKey(for: section)):\(row):\(column)"
    }
}

private struct GridCell: Identifiable {
    let id: String
    let section: String?
    let row: Int
    let column: Int
    let command: Command?
}

extension Notification.Name {
    static let paletteCommandsChanged = Notification.Name("paletteCommandsChanged")
}
