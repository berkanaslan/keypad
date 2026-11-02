public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let control = ShortcutModifiers(rawValue: 1)
    public static let option = ShortcutModifiers(rawValue: 2)
    public static let shift = ShortcutModifiers(rawValue: 4)
    public static let command = ShortcutModifiers(rawValue: 8)
}

/// A system-wide shortcut: a virtual key code and its modifiers.
public struct Shortcut: Codable, Hashable, Sendable {
    public static let `default` = Shortcut(keyCode: 40, modifiers: [.control, .option])
    /// F1…F20, in order.
    public static let functionKeyCodes: [UInt16] = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
    ]
    private static let modifierKeyCodes: ClosedRange<UInt16> = 54...63

    public let keyCode: UInt16
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt16, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var isFunctionKey: Bool {
        Self.functionKeyCodes.contains(keyCode)
    }

    /// With one modifier almost every key is already an app shortcut or a text-editing key, and macOS 15 no longer
    /// accepts ⌥-only and ⌥⇧-only hotkeys.
    public var isValid: Bool {
        guard !Self.modifierKeyCodes.contains(keyCode) else { return false }
        if isFunctionKey { return true }
        let count = [ShortcutModifiers.control, .option, .shift, .command].filter(modifiers.contains).count
        return count >= 2 && !modifiers.isDisjoint(with: [.command, .control])
    }
}
