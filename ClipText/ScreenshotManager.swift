import Cocoa
import ScreenCaptureKit

class ScreenshotManager: NSObject {
    private var overlayWindow: NSWindow?
    private var selectionView: SelectionView?
    private var completion: ((NSImage?) -> Void)?
    private var stream: SCStream?
    
    override init() {
        super.init()
        // Print bundle ID and ensure it matches Info.plist
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        print("Bundle identifier: \(bundleId)")
        if bundleId != "com.snair.cliptext" {
            print("Warning: Bundle identifier mismatch. Expected 'com.snair.cliptext' but got '\(bundleId)'")
        }
    }
    
    func captureRegion(completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        
        Task {
            do {
                // First check if we have screen recording permission
                let authorized = await checkScreenRecordingPermission()
                if authorized {
                    print("Screen recording permission granted")
                    await MainActor.run {
                        self.showOverlayWindow()
                    }
                } else {
                    print("Screen recording permission not granted")
                    await MainActor.run {
                        self.requestScreenRecordingPermission()
                    }
                }
            } catch {
                print("Error checking permissions: \(error)")
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }
    
    private func checkScreenRecordingPermission() async -> Bool {
        do {
            // Try to get the shareable content
            let content = try await SCShareableContent.current
            
            // If we get here without an error, we have permission
            print("Successfully got shareable content")
            print("Available displays: \(content.displays.count)")
            print("Available windows: \(content.windows.count)")
            return true
        } catch {
            print("Error getting shareable content: \(error)")
            let nsError = error as NSError
            print("Error domain: \(nsError.domain)")
            print("Error code: \(nsError.code)")
            print("Error description: \(nsError.localizedDescription)")
            print("Error user info: \(nsError.userInfo)")
            return false
        }
    }
    
    private func requestScreenRecordingPermission() {
        print("Requesting screen recording permission")
        
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "ClipText needs screen recording permission to capture text from your screen. Please enable it in System Settings > Privacy & Security > Screen Recording, then restart the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
    
    private func showOverlayWindow() {
        print("Showing overlay window")
        // Hide the app's main window if it exists
        NSApplication.shared.windows.forEach { window in
            if window.title == "ClipText" {
                window.orderOut(nil)
            }
        }
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver // Higher level to ensure it's above other windows
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        
        let selectionView = SelectionView()
        selectionView.onSelectionComplete = { [weak self] rect in
            self?.captureSelectedRegion(rect)
            self?.overlayWindow?.orderOut(nil)
            self?.overlayWindow = nil
        }
        
        window.contentView = selectionView
        self.selectionView = selectionView
        self.overlayWindow = window
        
        // Ensure we're the key window and front-most
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Register escape key to cancel
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.overlayWindow?.orderOut(nil)
                self?.overlayWindow = nil
                return nil
            }
            return event
        }
    }
    
    private func captureSelectedRegion(_ rect: NSRect) {
        print("Capturing selected region: \(rect)")
        Task {
            do {
                // Get the main display
                let content = try await SCShareableContent.current
                guard let mainDisplay = content.displays.first else {
                    print("No display found")
                    completion?(nil)
                    return
                }
                
                print("Found main display: \(mainDisplay)")
                
                // Convert rect to screen coordinates
                let screen = NSScreen.main ?? NSScreen.screens[0]
                let flippedRect = CGRect(
                    x: rect.minX,
                    y: screen.frame.height - rect.maxY,
                    width: rect.width,
                    height: rect.height
                )
                
                print("Converted to flipped rect: \(flippedRect)")
                
                // Create filter for the region
                let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
                
                // Configure stream configuration
                let configuration = SCStreamConfiguration()
                configuration.width = Int(rect.width)
                configuration.height = Int(rect.height)
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                configuration.queueDepth = 1
                configuration.sourceRect = flippedRect
                configuration.showsCursor = false
                
                print("Created stream configuration")
                
                // Create and start the stream
                let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                self.stream = stream
                
                print("Created stream")
                
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                try await stream.startCapture()
                
                print("Started capture")
                
            } catch {
                print("Capture error: \(error)")
                let nsError = error as NSError
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error user info: \(nsError.userInfo)")
                DispatchQueue.main.async { [weak self] in
                    self?.completion?(nil)
                    self?.showError(error)
                }
            }
        }
    }
    
    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private func cleanup() {
        Task {
            if let stream = stream {
                try? await stream.stopCapture()
                self.stream = nil
            }
        }
    }
    
    deinit {
        cleanup()
    }
}

extension ScreenshotManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.completion?(nil)
            self?.showError(error)
        }
    }
}

extension ScreenshotManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        DispatchQueue.main.async { [weak self] in
            self?.completion?(image)
            self?.cleanup()
        }
    }
}

class SelectionView: NSView {
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var instructionLabel: NSTextField?
    private var loadingIndicator: NSProgressIndicator?
    var onSelectionComplete: ((NSRect) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        
        // Add instruction label
        let label = NSTextField(labelWithString: "Drag to select an area. Press Esc to cancel.")
        label.textColor = .white
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 20)
        ])
        
        instructionLabel = label
        
        // Add loading indicator (initially hidden)
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.isIndeterminate = true
        indicator.isHidden = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        loadingIndicator = indicator
        
        // Set cursor
        NSCursor.crosshair.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentRect = nil
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = event.locationInWindow
        
        currentRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width > 1, rect.height > 1 else { return }
        
        // Show loading indicator
        instructionLabel?.isHidden = true
        loadingIndicator?.isHidden = false
        loadingIndicator?.startAnimation(nil)
        
        // Slight delay to show the loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.onSelectionComplete?(rect)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc key
            window?.close()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let rect = currentRect {
            // Draw dimming overlay
            NSColor.black.withAlphaComponent(0.5).setFill()
            let path = NSBezierPath(rect: bounds)
            path.fill()
            
            // Clear the selection area
            NSColor.clear.setFill()
            let selectionPath = NSBezierPath(rect: rect)
            selectionPath.fill()
            
            // Draw selection border with system accent color
            NSColor.systemBlue.setStroke()
            let strokePath = NSBezierPath(rect: rect)
            strokePath.lineWidth = 2.0
            strokePath.stroke()
            
            // Draw selection handles
            let handleSize: CGFloat = 6.0
            let handles = [
                NSRect(x: rect.minX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize),
                NSRect(x: rect.maxX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize),
                NSRect(x: rect.minX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize),
                NSRect(x: rect.maxX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize)
            ]
            
            NSColor.white.setFill()
            for handle in handles {
                let handlePath = NSBezierPath(rect: handle)
                handlePath.fill()
            }
        }
    }
    
    func showProcessingState() {
        instructionLabel?.isHidden = true
        loadingIndicator?.isHidden = false
        loadingIndicator?.startAnimation(nil)
    }
    
    func hideProcessingState() {
        loadingIndicator?.isHidden = true
        loadingIndicator?.stopAnimation(nil)
    }
} 
