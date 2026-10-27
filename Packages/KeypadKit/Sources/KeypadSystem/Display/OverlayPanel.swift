import AppKit

/// A borderless panel above every app on every Space, including full-screen ones, that never activates Keypad.
class OverlayPanel: NSPanel {
    init(backgroundColor: NSColor) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.backgroundColor = backgroundColor
        // Before `level`: setting it resets the level to `.floating`.
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
