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
        try? registry.startWatching()

        // Menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Palette")
        }

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle Palette", action: #selector(togglePanel), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Panel
        let view = PaletteView(registry: registry, runner: runner) { [weak self] in
            self?.panel.close()
        }
        panel = OverlayPanel(contentView: view)

        // Global hotkey: Cmd + Shift + Space
        hotkeyManager.register { [weak self] in
            self?.panel.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        registry.stopWatching()
    }

    @objc func togglePanel() {
        panel.toggle()
    }
}
