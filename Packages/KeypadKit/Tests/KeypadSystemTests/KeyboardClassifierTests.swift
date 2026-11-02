import Carbon.HIToolbox
import KeypadCore
import Testing

@testable import KeypadSystem

@Suite struct KeyboardClassifierTests {
    @Test func topRowAndKeypadDigitsAreDigits() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_ANSI_7), characters: "7", isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ",")
                == .digit(7))
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_ANSI_Keypad3), characters: "3", isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ",")
                == .digit(3))
    }

    @Test func shiftedDigitKeyIsOther() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_ANSI_1), characters: "!", isShiftDown: true, isShortcutModifierDown: false,
                decimalSeparator: ",")
                == .other)
    }

    @Test func keypadDecimalIsDecimal() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_ANSI_KeypadDecimal), characters: ",", isShiftDown: false,
                isShortcutModifierDown: false, decimalSeparator: ",")
                == .decimalSeparator)
    }

    @Test func mainKeyboardKeyMatchingSeparatorIsDecimal() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_ANSI_Backslash), characters: ",", isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ",")
                == .decimalSeparator)
    }

    @Test func otherPunctuationIsOther() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_ANSI_Slash), characters: ".", isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ",")
                == .other)
    }

    @Test func commitKeysRespectShift() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_Return), characters: "\r", isShiftDown: true, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .commit(.shiftReturn))
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_Tab), characters: "\t", isShiftDown: true, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .commit(.shiftTab))
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_DownArrow), characters: nil, isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .commit(.arrow(.down)))
    }

    @Test(arguments: [
        (kVK_LeftArrow, ArrowDirection.left), (kVK_RightArrow, .right), (kVK_UpArrow, .up), (kVK_DownArrow, .down),
    ])
    func plainArrowsCommit(keyCode: Int, direction: ArrowDirection) {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(keyCode), characters: nil, isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .commit(.arrow(direction)))
    }

    @Test(arguments: [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow])
    func shiftedArrowsAreOther(keyCode: Int) {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(keyCode), characters: nil, isShiftDown: true, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .other)
    }

    @Test func escapeAndDelete() {
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_Escape), characters: "\u{1b}", isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .escape)
        #expect(
            KeyboardClassifier.classify(
                keyCode: UInt16(kVK_Delete), characters: "\u{7f}", isShiftDown: false, isShortcutModifierDown: false,
                decimalSeparator: ".")
                == .deleteBackward)
    }

    @Test func shortcutChordsAreOther() {
        let chords: [(keyCode: Int, characters: String?)] = [
            (kVK_UpArrow, nil),
            (kVK_ANSI_5, "5"),
            (kVK_Return, "\r"),
            (kVK_Tab, "\t"),
            (kVK_Escape, "\u{1b}"),
        ]
        for chord in chords {
            #expect(
                KeyboardClassifier.classify(
                    keyCode: UInt16(chord.keyCode), characters: chord.characters, isShiftDown: false,
                    isShortcutModifierDown: true, decimalSeparator: ".")
                    == .other)
        }
    }
}
