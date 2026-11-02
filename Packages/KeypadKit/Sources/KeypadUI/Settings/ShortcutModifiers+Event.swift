import AppKit
import KeypadCore

extension ShortcutModifiers {
    /// Keeps ⌘ ⌃ ⌥ ⇧ only: macOS adds `.function` and `.numericPad` to arrow and function keys on its own.
    init(eventFlags: NSEvent.ModifierFlags) {
        let pairs: [(NSEvent.ModifierFlags, ShortcutModifiers)] = [
            (.control, .control), (.option, .option), (.shift, .shift), (.command, .command),
        ]
        self = pairs.reduce(into: []) { modifiers, pair in
            if eventFlags.contains(pair.0) { modifiers.insert(pair.1) }
        }
    }
}
