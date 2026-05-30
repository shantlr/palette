import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var callback: (() -> Void)?

    // Default: ⌘ + ⇧ + Space (Cmd + Shift + Space)
    func register(modifiers: CGEventFlags = [.maskCommand, .maskShift], keyCode: CGKeyCode = 49, action: @escaping () -> Void) {
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

                    // Check Cmd + Shift + Space
                    if flags.contains(.maskCommand) && flags.contains(.maskShift) && code == 49 {
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
