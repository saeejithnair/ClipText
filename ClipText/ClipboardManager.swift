import AppKit

protocol ClipboardManagerProtocol {
    func copyToClipboard(_ text: String)
}

final class ClipboardManager: ClipboardManagerProtocol {
    static let shared = ClipboardManager()
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    func copyToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
} 