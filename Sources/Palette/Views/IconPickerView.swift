import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.fixed(44), spacing: 6), count: 8)

    private var filteredIcons: [String] {
        if searchText.isEmpty { return Self.commonIcons }
        return Self.commonIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search icons...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }
            .padding(8)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filteredIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.body)
                                .frame(width: 36, height: 36)
                                .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 380, height: 280)
    }

    // Curated list of useful SF Symbols
    static let commonIcons: [String] = [
        // General
        "terminal", "command", "apple.terminal", "chevron.left.forwardslash.chevron.right",
        "curlybraces", "number", "textformat", "doc", "doc.text", "doc.plaintext",

        // Actions
        "play", "play.fill", "pause", "stop", "forward", "backward",
        "arrow.clockwise", "arrow.counterclockwise", "arrow.up.arrow.down",
        "arrow.left.arrow.right", "arrow.triangle.branch", "arrow.triangle.merge",

        // System
        "gear", "gearshape", "gearshape.2", "wrench", "wrench.and.screwdriver",
        "hammer", "screwdriver", "cpu", "memorychip", "internaldrive",
        "externaldrive", "server.rack", "desktopcomputer", "laptopcomputer",

        // Network
        "network", "wifi", "globe", "antenna.radiowaves.left.and.right",
        "icloud", "icloud.and.arrow.up", "icloud.and.arrow.down",
        "link", "personalhotspot",

        // Files & Folders
        "folder", "folder.fill", "folder.badge.plus", "folder.badge.gear",
        "trash", "trash.fill", "archivebox", "tray", "tray.full",
        "doc.on.doc", "doc.on.clipboard", "clipboard",

        // Communication
        "envelope", "envelope.fill", "message", "message.fill",
        "bubble.left", "bubble.right", "phone", "video",

        // Media
        "photo", "camera", "film", "music.note", "music.note.list",
        "speaker.wave.2", "mic", "headphones",

        // Security
        "lock", "lock.fill", "lock.open", "key", "key.fill",
        "shield", "shield.fill", "shield.checkered",

        // Status
        "checkmark", "checkmark.circle", "checkmark.circle.fill",
        "xmark", "xmark.circle", "xmark.circle.fill",
        "exclamationmark.triangle", "exclamationmark.circle",
        "info.circle", "questionmark.circle",

        // Navigation
        "magnifyingglass", "binoculars", "scope", "location",
        "map", "mappin", "compass.drawing",

        // Time
        "clock", "clock.fill", "timer", "stopwatch",
        "calendar", "calendar.badge.clock",

        // People
        "person", "person.fill", "person.2", "person.3",
        "hand.wave", "hand.raised", "hand.thumbsup", "hand.thumbsdown",

        // Nature
        "sun.max", "moon", "cloud", "cloud.rain", "bolt",
        "flame", "drop", "leaf", "tree",

        // Shapes
        "star", "star.fill", "heart", "heart.fill",
        "flag", "flag.fill", "tag", "tag.fill",
        "bookmark", "bookmark.fill", "pin", "pin.fill",

        // Math & Data
        "chart.bar", "chart.line.uptrend.xyaxis", "chart.pie",
        "function", "sum", "percent", "number.circle",

        // Misc
        "lightbulb", "bolt.fill", "battery.100", "powercord",
        "paperplane", "paperplane.fill", "gift", "cart",
        "bag", "creditcard", "banknote", "dollarsign.circle",
        "paintbrush", "paintpalette", "eyedropper",
        "wand.and.stars", "sparkles", "ant", "ladybug",
        "puzzlepiece", "dice", "gamecontroller",
        "bell", "bell.fill", "alarm", "alarm.fill",
        "plus", "minus", "plus.circle", "minus.circle",
    ]
}
