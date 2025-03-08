import Cocoa

final class SelectionView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    private var startPoint: NSPoint?
    private var currentRect: NSRect?

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let rect = currentRect, rect.width > 1 && rect.height > 1 {
            onSelectionComplete?(rect)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Dimmed overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        if let rect = currentRect {
            // Clear selected region
            NSColor.clear.setFill()
            rect.fill()
            // Draw white border
            NSColor.white.setStroke()
            NSBezierPath(rect: rect).stroke()
        }
    }
}