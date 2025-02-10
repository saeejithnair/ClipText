//
//  ClipTextApp.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-01-25.
//

import SwiftUI

@main
struct ClipTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 320, maxWidth: 320, minHeight: 320, maxHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var screenshotManager: ScreenshotManager?
    private var ocrService: OCRService?
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupStatusBarItem()
        setupServices()
        
        // Ensure the app keeps running even when the window is closed
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when the window is closed
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any resources
        hotkeyManager = nil
        screenshotManager = nil
        ocrService = nil
    }
    
    private func setupWindow() {
        // Configure the main window to be more native-looking
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.hasShadow = true
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            
            // Add rounded corners to match the content
            window.appearance = NSAppearance(named: .vibrantDark)
            window.isOpaque = false
            window.hasShadow = true
            
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 24
                contentView.layer?.masksToBounds = true
            }
            
            // Center the window
            if let screen = NSScreen.main {
                let x = (screen.frame.width - window.frame.width) / 2
                let y = (screen.frame.height - window.frame.height) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            mainWindow = window
        }
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ClipText")
        }
        
        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture Text (⌃⇧9)", action: #selector(startCapture), keyEquivalent: "9")
        captureItem.keyEquivalentModifierMask = [.control, .shift]
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupServices() {
        // TODO: In a real app, get this from secure storage or user preferences
        let apiKey = "AIzaSyCJtymXxwho9G9womXQD12HDZJNBbZjVqU"
        
        screenshotManager = ScreenshotManager()
        ocrService = OCRService(apiKey: apiKey)
        
        // Initialize hotkey manager
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyTriggered = { [weak self] in
            // Hide the main window if it's visible
            self?.mainWindow?.orderOut(nil)
            
            // Start the capture process
            self?.handleHotkeyTriggered()
        }
    }
    
    @objc private func startCapture() {
        handleHotkeyTriggered()
    }
    
    private func handleHotkeyTriggered() {
        // Hide the main window before capture
        mainWindow?.orderOut(nil)
        
        // Small delay to ensure window is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.screenshotManager?.captureRegion { [weak self] image in
                guard let image = image else {
                    NotificationManager.shared.showError(message: "Failed to capture screenshot")
                    return
                }
                
                self?.processImage(image)
            }
        }
    }
    
    private func processImage(_ image: NSImage) {
        print("Processing captured image: \(image.size)")
        ocrService?.performOCR(on: image) { result in
            print("OCR completed with result: \(result)")
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    print("OCR succeeded, copying to clipboard: \(text)")
                    ClipboardManager.shared.copyToClipboard(text)
                    NotificationManager.shared.showSuccess(message: "Text copied to clipboard")
                    
                case .failure(let error):
                    print("OCR failed with error: \(error)")
                    let errorMessage: String
                    switch error {
                    case .imageConversionFailed:
                        errorMessage = "Failed to process image"
                    case .networkError(let err):
                        errorMessage = "Network error occurred: \(err.localizedDescription)"
                    case .apiError(let message):
                        errorMessage = "API error: \(message)"
                    case .invalidResponse:
                        errorMessage = "Invalid response from server"
                    }
                    print("Showing error: \(errorMessage)")
                    NotificationManager.shared.showError(message: errorMessage)
                }
            }
        }
    }
    
    @objc private func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
