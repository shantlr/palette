import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private struct Registration {
        let modifiers: CGEventFlags
        let keyCode: CGKeyCode
        let action: () -> Void
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var registrations: [UUID: Registration] = [:]

    // Default: ⌘ + ⇧ + Space (Cmd + Shift + Space)
    @discardableResult
    func register(modifiers: CGEventFlags = [.maskCommand, .maskShift], keyCode: CGKeyCode = 49, action: @escaping () -> Void) -> UUID {
        let id = UUID()
        registrations[id] = Registration(modifiers: normalize(modifiers), keyCode: keyCode, action: action)

        guard eventTap == nil else { return id }

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
                    let flags = manager.normalize(event.flags)
                    let code = event.getIntegerValueField(.keyboardEventKeycode)

                    if let registration = manager.registrations.values.first(where: {
                        $0.keyCode == code && $0.modifiers == flags
                    }) {
                        DispatchQueue.main.async {
                            registration.action()
                        }
                        return nil // consume event
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            print("⚠️ Failed to create event tap. Grant Accessibility permission in System Settings > Privacy & Security > Accessibility.")
            registrations.removeValue(forKey: id)
            return id
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return id
    }

    func unregister(_ id: UUID) {
        registrations.removeValue(forKey: id)
        if registrations.isEmpty {
            tearDownEventTap()
        }
    }

    func unregisterAll() {
        registrations.removeAll()
        tearDownEventTap()
    }

    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func normalize(_ flags: CGEventFlags) -> CGEventFlags {
        let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        return flags.intersection(relevantFlags)
    }

    deinit {
        // Cleanup handled by MainActor
    }
}
