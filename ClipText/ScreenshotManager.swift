import Cocoa
import ScreenCaptureKit
import AppKit
import Combine

protocol ScreenshotManagerProtocol {
    func prepareCapture() async throws
    func captureRegion() async throws -> NSImage
}

enum ScreenshotError: Error {
    case permissionDenied
    case setupFailed
    case captureFailed
    case cancelled
}

@MainActor
final class ScreenshotManager: NSObject, ScreenshotManagerProtocol, SCStreamDelegate {
    private var stream: SCStream?
    private var selectionWindow: SelectionWindow?
    private var selectedRegion: CGRect?
    private var captureCompletion: ((Result<NSImage, Error>) -> Void)?
    
    func prepareCapture() async throws {
        // Check screen recording permission
        guard await SCShareableContent.current.windows.isEmpty == false else {
            throw ScreenshotError.permissionDenied
        }
        
        // Clean up any existing capture
        await cleanup()
        
        // Show selection window
        selectionWindow = SelectionWindow()
        selectionWindow?.onRegionSelected = { [weak self] region in
            self?.selectedRegion = region
            Task { @MainActor in
                try await self?.startCapture(region: region)
            }
        }
        selectionWindow?.onCancelled = { [weak self] in
            Task { @MainActor in
                await self?.cleanup()
            }
        }
        selectionWindow?.show()
    }
    
    func captureRegion() async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            captureCompletion = { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func startCapture(region: CGRect) async throws {
        print("ScreenshotManager: Starting capture for region: \(region)")
        
        // Clean up any existing capture first
        await cleanup()
        
        guard let display = await SCShareableContent.current.displays.first else {
            print("ScreenshotManager: No display found")
            throw ScreenshotError.setupFailed
        }
        
        // Get all shareable content
        let content = try await SCShareableContent.current
        
        // Find our selection window in the shareable windows
        let excludedWindow = content.windows.first { window in
            window.windowID == selectionWindow?.window.windowNumber ?? 0
        }
        
        let filter = SCContentFilter(
            display: display,
            excludingWindows: excludedWindow.map { [$0] } ?? []
        )
        
        let config = SCStreamConfiguration()
        config.width = Int(region.width)
        config.height = Int(region.height)
        config.showsCursor = false
        config.sourceRect = region
        
        print("ScreenshotManager: Creating stream")
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        print("ScreenshotManager: Adding stream output")
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        
        print("ScreenshotManager: Starting stream capture")
        try await stream?.startCapture()
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("ScreenshotManager: Stream stopped with error: \(error)")
        captureCompletion?(.failure(error))
        Task { @MainActor in
            await cleanup()
        }
    }
}

extension ScreenshotManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let image = convertToImage(sampleBuffer) else {
            captureCompletion?(.failure(ScreenshotError.captureFailed))
            return
        }
        
        Task { @MainActor in
            captureCompletion?(.success(image))
            try? await stream.stopCapture()
            await cleanup()
        }
    }
    
    private func convertToImage(_ buffer: CMSampleBuffer) -> NSImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
    private func cleanup() async {
        print("ScreenshotManager: Starting cleanup")
        
        if let stream = stream {
            do {
                try await stream.stopCapture()
                print("ScreenshotManager: Stream stopped successfully")
            } catch {
                print("ScreenshotManager: Error stopping stream: \(error)")
                // Continue cleanup even if stopping fails
            }
        }
        
        stream = nil
        selectionWindow?.close()
        selectionWindow = nil
        selectedRegion = nil
        captureCompletion = nil
        
        print("ScreenshotManager: Cleanup completed")
    }
}

// MARK: - Selection Window
private final class SelectionWindow {
    var onRegionSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    private(set) var window: NSWindow!
    private var selectionView: RegionSelectionView!
    
    init() {
        setupWindow()
        setupKeyHandling()
    }
    
    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func close() {
        window.orderOut(nil)
    }
    
    private func setupWindow() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        selectionView = RegionSelectionView()
        selectionView.onRegionSelected = { [weak self] region in
            self?.onRegionSelected?(region)
        }
        window.contentView = selectionView
    }
    
    private func setupKeyHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.onCancelled?()
                return nil
            }
            return event
        }
    }
}

// MARK: - Selection View
private final class RegionSelectionView: NSView {
    var onRegionSelected: ((CGRect) -> Void)?
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
    }
    
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
        guard let rect = currentRect else { return }
        onRegionSelected?(rect)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let rect = currentRect {
            // Draw semi-transparent overlay
            NSColor.black.withAlphaComponent(0.5).setFill()
            let path = NSBezierPath(rect: bounds)
            path.fill()
            
            // Clear the selection area
            NSColor.clear.setFill()
            NSBezierPath(rect: rect).fill()
            
            // Draw selection border
            NSColor.systemBlue.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2.0
            borderPath.stroke()
        }
    }
} 
