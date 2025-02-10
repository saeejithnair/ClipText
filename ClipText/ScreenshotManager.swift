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
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
        
        window.makeKeyAndOrderFront(nil)
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
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
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
        guard let rect = currentRect else { return }
        onSelectionComplete?(rect)
        startPoint = nil
        currentRect = nil
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let rect = currentRect {
            NSColor.clear.set()
            let selectionPath = NSBezierPath(rect: rect)
            selectionPath.fill()
            
            NSColor.white.set()
            let strokePath = NSBezierPath(rect: rect)
            strokePath.lineWidth = 1.0
            strokePath.stroke()
        }
    }
} 
