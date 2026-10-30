import Carbon.HIToolbox
import KeypadCore

/// Names a shortcut the way macOS menus do: modifiers in the order ⌃ ⌥ ⇧ ⌘, then the key as the current layout
/// types it.
@MainActor
public final class KeyboardLayoutShortcutNames: ShortcutNaming {
    private static let modifierSymbols: [(ShortcutModifiers, String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]
    private static let keySymbols: [Int: String] = [
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "␣", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    public init() {}

    public func name(for shortcut: Shortcut) -> String {
        let modifiers = Self.modifierSymbols.filter { shortcut.modifiers.contains($0.0) }.map(\.1).joined()
        return modifiers + keyName(for: shortcut)
    }

    private func keyName(for shortcut: Shortcut) -> String {
        if let index = Shortcut.functionKeyCodes.firstIndex(of: shortcut.keyCode) { return "F\(index + 1)" }
        if let symbol = Self.keySymbols[Int(shortcut.keyCode)] { return symbol }
        return KeyboardLayout.character(for: shortcut.keyCode)?.uppercased() ?? "?"
    }
}
