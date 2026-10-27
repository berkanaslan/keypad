import Carbon.HIToolbox
import KeypadCore

public enum KeyboardClassifier {
    public static func classify(
        keyCode: UInt16,
        characters: String?,
        isShiftDown: Bool,
        isShortcutModifierDown: Bool,
        decimalSeparator: String
    ) -> KeyInput {
        if isShortcutModifierDown { return .other }
        switch Int(keyCode) {
        case kVK_ANSI_KeypadDecimal: return .decimalSeparator
        case kVK_Delete: return .deleteBackward
        case kVK_Return: return .commit(isShiftDown ? .shiftReturn : .returnKey)
        case kVK_ANSI_KeypadEnter: return .commit(.keypadEnter)
        case kVK_Tab: return .commit(isShiftDown ? .shiftTab : .tab)
        case kVK_LeftArrow: return arrow(.left, isShiftDown: isShiftDown)
        case kVK_RightArrow: return arrow(.right, isShiftDown: isShiftDown)
        case kVK_UpArrow: return arrow(.up, isShiftDown: isShiftDown)
        case kVK_DownArrow: return arrow(.down, isShiftDown: isShiftDown)
        case kVK_Escape: return .escape
        default: return classify(characters: characters, decimalSeparator: decimalSeparator)
        }
    }

    /// ⇧ with an arrow extends a selection in the target, so unlike ⇧Return and ⇧Tab it is never a commit.
    private static func arrow(_ direction: ArrowDirection, isShiftDown: Bool) -> KeyInput {
        isShiftDown ? .other : .commit(.arrow(direction))
    }

    private static func classify(characters: String?, decimalSeparator: String) -> KeyInput {
        guard let characters, !characters.isEmpty else { return .other }
        if let digit = digit(in: characters) { return .digit(digit) }
        return characters == decimalSeparator ? .decimalSeparator : .other
    }

    private static func digit(in characters: String) -> Int? {
        let scalars = characters.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first, ("0"..."9").contains(scalar) else { return nil }
        return Int(String(scalar))
    }
}
