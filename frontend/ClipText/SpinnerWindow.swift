import Cocoa

final class SpinnerWindow: NSWindow {
    private let spinner: NSProgressIndicator

    init() {
        let frame = NSRect(x: 20, y: NSScreen.main?.visibleFrame.maxY ?? 0 - 120, width: 80, height: 80)
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 20, width: 40, height: 40))
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.startAnimation(nil)
        contentView = spinner
    }

    func show() {
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        orderOut(nil)
    }
}