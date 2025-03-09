import SwiftUI
import AppKit
import ScreenCaptureKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

// Delegate protocol for communicating back to the app
// Make the protocol Sendable to fix the concurrency warnings
protocol ScreenshotCaptureDelegate: AnyObject, Sendable {
    func didCaptureScreenshot(_ image: NSImage)
    func didCancelScreenshotCapture()
}

// Custom NSWindow subclass for our overlay
class ScreenshotOverlayWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

// Custom NSView for handling mouse events and drawing the selection
class SelectionView: NSView {
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var selectionRect: NSRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
    
    var onSelectionFinished: ((NSRect) -> Void)?
    var onSelectionCancelled: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = event.locationInWindow
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow
        
        // Finish selection only if we have a valid selection rectangle
        if let rect = selectionRect, rect.width > 10, rect.height > 10 {
            onSelectionFinished?(rect)
        } else {
            // Cancel if the selection is too small
            onSelectionCancelled?()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Cancel on escape key
        if event.keyCode == 53 { // ESC key
            onSelectionCancelled?()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw semi-transparent dark overlay
        NSColor(white: 0, alpha: 0.3).setFill()
        dirtyRect.fill()
        
        // Draw the selection rectangle if available
        if let rect = selectionRect {
            // Clear the selected area
            NSColor.clear.setFill()
            rect.fill()
            
            // Draw border around selection
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // Draw sizing handles at corners
            let handleSize: CGFloat = 8
            let handles = [
                NSRect(x: rect.minX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize),
                NSRect(x: rect.maxX - handleSize/2, y: rect.minY - handleSize/2, width: handleSize, height: handleSize),
                NSRect(x: rect.minX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize),
                NSRect(x: rect.maxX - handleSize/2, y: rect.maxY - handleSize/2, width: handleSize, height: handleSize)
            ]
            
            for handle in handles {
                NSColor.white.setFill()
                let handlePath = NSBezierPath(ovalIn: handle)
                handlePath.fill()
            }
            
            // Display dimensions
            let dimensionsString = "\(Int(rect.width)) × \(Int(rect.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor(white: 0, alpha: 0.7),
                .font: NSFont.systemFont(ofSize: 12, weight: .medium)
            ]
            
            let attributedString = NSAttributedString(string: dimensionsString, attributes: attributes)
            let stringSize = attributedString.size()
            
            // Position the dimensions text
            let textRect = NSRect(
                x: rect.midX - stringSize.width / 2,
                y: rect.maxY + 8,
                width: stringSize.width + 8,
                height: stringSize.height + 4
            )
            
            // Draw background for text
            NSColor(white: 0, alpha: 0.7).setFill()
            NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
            
            // Draw the text
            attributedString.draw(at: NSPoint(
                x: textRect.minX + 4,
                y: textRect.minY + 2
            ))
        }
    }
}

// Custom output class for SCStream
class ScreenshotStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private var onFrameReceived: ((NSImage) -> Void)?
    
    init(onFrameReceived: @escaping (NSImage) -> Void) {
        self.onFrameReceived = onFrameReceived
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // We only want screen content (not audio)
        guard type == .screen, let onFrameReceived = onFrameReceived else { return }
        
        // Convert CMSampleBuffer to CVPixelBuffer
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        // Create CIImage from CVPixelBuffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert CIImage to CGImage using CIContext
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Create NSImage from CGImage
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // Call our callback with the image
        onFrameReceived(image)
        
        // Remove callback to ensure we only capture one frame
        self.onFrameReceived = nil
    }
}

// Main controller for screenshot capture
class ScreenshotCaptureController: NSObject, @unchecked Sendable {
    private var overlayWindow: ScreenshotOverlayWindow?
    private var selectionView: SelectionView?
    private var stream: SCStream?
    private var streamOutput: ScreenshotStreamOutput?
    private var filter: SCContentFilter?
    private var configuration: SCStreamConfiguration?
    private var originalWindows: [NSWindow] = []
    
    weak var delegate: ScreenshotCaptureDelegate?
    
    // Start the screenshot capture process
    func beginCapture() {
        // Hide application windows to avoid capturing them
        hideAppWindows()
        
        // No need to check for main screen, just make sure there are screens
        guard !NSScreen.screens.isEmpty else {
            delegate?.didCancelScreenshotCapture()
            return
        }
        
        // Create overlay window covering all screens
        let allScreensRect = NSScreen.screens.reduce(NSRect.zero) { result, screen in
            return result.union(screen.frame)
        }
        
        overlayWindow = ScreenshotOverlayWindow(contentRect: allScreensRect)
        
        // Create selection view
        selectionView = SelectionView(frame: NSRect(origin: .zero, size: allScreensRect.size))
        selectionView?.onSelectionFinished = { [weak self] rect in
            self?.captureSelectedRegion(rect)
        }
        selectionView?.onSelectionCancelled = { [weak self] in
            self?.cancelCapture()
        }
        
        // Add selection view to window and make it key
        overlayWindow?.contentView = selectionView
        overlayWindow?.makeKeyAndOrderFront(nil)
        
        // Make the view first responder to receive keyboard events
        overlayWindow?.makeFirstResponder(selectionView)
    }
    
    // Capture the selected region using ScreenCaptureKit
    private func captureSelectedRegion(_ rect: NSRect) {
        // Store a weak reference to delegate before the Task
        // to avoid concurrency issues
        weak var weakDelegate = delegate
        
        Task {
            do {
                // Convert screen coordinates to global coordinates
                let convertedRect = CGRect(
                    x: rect.minX,
                    y: NSScreen.screens.reduce(NSRect.zero) { result, screen in
                        return result.union(screen.frame)
                    }.height - rect.maxY,
                    width: rect.width,
                    height: rect.height
                )
                
                // Get available content
                let availableContent = try await SCShareableContent.current
                
                // Create a display filter for the main display
                guard let mainDisplay = availableContent.displays.first else {
                    throw NSError(domain: "ScreenshotCaptureError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
                }
                
                // Create a content filter for the specific region of the display
                let excludedApps = availableContent.applications.filter { app in
                    return Bundle.main.bundleIdentifier == app.bundleIdentifier
                }
                
                // Create the filter with the selected rect
                filter = SCContentFilter(
                    display: mainDisplay,
                    excludingApplications: excludedApps,
                    exceptingWindows: []
                )
                
                // Create stream configuration
                configuration = SCStreamConfiguration()
                configuration?.width = Int(rect.width)
                configuration?.height = Int(rect.height)
                configuration?.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                configuration?.pixelFormat = kCVPixelFormatType_32BGRA
                
                // Set the region of the screen to capture
                configuration?.sourceRect = convertedRect
                
                // Create the stream and add our custom output
                stream = SCStream(filter: filter!, configuration: configuration!, delegate: nil)
                
                // Create and add the stream output with safer concurrency
                streamOutput = ScreenshotStreamOutput { [weak self] capturedImage in
                    // Create a copy of the image data
                    let tiffData = capturedImage.tiffRepresentation ?? Data()
                    
                    Task { [weak self] in
                        try? await self?.stream?.stopCapture()
                        
                        // Capture what we need to update UI
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            // Stop the screen capture
                            self.stream = nil
                            self.overlayWindow?.close()
                            self.overlayWindow = nil
                            self.restoreAppWindows()
                            
                            // Reconstruct the image on the main thread
                            // This ensures NSImage is only handled on the main thread
                            if let image = NSImage(data: tiffData) {
                                weakDelegate?.didCaptureScreenshot(image)
                            }
                        }
                    }
                }
                
                try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: .main)
                
                // Start capturing
                try await stream?.startCapture()
            } catch {
                print("Screenshot capture error: \(error)")
                
                // Move all UI updates to main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.overlayWindow?.close()
                    self.overlayWindow = nil
                    self.restoreAppWindows()
                    
                    // Call delegate on main thread
                    weakDelegate?.didCancelScreenshotCapture()
                }
            }
        }
    }
    
    // Cancel the capture process
    private func cancelCapture() {
        overlayWindow?.close()
        overlayWindow = nil
        restoreAppWindows()
        delegate?.didCancelScreenshotCapture()
    }
    
    // Hide app windows to avoid capturing them
    private func hideAppWindows() {
        // Store visible windows
        originalWindows = NSApp.windows.filter { $0.isVisible }
        
        // Hide all app windows
        NSApp.windows.forEach { window in
            if window.isVisible {
                window.orderOut(nil)
            }
        }
    }
    
    // Restore app windows after capture
    private func restoreAppWindows() {
        originalWindows.forEach { window in
            window.makeKeyAndOrderFront(nil)
        }
        originalWindows = []
    }
} 