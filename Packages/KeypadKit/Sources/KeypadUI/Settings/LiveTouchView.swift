import AppKit
import KeypadCore
import Observation

/// The fingers currently on the trackpad, while the Settings window is key.
@MainActor
@Observable
final class LiveTouches {
    var points: [TrackpadPoint] = []
}

/// Lies on top of the Keypad tab and claims only trackpad touches; clicks, drags and scrolls fall through to the
/// controls underneath.
final class LiveTouchView: NSView {
    private let liveTouches: LiveTouches

    init(liveTouches: LiveTouches) {
        self.liveTouches = liveTouches
        super.init(frame: .zero)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        NSApplication.shared.currentEvent?.type == .gesture ? super.hitTest(point) : nil
    }

    override func touchesBegan(with event: NSEvent) { report(event) }
    override func touchesMoved(with event: NSEvent) { report(event) }
    override func touchesEnded(with event: NSEvent) { report(event) }
    override func touchesCancelled(with event: NSEvent) { report(event) }

    private func report(_ event: NSEvent) {
        liveTouches.points = event.touches(matching: .touching, in: self).map {
            TrackpadPoint(x: $0.normalizedPosition.x, y: $0.normalizedPosition.y)
        }
    }
}
