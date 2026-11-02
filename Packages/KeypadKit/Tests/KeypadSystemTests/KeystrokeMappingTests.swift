import Carbon.HIToolbox
import CoreGraphics
import KeypadCore
import Testing

@testable import KeypadSystem

@Suite struct KeystrokeMappingTests {
    @Test func keypadDigitsCarryTheNumericPadFlag() {
        #expect(
            KeystrokeMapping.keyEvent(for: .keypadDigit(8))
                == KeyEvent(code: CGKeyCode(kVK_ANSI_Keypad8), flags: .maskNumericPad))
    }

    @Test func shiftTabCarriesShift() {
        #expect(
            KeystrokeMapping.keyEvent(for: .commit(.shiftTab))
                == KeyEvent(code: CGKeyCode(kVK_Tab), flags: .maskShift))
    }

    @Test func arrowsCarryNumericPadAndFn() {
        #expect(
            KeystrokeMapping.keyEvent(for: .commit(.arrow(.left)))
                == KeyEvent(code: CGKeyCode(kVK_LeftArrow), flags: [.maskNumericPad, .maskSecondaryFn]))
    }

    @Test func plainReturnHasNoFlags() {
        #expect(
            KeystrokeMapping.keyEvent(for: .commit(.returnKey))
                == KeyEvent(code: CGKeyCode(kVK_Return), flags: []))
    }
}
