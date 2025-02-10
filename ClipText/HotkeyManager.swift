import Cocoa
import Carbon.HIToolbox

class HotkeyManager {
    var onHotkeyTriggered: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    
    init() {
        registerHotkey()
    }
    
    deinit {
        unregisterHotkey()
    }
    
    private func registerHotkey() {
        // Define the hotkey (Control + Shift + 9)
        var keyID = EventHotKeyID()
        keyID.signature = OSType("CLIP".utf8.reduce(0) { ($0 << 8) + UInt32($1) })
        keyID.id = UInt32(0)
        
        // Create the event type spec
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install event handler
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, eventRef, userData) -> OSStatus in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                manager.hotkeyPressed()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
        
        guard status == noErr else {
            print("Failed to install event handler")
            return
        }
        
        // Register the hotkey
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(25),  // Virtual keycode for '9'
            UInt32(controlKey | shiftKey), // Modifiers
            keyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        guard hotKeyStatus == noErr else {
            print("Failed to register hotkey")
            return
        }
    }
    
    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
    
    @objc private func hotkeyPressed() {
        DispatchQueue.main.async { [weak self] in
            self?.onHotkeyTriggered?()
        }
    }
} 