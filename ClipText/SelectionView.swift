import Cocoa

final class SelectionView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    
    private var selectionRect: NSRect?
    private var startPoint: NSPoint?
    private var isSelecting = false
    private var dimView: NSView?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Create dimming view
        let dim = NSView(frame: bounds)
        dim.wantsLayer = true
        dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        addSubview(dim)
        self.dimView = dim
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        isSelecting = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        
        let current = convert(event.locationInWindow, from: nil)
        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        selectionRect = rect
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isSelecting = false
        
        if let rect = selectionRect, rect.width > 1 && rect.height > 1 {
            onSelectionComplete?(rect)
        }
        
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Update dimming view frame
        dimView?.frame = bounds
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        if let rect = selectionRect {
            // Clear the selection area in the dim view
            dimView?.layer?.mask = createMaskLayer(for: rect)
            
            // Draw selection rectangle border
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1.0)
            context.stroke(rect)
            
            // Draw selection guides
            drawGuides(in: context, for: rect)
        }
    }
    
    private func createMaskLayer(for rect: NSRect) -> CALayer {
        let maskLayer = CALayer()
        maskLayer.frame = bounds
        maskLayer.backgroundColor = NSColor.black.cgColor
        
        let holeLayer = CALayer()
        holeLayer.frame = rect
        holeLayer.backgroundColor = NSColor.clear.cgColor
        
        maskLayer.addSublayer(holeLayer)
        return maskLayer
    }
    
    private func drawGuides(in context: CGContext, for rect: NSRect) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [5, 5])
        
        // Horizontal guides
        context.move(to: CGPoint(x: 0, y: rect.minY))
        context.addLine(to: CGPoint(x: bounds.width, y: rect.minY))
        context.move(to: CGPoint(x: 0, y: rect.maxY))
        context.addLine(to: CGPoint(x: bounds.width, y: rect.maxY))
        
        // Vertical guides
        context.move(to: CGPoint(x: rect.minX, y: 0))
        context.addLine(to: CGPoint(x: rect.minX, y: bounds.height))
        context.move(to: CGPoint(x: rect.maxX, y: 0))
        context.addLine(to: CGPoint(x: rect.maxX, y: bounds.height))
        
        context.strokePath()
    }
} 