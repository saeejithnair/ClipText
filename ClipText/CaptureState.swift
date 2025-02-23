import Foundation
import AppKit
import Combine

/// Represents the current state of the capture process
enum CaptureState: Equatable {
    case idle
    case preparingCapture
    case selectingRegion
    case capturing
    case processing
    case completed
    case error(String)
    
    static func == (lhs: CaptureState, rhs: CaptureState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparingCapture, .preparingCapture),
             (.selectingRegion, .selectingRegion),
             (.capturing, .capturing),
             (.processing, .processing),
             (.completed, .completed):
            return true
        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Main coordinator that manages the capture flow
@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published private(set) var state: CaptureState = .idle
    private var cancellables: Set<AnyCancellable> = []
    private var cleanupTasks: [() -> Void] = []
    
    // Dependencies
    private let screenshotManager: ScreenshotManagerProtocol
    private let ocrService: OCRServiceProtocol
    private let clipboardManager: ClipboardManagerProtocol
    
    init(
        screenshotManager: ScreenshotManagerProtocol,
        ocrService: OCRServiceProtocol,
        clipboardManager: ClipboardManagerProtocol = ClipboardManager.shared
    ) {
        self.screenshotManager = screenshotManager
        self.ocrService = ocrService
        self.clipboardManager = clipboardManager
    }
    
    func startCapture() async {
        guard state == .idle else { return }
        
        do {
            state = .preparingCapture
            try await screenshotManager.prepareCapture()
            
            state = .selectingRegion
            let image = try await screenshotManager.captureRegion()
            
            state = .capturing
            let text = try await ocrService.performOCR(on: image)
            
            state = .processing
            clipboardManager.copyToClipboard(text)
            
            state = .completed
            await cleanup()
        } catch {
            state = .error(error.localizedDescription)
            await cleanup()
        }
    }
    
    func cancel() async {
        await cleanup()
        state = .idle
    }
    
    private func cleanup() async {
        cleanupTasks.forEach { $0() }
        cleanupTasks.removeAll()
    }
    
    func registerCleanupTask(_ task: @escaping () -> Void) {
        cleanupTasks.append(task)
    }
} 