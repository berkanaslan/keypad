import AppKit

/// Marks the key events Keypad posts. The delivery wait is a heuristic, so one can reach Keypad's own keyboard
/// monitor late; the tag lets the monitor recognise and discard it instead of treating it as user input.
enum PostedKeystrokeTag {
    static let value: Int64 = 0x4B45_5950

    static func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: value)
    }

    static func isMarked(_ event: NSEvent) -> Bool {
        event.cgEvent?.getIntegerValueField(.eventSourceUserData) == value
    }
}
