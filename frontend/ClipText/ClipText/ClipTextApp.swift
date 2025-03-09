//
//  ClipTextApp.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-03-07.
//

import SwiftUI
import Auth0
import AppKit
import UserNotifications
import Combine

// Define a notification name for screenshot capture
extension Notification.Name {
    static let didCaptureScreenshot = Notification.Name("didCaptureScreenshot")
}

// Make the class explicitly conform to @unchecked Sendable to handle thread safety manually
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, ScreenshotCaptureDelegate, @unchecked Sendable {
    var statusItem: NSStatusItem?
    @Published var lastResponse: String = ""
    
    // Global monitor for keyboard events
    private var globalKeyMonitor: Any?
    // Screenshot capture controller
    private var screenshotController: ScreenshotCaptureController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerHotkey()
        
        // Initialize screenshot controller
        screenshotController = ScreenshotCaptureController()
        screenshotController?.delegate = self
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up global monitor
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // Register global hotkey (ctrl + shift + 9)
    private func registerHotkey() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Ctrl+Shift+9 (keycode 25 is '9')
            let isCommandDown = event.modifierFlags.contains(.control)
            let isShiftDown = event.modifierFlags.contains(.shift)
            let isKeycode9 = event.keyCode == 25
            
            if isCommandDown && isShiftDown && isKeycode9 {
                print("Screenshot hotkey detected")
                self?.startScreenshotCapture()
            }
        }
    }
    
    // Make this method public so it can be called from GeminiView
    func startScreenshotCapture() {
        DispatchQueue.main.async { [weak self] in
            self?.screenshotController?.beginCapture()
        }
    }
    
    // MARK: - Screenshot Capture Delegate Methods
    
    func didCaptureScreenshot(_ image: NSImage) {
        print("Screenshot captured: \(image.size)")
        
        // Post notification with the captured image
        NotificationCenter.default.post(
            name: .didCaptureScreenshot,
            object: nil,
            userInfo: ["image": image]
        )
    }
    
    func didCancelScreenshotCapture() {
        print("Screenshot capture cancelled")
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "ClipText")
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Copy Last Response", action: #selector(copyLastResponse), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open ClipText", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func copyLastResponse() {
        if !lastResponse.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(lastResponse, forType: .string)
            
            // Show notification using the new API
            let content = UNMutableNotificationContent()
            content.title = "ClipText"
            content.body = "Last response copied to clipboard"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error showing notification: \(error)")
                }
            }
        }
    }
    
    @objc func openApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    func updateLastResponse(_ response: String) {
        lastResponse = response
    }
}

@main
struct ClipTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        configureAuth0()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate)
        }
    }
    
    private func configureAuth0() {
        guard let path = Bundle.main.path(forResource: "Auth0", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
              let domain = dict["Domain"] as? String,
              let clientId = dict["ClientId"] as? String else {
            print("Auth0 configuration error: missing or invalid Auth0.plist file")
            return
        }
        
        // We don't need to store these instances as Auth0 manages them internally
        // We're just making sure the configuration is loaded
        _ = Auth0.authentication(clientId: clientId, domain: domain)
        _ = Auth0.webAuth(clientId: clientId, domain: domain)
    }
}
