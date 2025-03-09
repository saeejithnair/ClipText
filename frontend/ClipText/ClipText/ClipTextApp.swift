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

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    @Published var lastResponse: String = ""
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
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
