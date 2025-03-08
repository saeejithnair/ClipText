import Cocoa

final class SelectionWindow {
    var onRegionSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    private(set) var window: NSWindow!
    private var selectionView: SelectionView!

    init() {
        setupWindow()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window.orderOut(nil)
    }

    private func setupWindow() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false

        selectionView = SelectionView(frame: screen.frame)
        selectionView.onSelectionComplete = { [weak self] rect in
            self?.onRegionSelected?(rect)
            self?.close()
        }
        window.contentView = selectionView
    }
}