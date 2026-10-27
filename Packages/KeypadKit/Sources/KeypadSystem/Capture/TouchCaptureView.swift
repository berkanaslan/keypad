import AppKit
import KeypadCore

/// Reports trackpad touches as samples and swallows every other input, so nothing reaches the app underneath.
final class TouchCaptureView: NSView {
    var onSample: ((TouchSample) -> Void)?

    private var identifiers: [NSObject: Int] = [:]
    private var nextIdentifier = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    /// Identifiers are never reused, so a touch that was in flight cannot be mistaken for a later one.
    func forgetTouches() {
        identifiers.removeAll()
    }

    override func touchesBegan(with event: NSEvent) { report(event, as: .began, matching: .began) }
    override func touchesMoved(with event: NSEvent) { report(event, as: .moved, matching: .moved) }
    override func touchesEnded(with event: NSEvent) { report(event, as: .ended, matching: .ended) }
    override func touchesCancelled(with event: NSEvent) { report(event, as: .cancelled, matching: .cancelled) }

    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    override func magnify(with event: NSEvent) {}
    override func rotate(with event: NSEvent) {}
    override func swipe(with event: NSEvent) {}

    private func report(_ event: NSEvent, as phase: TouchSample.Phase, matching touchPhase: NSTouch.Phase) {
        for touch in event.touches(matching: touchPhase, in: self) {
            guard let identity = touch.identity as? NSObject else { continue }
            let sample = TouchSample(
                id: identifier(for: identity),
                phase: phase,
                point: TrackpadPoint(x: touch.normalizedPosition.x, y: touch.normalizedPosition.y),
                time: event.timestamp
            )
            if phase == .ended || phase == .cancelled { identifiers[identity] = nil }
            onSample?(sample)
        }
    }

    private func identifier(for identity: NSObject) -> Int {
        if let known = identifiers[identity] { return known }
        nextIdentifier += 1
        identifiers[identity] = nextIdentifier
        return nextIdentifier
    }
}
