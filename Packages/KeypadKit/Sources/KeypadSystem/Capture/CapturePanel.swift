import AppKit

/// Key despite being non-activating: trackpad touches reach a view only through the key window (RFC-0000 F2).
final class CapturePanel: OverlayPanel {
    init() {
        super.init(backgroundColor: NSColor.black.withAlphaComponent(0.1))
    }

    override var canBecomeKey: Bool { true }
}
