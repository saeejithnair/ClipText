import Cocoa
import Carbon.HIToolbox
import AppKit

final class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var lastTriggerTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 1.0 // Prevent triggers within 1 second
    var onHotkeyTriggered: (() -> Void)?
    
    init() {
        print("HotkeyManager: Initializing...")
        registerHotkey()
    }
    
    deinit {
        print("HotkeyManager: Cleaning up...")
        unregisterHotkey()
    }
    
    // Static callback for Carbon event
    private static let hotKeyCallback: EventHandlerUPP = { (nextHandler, eventRef, userData) -> OSStatus in
        guard let eventRef = eventRef,
              let userData = userData else {
            return OSStatus(eventNotHandledErr)
        }
        
        // Get back our Swift object
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        print("HotkeyManager: Event received")
        
        // Check debounce
        let now = Date()
        if now.timeIntervalSince(manager.lastTriggerTime) < manager.debounceInterval {
            print("HotkeyManager: Ignoring event due to debounce")
            return noErr
        }
        manager.lastTriggerTime = now
        
        // Verify it's our hotkey
        var hotKeyID = EventHotKeyID()
        let error = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard error == noErr else {
            print("HotkeyManager: Error getting event parameter: \(error)")
            return error
        }
        
        if hotKeyID.id == 1 {
            print("HotkeyManager: Hotkey match confirmed")
            DispatchQueue.main.async {
                manager.onHotkeyTriggered?()
            }
            return noErr
        }
        
        return CallNextEventHandler(nextHandler, eventRef)
    }
    
    private func registerHotkey() {
        print("HotkeyManager: Setting up event handler...")
        
        // Define event type for hotkey events
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Create a unique ID for our hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.id = 1
        hotKeyID.signature = OSType(0x434C4950) // "CLIP" in hex
        
        // Create a context to pass to the callback
        let context = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        
        // Install event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyCallback,
            1,
            &eventType,
            context,
            &eventHandler
        )
        
        if status == noErr {
            print("HotkeyManager: Event handler installed successfully")
            
            // Register the hotkey
            let registerStatus = RegisterEventHotKey(
                UInt32(kVK_ANSI_9),  // Virtual keycode for '9'
                UInt32(controlKey | shiftKey),
                hotKeyID,
                GetApplicationEventTarget(),
                OptionBits(0),
                &hotKeyRef
            )
            
            if registerStatus == noErr {
                print("HotkeyManager: Hotkey registered successfully")
            } else {
                print("HotkeyManager: Failed to register hotkey, status: \(registerStatus)")
            }
        } else {
            print("HotkeyManager: Failed to install event handler, status: \(status)")
        }
    }
    
    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            print("HotkeyManager: Unregistered hotkey with status: \(status)")
            self.hotKeyRef = nil
        }
        
        if let handler = eventHandler {
            let status = RemoveEventHandler(handler)
            print("HotkeyManager: Removed event handler with status: \(status)")
            eventHandler = nil
        }
    }
    
    static let shared = HotkeyManager()
} 
