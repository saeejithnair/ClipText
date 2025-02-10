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
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var screenshotManager: ScreenshotManager?
    private var ocrService: OCRService?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupServices()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ClipText")
        }
        
        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture (⌃⇧9)", action: #selector(startCapture), keyEquivalent: "9")
        captureItem.keyEquivalentModifierMask = [.control, .shift]
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupServices() {
        // TODO: In a real app, get this from secure storage or user preferences
        let apiKey = "AIzaSyCJtymXxwho9G9womXQD12HDZJNBbZjVqU"
        
        screenshotManager = ScreenshotManager()
        ocrService = OCRService(apiKey: apiKey)
        
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyTriggered = { [weak self] in
            self?.handleHotkeyTriggered()
        }
    }
    
    @objc private func startCapture() {
        handleHotkeyTriggered()
    }
    
    private func handleHotkeyTriggered() {
        screenshotManager?.captureRegion { [weak self] image in
            guard let image = image else {
                NotificationManager.shared.showError(message: "Failed to capture screenshot")
                return
            }
            
            self?.processImage(image)
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
}
