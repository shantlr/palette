import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel!
    private let hotkeyManager = HotkeyManager()
    private let screenBrushController = ScreenBrushController()
    let registry = CommandRegistry()
    let runner = CommandRunner()
    private var paletteHotkeyID: UUID?
    private var screenBrushHotkeyID: UUID?

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
        let brushItem = NSMenuItem(title: "Toggle Screen Brush", action: #selector(toggleScreenBrush), keyEquivalent: "6")
        brushItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(brushItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Panel
        let view = PaletteView(registry: registry, runner: runner) { [weak self] in
            self?.panel.close()
        }
        panel = OverlayPanel(contentView: view)

        // Global hotkey: Cmd + Shift + Space
        paletteHotkeyID = hotkeyManager.register { [weak self] in
            self?.panel.toggle()
        }

        // Global hotkey: Cmd + Shift + 6
        screenBrushHotkeyID = hotkeyManager.register(keyCode: 22) { [weak self] in
            self?.screenBrushController.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let paletteHotkeyID {
            hotkeyManager.unregister(paletteHotkeyID)
        }
        if let screenBrushHotkeyID {
            hotkeyManager.unregister(screenBrushHotkeyID)
        }
        registry.stopWatching()
    }

    @objc func togglePanel() {
        panel.toggle()
    }

    @objc func toggleScreenBrush() {
        screenBrushController.toggle()
    }
}
