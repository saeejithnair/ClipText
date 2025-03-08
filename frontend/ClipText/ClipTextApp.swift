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
        // Hardcode API key for development purposes
        let apiKey = "your_api_key_here"
        print("Using hardcoded API key for development. In production, retrieve from Keychain.")

        let screenshotManager = ScreenshotManager()
        let ocrService = OCRService(apiKey: apiKey)
        let clipboardManager = ClipboardManager.shared
        let notificationManager = NotificationManager.shared
        let resourceManager = ResourceManager.shared

        coordinator = CaptureCoordinator(
            screenshotManager: screenshotManager,
            ocrService: ocrService,
            clipboardManager: clipboardManager,
            notificationManager: notificationManager,
            resourceManager: resourceManager
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupStatusItem()
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            setupWindow()

            if !hasAccessibilityPermissions {
                showAccessibilityAlert()
            }

            HotkeyManager.shared.onHotkeyTriggered = { [weak self] in
                Task { @MainActor in
                    await self?.handleHotkeyTriggered()
                }
            }

            NSApp.setActivationPolicy(.accessory)
        }
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

    @objc private func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleHotkeyTriggered() async {
        mainWindow?.orderOut(nil)
        await coordinator.startCapture()
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "ClipText needs accessibility permissions to capture screen content. Please enable them in System Settings > Privacy & Security > Accessibility, then restart the app."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
