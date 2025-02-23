import Cocoa
import Carbon.HIToolbox

final class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var lastTriggerTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 1.0
    var onHotkeyTriggered: (() -> Void)?

    init() {
        registerHotkey()
    }

    deinit {
        unregisterHotkey()
    }

    private func registerHotkey() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &eventType, context, &eventHandler)
        if status != noErr {
            print("Failed to install event handler: \(status)")
            return
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.id = 1
        hotKeyID.signature = OSType(0x434C4950) // "CLIP"

        let registerStatus = RegisterEventHotKey(UInt32(kVK_ANSI_9), UInt32(controlKey | shiftKey), hotKeyID, GetApplicationEventTarget(), OptionBits(0), &hotKeyRef)
        if registerStatus != noErr {
            print("Failed to register hotkey: \(registerStatus)")
        }
    }

    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    private let hotKeyCallback: EventHandlerUPP = { (nextHandler, eventRef, userData) -> OSStatus in
        guard let eventRef = eventRef,
              let userData = userData else {
            return OSStatus(eventNotHandledErr)
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        let now = Date()
        if now.timeIntervalSince(manager.lastTriggerTime) < manager.debounceInterval {
            return noErr
        }
        manager.lastTriggerTime = now

        var hotKeyID = EventHotKeyID()
        let error = GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        if error == noErr && hotKeyID.id == 1 {
            DispatchQueue.main.async {
                manager.onHotkeyTriggered?()
            }
            return noErr
        }
        return CallNextEventHandler(nextHandler, eventRef)
    }
}

extension HotkeyManager {
    static let shared = HotkeyManager()
}