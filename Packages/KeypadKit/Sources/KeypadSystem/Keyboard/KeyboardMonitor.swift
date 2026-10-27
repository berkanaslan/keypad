import AppKit
import KeypadCore
import os

@MainActor
public final class KeyboardMonitor {
    private let decimalSeparator: DecimalSeparatorProvider
    private let logger = Logger(subsystem: "io.berkan.keypad", category: "input")
    private var handler: (@MainActor (KeyInput) -> Bool)?
    private var token: Any?

    public init(decimalSeparator: DecimalSeparatorProvider) {
        self.decimalSeparator = decimalSeparator
    }

    /// Calls `handler` for every key-down in this app; the key is swallowed when it returns `true`.
    public func start(_ handler: @escaping @MainActor (KeyInput) -> Bool) {
        stop()
        self.handler = handler
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if PostedKeystrokeTag.isMarked(event) {
                MainActor.assumeIsolated {
                    self?.logger.info("Discarded a keystroke Keypad posted itself after the delivery wait")
                }
                return nil
            }
            let code = event.keyCode
            let characters = event.characters
            let isShiftDown = event.modifierFlags.contains(.shift)
            // `.function` and `.numericPad` are excluded: macOS sets them on plain arrow-key and keypad events.
            let isShortcutModifierDown = !event.modifierFlags.isDisjoint(with: [.command, .control, .option])
            let swallowed = MainActor.assumeIsolated {
                self?.handle(code, characters, isShiftDown, isShortcutModifierDown) ?? false
            }
            return swallowed ? nil : event
        }
    }

    public func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
        handler = nil
    }

    private func handle(
        _ code: UInt16, _ characters: String?, _ isShiftDown: Bool, _ isShortcutModifierDown: Bool
    ) -> Bool {
        let input = KeyboardClassifier.classify(
            keyCode: code,
            characters: characters,
            isShiftDown: isShiftDown,
            isShortcutModifierDown: isShortcutModifierDown,
            decimalSeparator: decimalSeparator.decimalSeparator
        )
        return handler?(input) ?? false
    }
}
