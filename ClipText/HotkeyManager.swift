import Cocoa
import Carbon

class HotkeyManager {
    private var eventMonitor: Any?
    var onHotkeyTriggered: (() -> Void)?
    
    init() {
        setupHotkeyMonitor()
    }
    
    private func setupHotkeyMonitor() {
        // Monitor for key down events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            // Check for Control+Shift+9
            if event.modifierFlags.contains([.control, .shift]) &&
               event.keyCode == 25 { // 25 is the keycode for '9'
                DispatchQueue.main.async {
                    self?.onHotkeyTriggered?()
                }
            }
        }
        
        // Also monitor for local key events (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.modifierFlags.contains([.control, .shift]) &&
               event.keyCode == 25 {
                DispatchQueue.main.async {
                    self?.onHotkeyTriggered?()
                }
                return nil // Consume the event
            }
            return event
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
} 