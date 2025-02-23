import Foundation
import AppKit
import Combine

@MainActor
final class CaptureCoordinator {
    private let screenshotManager: ScreenshotManager
    private let ocrService: OCRService
    private let clipboardManager: ClipboardManager
    private let notificationManager: NotificationManager
    private let resourceManager: ResourceManager
    private var spinnerWindow: SpinnerWindow?
    private var selectionWindow: SelectionWindow?
    private var eventMonitor: Any?

    init(screenshotManager: ScreenshotManager,
         ocrService: OCRService,
         clipboardManager: ClipboardManager,
         notificationManager: NotificationManager,
         resourceManager: ResourceManager) {
        self.screenshotManager = screenshotManager
        self.ocrService = ocrService
        self.clipboardManager = clipboardManager
        self.notificationManager = notificationManager
        self.resourceManager = resourceManager
    }

    func startCapture() async {
        // Monitor ESC key for cancellation
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                Task { await self?.cancel() }
                return nil
            }
            return event
        }
        resourceManager.track(.eventMonitor(eventMonitor!))

        do {
            // Prepare for capture and show selection window
            try await screenshotManager.prepareCapture()
            selectionWindow = screenshotManager.selectionWindow
            resourceManager.track(.window(selectionWindow!.window))

            // Get selected region
            let region = try await screenshotManager.selectRegion()

            // Show spinner during processing
            spinnerWindow = SpinnerWindow()
            spinnerWindow?.show()
            resourceManager.track(.window(spinnerWindow!))

            // Capture the selected region
            let image = try await screenshotManager.captureRegion(region: region)

            // Perform OCR
            let text = try await ocrService.performOCR(on: image)

            // Copy text to clipboard
            clipboardManager.copyToClipboard(text)

            // Notify user of success
            notificationManager.showSuccess(message: "Text copied to clipboard")

            // Clean up resources
            await cleanup()
        } catch {
            // Handle errors and notify user
            notificationManager.showError(message: error.localizedDescription)
            await cleanup()
        }
    }

    private func cancel() async {
        await cleanup()
    }

    private func cleanup() async {
        spinnerWindow?.hide()
        spinnerWindow = nil
        selectionWindow?.close()
        selectionWindow = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        resourceManager.releaseAll()
    }
}