# Palette — Mac Overlay Launcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that opens a Raycast-like overlay on a global hotkey, showing a searchable list of user-defined commands (bash scripts) that can be run instantly.

**Architecture:** Menu bar-only app (LSUIElement). Global hotkey via `CGEvent` tap registers a system-wide shortcut. Overlay is an `NSPanel` with `.nonactivatingPanel` style level so it floats above all windows without stealing focus. SwiftUI view inside the panel renders a search bar + filtered command list. Commands loaded from `~/.palette/commands.json`. Command execution via `Process` with stdout/stderr capture.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSPanel, CGEvent), Swift Package Manager (no external deps)

---

## Project Structure

```
Palette/
├── Package.swift
├── Sources/
│   └── Palette/
│       ├── PaletteApp.swift              # App entry, menu bar setup
│       ├── AppDelegate.swift             # NSApplicationDelegate, panel setup
│       ├── Hotkey/
│       │   └── HotkeyManager.swift       # Global hotkey via CGEvent tap
│       ├── Panel/
│       │   └── OverlayPanel.swift        # NSPanel subclass
│       ├── Views/
│       │   ├── PaletteView.swift         # Main overlay SwiftUI view
│       │   ├── CommandRow.swift          # Single command row
│       │   └── OutputView.swift          # Command output display
│       ├── Models/
│       │   ├── Command.swift             # Command model
│       │   └── CommandRegistry.swift     # Load/save commands.json
│       └── Runner/
│           └── CommandRunner.swift       # Execute bash via Process
├── Tests/
│   └── PaletteTests/
│       ├── CommandTests.swift
│       ├── CommandRegistryTests.swift
│       └── CommandRunnerTests.swift
└── docs/
    └── plans/
```

---

### Task 1: Swift Package + Bare App Entry

**Files:**
- Create: `Package.swift`
- Create: `Sources/Palette/PaletteApp.swift`
- Create: `Sources/Palette/AppDelegate.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Palette",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Palette",
            path: "Sources/Palette",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Palette/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "PaletteTests",
            dependencies: ["Palette"],
            path: "Tests/PaletteTests"
        ),
    ]
)
```

**Step 2: Create Info.plist (LSUIElement to hide dock icon)**

Create: `Sources/Palette/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>Palette</string>
    <key>CFBundleIdentifier</key>
    <string>dev.linp.palette</string>
</dict>
</plist>
```

**Step 3: Create AppDelegate.swift**

```swift
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Palette")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}
```

**Step 4: Create PaletteApp.swift**

```swift
import AppKit

@main
struct PaletteBootstrap {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
```

**Step 5: Build and run to verify menu bar icon appears**

Run: `cd /Users/patricklin/work/tools/palette && swift build 2>&1`
Expected: Build succeeds

Run: `swift run Palette &` then check menu bar for icon, then kill process.

**Step 6: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: scaffold Palette menu bar app with SPM"
```

---

### Task 2: Command Model + Registry

**Files:**
- Create: `Sources/Palette/Models/Command.swift`
- Create: `Sources/Palette/Models/CommandRegistry.swift`
- Create: `Tests/PaletteTests/CommandTests.swift`
- Create: `Tests/PaletteTests/CommandRegistryTests.swift`

**Step 1: Write Command model**

```swift
import Foundation

struct Command: Codable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let description: String
    let script: String           // bash script content or path
    let icon: String?            // SF Symbol name, optional
    let shortcut: String?        // e.g. "cmd+shift+t", optional

    enum CodingKeys: String, CodingKey {
        case name, description, script, icon, shortcut
    }
}
```

**Step 2: Write CommandRegistry**

```swift
import Foundation

@MainActor
final class CommandRegistry: ObservableObject {
    @Published var commands: [Command] = []

    private let configURL: URL

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
```

**Step 3: Write tests for Command model**

```swift
import Testing
import Foundation
@testable import Palette

@Test func commandDecodesFromJSON() throws {
    let json = """
    {
        "name": "Test",
        "description": "A test command",
        "script": "echo hello",
        "icon": "star",
        "shortcut": null
    }
    """.data(using: .utf8)!

    let command = try JSONDecoder().decode(Command.self, from: json)
    #expect(command.name == "Test")
    #expect(command.script == "echo hello")
    #expect(command.icon == "star")
    #expect(command.id == "Test")
}

@Test func commandEncodesRoundTrip() throws {
    let command = Command(name: "Foo", description: "Bar", script: "ls", icon: nil, shortcut: "cmd+f")
    let data = try JSONEncoder().encode(command)
    let decoded = try JSONDecoder().decode(Command.self, from: data)
    #expect(decoded.name == command.name)
    #expect(decoded.shortcut == "cmd+f")
}
```

**Step 4: Write tests for CommandRegistry**

```swift
import Testing
import Foundation
@testable import Palette

@Test func registryCreatesDefaultsWhenNoFile() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("commands.json")

    let registry = await CommandRegistry(configURL: tmp)
    try await registry.load()

    #expect(await registry.commands.count == 3)

    // Verify file was created
    #expect(FileManager.default.fileExists(atPath: tmp.path))

    // Cleanup
    try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent())
}

@Test func registryLoadsCustomCommands() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    let file = tmp.appendingPathComponent("commands.json")
    let json = """
    [{"name":"Custom","description":"Custom cmd","script":"whoami","icon":null,"shortcut":null}]
    """.data(using: .utf8)!
    try json.write(to: file)

    let registry = await CommandRegistry(configURL: file)
    try await registry.load()

    #expect(await registry.commands.count == 1)
    #expect(await registry.commands[0].name == "Custom")

    try? FileManager.default.removeItem(at: tmp)
}
```

**Step 5: Run tests**

Run: `cd /Users/patricklin/work/tools/palette && swift test 2>&1`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add Sources/Palette/Models/ Tests/PaletteTests/
git commit -m "feat: add Command model and CommandRegistry with JSON persistence"
```

---

### Task 3: CommandRunner — Execute Bash Scripts

**Files:**
- Create: `Sources/Palette/Runner/CommandRunner.swift`
- Create: `Tests/PaletteTests/CommandRunnerTests.swift`

**Step 1: Write CommandRunner**

```swift
import Foundation

struct CommandResult: Sendable {
    let output: String
    let error: String
    let exitCode: Int32
}

final class CommandRunner: Sendable {
    func run(_ command: Command) async throws -> CommandResult {
        try await run(script: command.script)
    }

    func run(script: String) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", script]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

                    let result = CommandResult(
                        output: String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        error: String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        exitCode: process.terminationStatus
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

**Step 2: Write tests**

```swift
import Testing
import Foundation
@testable import Palette

@Test func runnerExecutesSimpleCommand() async throws {
    let runner = CommandRunner()
    let result = try await runner.run(script: "echo hello")
    #expect(result.output == "hello")
    #expect(result.exitCode == 0)
}

@Test func runnerCapturesStderr() async throws {
    let runner = CommandRunner()
    let result = try await runner.run(script: "echo error >&2")
    #expect(result.error == "error")
    #expect(result.exitCode == 0)
}

@Test func runnerReportsNonZeroExit() async throws {
    let runner = CommandRunner()
    let result = try await runner.run(script: "exit 42")
    #expect(result.exitCode == 42)
}

@Test func runnerExecutesCommand() async throws {
    let runner = CommandRunner()
    let cmd = Command(name: "Test", description: "test", script: "echo palette", icon: nil, shortcut: nil)
    let result = try await runner.run(cmd)
    #expect(result.output == "palette")
}
```

**Step 3: Run tests**

Run: `cd /Users/patricklin/work/tools/palette && swift test 2>&1`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add Sources/Palette/Runner/ Tests/PaletteTests/CommandRunnerTests.swift
git commit -m "feat: add CommandRunner for bash script execution"
```

---

### Task 4: Overlay Panel (NSPanel)

**Files:**
- Create: `Sources/Palette/Panel/OverlayPanel.swift`
- Modify: `Sources/Palette/AppDelegate.swift`

**Step 1: Create OverlayPanel**

```swift
import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.animationBehavior = .utilityWindow
        self.backgroundColor = .clear
        self.hasShadow = true

        // Rounded corners
        self.isOpaque = false
        self.contentView = NSHostingView(rootView:
            contentView
                .frame(width: 680, height: 420)
                .background(VisualEffectView())
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )

        centerOnScreen()
    }

    func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2 + 100 // slightly above center
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            centerOnScreen()
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Close on escape
    override func cancelOperation(_ sender: Any?) {
        close()
    }

    // Close when clicking outside
    override func resignKey() {
        super.resignKey()
        close()
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
```

**Step 2: Update AppDelegate to create panel**

```swift
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel!
    let registry = CommandRegistry()
    let runner = CommandRunner()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load commands
        try? registry.load()

        // Menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Palette")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Palette", action: #selector(togglePanel), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Panel
        let view = PaletteView(registry: registry, runner: runner) {
            self.panel.close()
        }
        panel = OverlayPanel(contentView: view)
    }

    @objc func togglePanel() {
        panel.toggle()
    }
}
```

**Step 3: Build to verify**

Run: `cd /Users/patricklin/work/tools/palette && swift build 2>&1`
Expected: Build succeeds (PaletteView created in next task — use placeholder for now)

**Step 4: Commit**

```bash
git add Sources/Palette/Panel/ Sources/Palette/AppDelegate.swift
git commit -m "feat: add OverlayPanel with vibrancy and auto-dismiss"
```

---

### Task 5: SwiftUI Views — PaletteView, CommandRow, OutputView

**Files:**
- Create: `Sources/Palette/Views/PaletteView.swift`
- Create: `Sources/Palette/Views/CommandRow.swift`
- Create: `Sources/Palette/Views/OutputView.swift`

**Step 1: Create CommandRow**

```swift
import SwiftUI

struct CommandRow: View {
    let command: Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.icon ?? "terminal")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.body.weight(.medium))
                Text(command.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}
```

**Step 2: Create OutputView**

```swift
import SwiftUI

struct OutputView: View {
    let result: CommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(result.exitCode == 0 ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("exit \(result.exitCode)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(result.output.isEmpty ? result.error : result.output)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .padding(8)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
    }
}
```

**Step 3: Create PaletteView**

```swift
import SwiftUI

struct PaletteView: View {
    @ObservedObject var registry: CommandRegistry
    let runner: CommandRunner
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var lastResult: CommandResult?
    @State private var isRunning = false

    var filteredCommands: [Command] {
        if searchText.isEmpty { return registry.commands }
        return registry.commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit { runSelected() }

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(16)

            Divider()

            // Command list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandRow(command: command, isSelected: index == selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    runSelected()
                                }
                        }
                    }
                    .padding(.vertical, 8)
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
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
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
```

**Step 4: Build and verify**

Run: `cd /Users/patricklin/work/tools/palette && swift build 2>&1`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Sources/Palette/Views/
git commit -m "feat: add SwiftUI views — PaletteView, CommandRow, OutputView"
```

---

### Task 6: Global Hotkey Manager

**Files:**
- Create: `Sources/Palette/Hotkey/HotkeyManager.swift`
- Modify: `Sources/Palette/AppDelegate.swift`

**Step 1: Create HotkeyManager using CGEvent tap**

```swift
import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var callback: (() -> Void)?

    // Default: ⌥ + Space (Option + Space)
    func register(modifiers: CGEventFlags = .maskAlternate, keyCode: CGKeyCode = 49, action: @escaping () -> Void) {
        self.callback = action

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Need to capture `self` pointer for C callback
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .keyDown {
                    let flags = event.flags
                    let code = event.getIntegerValueField(.keyboardEventKeycode)

                    // Check Option + Space (modifier: 0x80000, keycode: 49)
                    if flags.contains(.maskAlternate) && code == 49 {
                        DispatchQueue.main.async {
                            manager.callback?()
                        }
                        return nil // consume event
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            print("⚠️ Failed to create event tap. Grant Accessibility permission in System Settings > Privacy & Security > Accessibility.")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit {
        // Cleanup handled by MainActor
    }
}
```

**Step 2: Update AppDelegate to wire up hotkey**

Replace full `AppDelegate.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel!
    private let hotkeyManager = HotkeyManager()
    let registry = CommandRegistry()
    let runner = CommandRunner()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load commands
        try? registry.load()

        // Menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Palette")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Palette", action: #selector(togglePanel), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Panel
        let view = PaletteView(registry: registry, runner: runner) { [weak self] in
            self?.panel.close()
        }
        panel = OverlayPanel(contentView: view)

        // Global hotkey: Option + Space
        hotkeyManager.register { [weak self] in
            self?.panel.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    @objc func togglePanel() {
        panel.toggle()
    }
}
```

**Step 3: Build and verify**

Run: `cd /Users/patricklin/work/tools/palette && swift build 2>&1`
Expected: Build succeeds

**Step 4: Manual test**

Run: `swift run Palette`
1. Verify menu bar icon appears
2. Press Option+Space → overlay should appear
3. Type to filter commands
4. Press Enter to run command, see output
5. Press Escape or click outside to dismiss
6. Quit from menu bar

**Step 5: Commit**

```bash
git add Sources/Palette/Hotkey/ Sources/Palette/AppDelegate.swift
git commit -m "feat: add global hotkey manager (Option+Space) to toggle overlay"
```

---

### Task 7: Polish + Reset State on Open

**Files:**
- Modify: `Sources/Palette/Views/PaletteView.swift`
- Modify: `Sources/Palette/Panel/OverlayPanel.swift`
- Modify: `Sources/Palette/AppDelegate.swift`

**Step 1: Add reset on panel open**

In `OverlayPanel.swift`, add notification when panel opens:

```swift
// Add to toggle() method, in the else branch, before makeKeyAndOrderFront:
NotificationCenter.default.post(name: .paletteWillOpen, object: nil)
```

Add extension:
```swift
extension Notification.Name {
    static let paletteWillOpen = Notification.Name("paletteWillOpen")
}
```

**Step 2: Reset search state in PaletteView when panel opens**

Add to PaletteView body modifiers:

```swift
.onReceive(NotificationCenter.default.publisher(for: .paletteWillOpen)) { _ in
    searchText = ""
    selectedIndex = 0
    lastResult = nil
}
```

**Step 3: Build and test**

Run: `cd /Users/patricklin/work/tools/palette && swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/Palette/
git commit -m "feat: reset search state when overlay opens"
```

---

### Task 8: commands.json Schema + Example Config

**Files:**
- Create: `examples/commands.json`

**Step 1: Create example commands.json**

```json
[
    {
        "name": "IP Address",
        "description": "Show local and public IP",
        "script": "echo \"Local: $(ipconfig getifaddr en0)\nPublic: $(curl -s ifconfig.me)\"",
        "icon": "network",
        "shortcut": null
    },
    {
        "name": "Git Status",
        "description": "Show git status of current directory",
        "script": "cd ~ && git status 2>/dev/null || echo 'Not a git repo'",
        "icon": "arrow.triangle.branch",
        "shortcut": null
    },
    {
        "name": "Top Processes",
        "description": "Show top 5 CPU-consuming processes",
        "script": "ps aux | sort -nrk 3,3 | head -5 | awk '{printf \"%-6s %-4s%% %s\\n\", $2, $3, $11}'",
        "icon": "cpu",
        "shortcut": null
    },
    {
        "name": "Empty Trash",
        "description": "Empty the macOS trash",
        "script": "rm -rf ~/.Trash/* && echo 'Trash emptied'",
        "icon": "trash",
        "shortcut": null
    },
    {
        "name": "Lock Screen",
        "description": "Lock the screen immediately",
        "script": "pmset displaysleepnow",
        "icon": "lock",
        "shortcut": null
    }
]
```

**Step 2: Commit**

```bash
git add examples/
git commit -m "docs: add example commands.json"
```

---

## Summary

| Task | What | Est. Time |
|------|------|-----------|
| 1 | SPM scaffold + menu bar app | 5 min |
| 2 | Command model + registry + tests | 10 min |
| 3 | CommandRunner + tests | 5 min |
| 4 | OverlayPanel (NSPanel) | 5 min |
| 5 | SwiftUI views | 10 min |
| 6 | Global hotkey manager | 10 min |
| 7 | Polish — reset state on open | 5 min |
| 8 | Example config | 2 min |

**Total: ~52 min, 8 commits, 0 external deps**

**Accessibility Note:** The global hotkey requires the app to be granted Accessibility permission in System Settings > Privacy & Security > Accessibility. On first run, macOS will prompt for this.
