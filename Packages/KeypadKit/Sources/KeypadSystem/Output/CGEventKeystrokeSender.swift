import CoreGraphics
import KeypadCore
import os

@MainActor
public final class CGEventKeystrokeSender: KeystrokeSender {
    private let deliveryBase: Duration
    private let deliveryPerKeystroke: Duration
    private let logger = Logger(subsystem: "io.berkan.keypad", category: "input")
    private var pendingTask: Task<Void, Never>?

    public init(deliveryBase: Duration = .milliseconds(50), deliveryPerKeystroke: Duration = .milliseconds(5)) {
        self.deliveryBase = deliveryBase
        self.deliveryPerKeystroke = deliveryPerKeystroke
    }

    public func send(_ keystrokes: [Keystroke], completion: @escaping @MainActor () -> Void) {
        for event in Self.events(for: keystrokes) {
            event.post(tap: .cghidEventTap)
        }
        let delay = deliveryBase + deliveryPerKeystroke * keystrokes.count
        logger.debug("Posted \(keystrokes.count) keystrokes, waiting \(delay.milliseconds) ms for delivery")
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            completion()
        }
    }
}

extension CGEventKeystrokeSender {
    static func events(for keystrokes: [Keystroke]) -> [CGEvent] {
        let source = CGEventSource(stateID: .privateState)
        return keystrokes.flatMap { keystroke -> [CGEvent] in
            let key = KeystrokeMapping.keyEvent(for: keystroke)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: false)
            else { return [] }
            for event in [down, up] {
                event.flags = key.flags
                PostedKeystrokeTag.mark(event)
            }
            return [down, up]
        }
    }
}

extension Duration {
    fileprivate var milliseconds: Int {
        Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
