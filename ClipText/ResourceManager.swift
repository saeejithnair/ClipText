import Foundation
import AppKit
import ScreenCaptureKit

/// Singleton responsible for managing and cleaning up all system resources
final class ResourceManager {
    static let shared = ResourceManager()
    private var activeResources: Set<Resource> = []
    private let queue = DispatchQueue(label: "com.snair.cliptext.resources")
    
    private init() {}
    
    enum Resource: Hashable {
        case eventMonitor(Any)
        case window(NSWindow)
        case stream(SCStream)
        case timer(Timer)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .eventMonitor(let monitor):
                hasher.combine(ObjectIdentifier(monitor as AnyObject))
            case .window(let window):
                hasher.combine(ObjectIdentifier(window))
            case .stream(let stream):
                hasher.combine(ObjectIdentifier(stream))
            case .timer(let timer):
                hasher.combine(ObjectIdentifier(timer))
            }
        }
        
        static func == (lhs: Resource, rhs: Resource) -> Bool {
            switch (lhs, rhs) {
            case (.eventMonitor(let l), .eventMonitor(let r)):
                return ObjectIdentifier(l as AnyObject) == ObjectIdentifier(r as AnyObject)
            case (.window(let l), .window(let r)):
                return ObjectIdentifier(l) == ObjectIdentifier(r)
            case (.stream(let l), .stream(let r)):
                return ObjectIdentifier(l) == ObjectIdentifier(r)
            case (.timer(let l), .timer(let r)):
                return ObjectIdentifier(l) == ObjectIdentifier(r)
            default:
                return false
            }
        }
    }
    
    func track(_ resource: Resource) {
        queue.async {
            self.activeResources.insert(resource)
        }
    }
    
    func release(_ resource: Resource) {
        queue.async {
            self.activeResources.remove(resource)
            self.cleanup(resource)
        }
    }
    
    func releaseAll() {
        queue.async {
            let resources = self.activeResources
            self.activeResources.removeAll()
            resources.forEach(self.cleanup)
        }
    }
    
    private func cleanup(_ resource: Resource) {
        switch resource {
        case .eventMonitor(let monitor):
            NSEvent.removeMonitor(monitor)
        case .window(let window):
            window.orderOut(nil)
        case .stream(let stream):
            Task {
                try? await stream.stopCapture()
            }
        case .timer(let timer):
            timer.invalidate()
        }
    }
    
    deinit {
        releaseAll()
    }
} 