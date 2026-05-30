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

    private var localMonitor: Any?
    private var modeObserver: Any?
    var isBrowseMode: Bool = true

    func installKeyMonitor() {
        modeObserver = NotificationCenter.default.addObserver(forName: .paletteModeChanged, object: nil, queue: .main) { [weak self] note in
            let isBrowse = (note.object as? String) == "browse"
            MainActor.assumeIsolated {
                self?.isBrowseMode = isBrowse
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isKeyWindow else { return event }

            let keyCode = Int(event.keyCode)

            // Escape always handled — goes back or dismisses
            if keyCode == 53 {
                NotificationCenter.default.post(name: .paletteEscapeKey, object: nil)
                return nil
            }

            // Arrow keys and Return only consumed in browse mode
            guard self.isBrowseMode else { return event }

            switch keyCode {
            case 126: // up
                NotificationCenter.default.post(name: .paletteArrowKey, object: "up")
                return nil
            case 125: // down
                NotificationCenter.default.post(name: .paletteArrowKey, object: "down")
                return nil
            case 123: // left
                NotificationCenter.default.post(name: .paletteArrowKey, object: "left")
                return nil
            case 124: // right
                NotificationCenter.default.post(name: .paletteArrowKey, object: "right")
                return nil
            case 36: // return
                NotificationCenter.default.post(name: .paletteEnterKey, object: nil)
                return nil
            default:
                return event
            }
        }
    }

    func removeKeyMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let observer = modeObserver {
            NotificationCenter.default.removeObserver(observer)
            modeObserver = nil
        }
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            NotificationCenter.default.post(name: .paletteWillOpen, object: nil)
            centerOnScreen()
            installKeyMonitor()
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    override func close() {
        removeKeyMonitor()
        super.close()
    }

    // Close when clicking outside
    override func resignKey() {
        super.resignKey()
        close()
    }
}

extension Notification.Name {
    static let paletteWillOpen = Notification.Name("paletteWillOpen")
    static let paletteArrowKey = Notification.Name("paletteArrowKey")
    static let paletteEnterKey = Notification.Name("paletteEnterKey")
    static let paletteEscapeKey = Notification.Name("paletteEscapeKey")
    static let paletteModeChanged = Notification.Name("paletteModeChanged")
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
