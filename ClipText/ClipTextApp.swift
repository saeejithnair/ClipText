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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: CaptureCoordinator
    private let statusItem: NSStatusItem
    private var mainWindow: NSWindow?
    private var hasAccessibilityPermissions = false
    
    override init() {
        // Initialize services
        let apiKey = "AIzaSyCJtymXxwho9G9womXQD12HDZJNBbZjVqU" // Replace with your Gemini API key
        
        // Check accessibility permissions
        let options = NSDictionary(object: kCFBooleanTrue!, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        hasAccessibilityPermissions = AXIsProcessTrustedWithOptions(options)
        print("AppDelegate: Accessibility enabled: \(hasAccessibilityPermissions)")
        
        let screenshotManager = ScreenshotManager()
        let ocrService = OCRService(apiKey: apiKey)
        
        coordinator = CaptureCoordinator(
            screenshotManager: screenshotManager,
            ocrService: ocrService
        )
        
        // Initialize status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        super.init()
        
        setupStatusItem()
    }
    
    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application did finish launching")
        Task { @MainActor in
            setupWindow()
            
            if !hasAccessibilityPermissions {
                showAccessibilityAlert()
            }
            
            // Register hotkey handler
            print("AppDelegate: Setting up hotkey handler")
            HotkeyManager.shared.onHotkeyTriggered = { [weak self] in
                print("AppDelegate: Hotkey triggered")
                Task { @MainActor in
                    await self?.handleHotkeyTriggered()
                }
            }
            
            // Ensure the app keeps running even when the window is closed
            NSApp.setActivationPolicy(.accessory)
            print("AppDelegate: Setup complete")
        }
    }
    
    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    private func setupWindow() {
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.hasShadow = true
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            
            window.appearance = NSAppearance(named: .vibrantDark)
            window.isOpaque = false
            
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 24
                contentView.layer?.masksToBounds = true
            }
            
            if let screen = NSScreen.main {
                let x = (screen.frame.width - window.frame.width) / 2
                let y = (screen.frame.height - window.frame.height) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            mainWindow = window
        }
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
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
        
        statusItem.menu = menu
    }
    
    @objc private func startCapture() {
        Task { @MainActor in
            await handleHotkeyTriggered()
        }
    }
    
    private func showAccessibilityAlert() {
        print("AppDelegate: Accessibility permissions required. Please grant them in System Settings.")
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "ClipText needs accessibility permissions to capture screen content. Please enable them in System Settings > Privacy & Security > Accessibility, then restart the app."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
    
    private func handleHotkeyTriggered() async {
        print("AppDelegate: Handling hotkey trigger")
        mainWindow?.orderOut(nil)
        await coordinator.startCapture()
    }
    
    @objc private func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
