import Foundation

final class ResourceManager {
    static let shared = ResourceManager()

    private var resources: [Resource] = []

    private init() {}

    enum Resource {
        case window(NSWindow)
        case eventMonitor(Any)
    }

    func track(_ resource: Resource) {
        resources.append(resource)
    }

    func releaseAll() {
        for resource in resources {
            switch resource {
            case .window(let window):
                window.close()
            case .eventMonitor(let monitor):
                NSEvent.removeMonitor(monitor)
            }
        }
        resources.removeAll()
    }
}