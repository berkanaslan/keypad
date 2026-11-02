import Carbon.HIToolbox
import KeypadCore
import Testing

@testable import KeypadSystem

@Test func carbonModifiersMapEveryFlag() {
    #expect(CarbonHotkey.carbonModifiers([.control, .option]) == UInt32(controlKey | optionKey))
    #expect(CarbonHotkey.carbonModifiers([.command, .shift]) == UInt32(cmdKey | shiftKey))
    #expect(CarbonHotkey.carbonModifiers([]) == 0)
}

@Test func coreFunctionKeyCodesMatchCarbon() {
    let carbon = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13,
        kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ].map { UInt16($0) }
    #expect(Shortcut.functionKeyCodes == carbon)
    #expect(Shortcut.default.keyCode == UInt16(kVK_ANSI_K))
}
