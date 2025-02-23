import Cocoa
import ScreenCaptureKit
import AppKit

final class ScreenshotManager {
    private(set) var selectionWindow: SelectionWindow?

    func prepareCapture() async throws {
        // Verify screen recording permission
        do {
            let content = try await SCShareableContent.current
            if content.windows.isEmpty && content.displays.isEmpty {
                throw ScreenshotError.permissionDenied
            }
        } catch {
            throw ScreenshotError.permissionDenied
        }

        // Initialize and show selection window
        selectionWindow = SelectionWindow()
        selectionWindow?.show()
    }

    func selectRegion() async throws -> CGRect {
        return try await withCheckedThrowingContinuation { continuation in
            selectionWindow?.onRegionSelected = { region in
                continuation.resume(returning: region)
            }
            selectionWindow?.onCancelled = {
                continuation.resume(throwing: ScreenshotError.cancelled)
            }
        }
    }

    func captureRegion(region: CGRect) async throws -> NSImage {
        let content = try await SCShareableContent.current
        let display = content.displays.first!
        // Exclude the selection window from capture
        let filter = SCContentFilter(display: display, excludingWindows: content.windows.filter { $0.windowID == selectionWindow?.window.windowNumber ?? 0 })
        let config = SCStreamConfiguration()
        config.width = Int(region.width)
        config.height = Int(region.height)
        config.sourceRect = region
        config.showsCursor = false

        let sampleBuffer = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw ScreenshotError.captureFailed
        }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

enum ScreenshotError: Error, LocalizedError {
    case permissionDenied
    case captureFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen recording permission is required."
        case .captureFailed: return "Failed to capture the screen."
        case .cancelled: return "Capture cancelled."
        }
    }
}