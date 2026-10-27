import Carbon.HIToolbox
import CoreGraphics
import KeypadCore

public struct KeyEvent: Equatable, Sendable {
    public let code: CGKeyCode
    public let flags: CGEventFlags

    public init(code: CGKeyCode, flags: CGEventFlags) {
        self.code = code
        self.flags = flags
    }
}

public enum KeystrokeMapping {
    private static let keypadDigitCodes: [Int] = [
        kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4,
        kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9,
    ]

    public static func keyEvent(for keystroke: Keystroke) -> KeyEvent {
        switch keystroke {
        case .keypadDigit(let digit): event(keypadDigitCodes[digit], .maskNumericPad)
        case .keypadDecimal: event(kVK_ANSI_KeypadDecimal, .maskNumericPad)
        case .commit(let key): keyEvent(for: key)
        }
    }

    private static func keyEvent(for key: CommitKey) -> KeyEvent {
        switch key {
        case .returnKey: event(kVK_Return, [])
        case .shiftReturn: event(kVK_Return, .maskShift)
        case .keypadEnter: event(kVK_ANSI_KeypadEnter, .maskNumericPad)
        case .tab: event(kVK_Tab, [])
        case .shiftTab: event(kVK_Tab, .maskShift)
        case .arrow(let direction): event(arrowCode(direction), [.maskNumericPad, .maskSecondaryFn])
        }
    }

    private static func arrowCode(_ direction: ArrowDirection) -> Int {
        switch direction {
        case .left: kVK_LeftArrow
        case .right: kVK_RightArrow
        case .up: kVK_UpArrow
        case .down: kVK_DownArrow
        }
    }

    private static func event(_ code: Int, _ flags: CGEventFlags) -> KeyEvent {
        KeyEvent(code: CGKeyCode(code), flags: flags)
    }
}
