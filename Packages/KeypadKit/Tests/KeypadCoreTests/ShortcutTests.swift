import Foundation
import Testing

@testable import KeypadCore

@Suite struct ShortcutTests {
    @Test func defaultIsControlOptionK() {
        #expect(Shortcut.default == Shortcut(keyCode: 40, modifiers: [.control, .option]))
        #expect(Shortcut.default.isValid)
    }

    @Test(arguments: [
        ShortcutModifiers.command, .control, .option, [.option, .shift], [.shift], [],
    ])
    func letterNeedsTwoModifiersIncludingCommandOrControl(modifiers: ShortcutModifiers) {
        #expect(!Shortcut(keyCode: 40, modifiers: modifiers).isValid)
    }

    @Test(arguments: [
        ShortcutModifiers([.control, .option]), [.command, .shift], [.command, .control], [.control, .shift],
    ])
    func twoModifiersWithCommandOrControlAreValid(modifiers: ShortcutModifiers) {
        #expect(Shortcut(keyCode: 40, modifiers: modifiers).isValid)
    }

    @Test func functionKeysAreValidAloneAndWithModifiers() {
        #expect(Shortcut(keyCode: 96, modifiers: []).isValid)
        #expect(Shortcut(keyCode: 105, modifiers: [.option]).isValid)
    }

    @Test(arguments: Array(UInt16(54)...63))
    func modifierKeysAloneAreNeverValid(keyCode: UInt16) {
        #expect(!Shortcut(keyCode: keyCode, modifiers: [.command, .control]).isValid)
    }

    @Test func modifierRawValuesArePinned() {
        #expect(ShortcutModifiers.control.rawValue == 1 && ShortcutModifiers.option.rawValue == 2)
        #expect(ShortcutModifiers.shift.rawValue == 4 && ShortcutModifiers.command.rawValue == 8)
    }

    @Test func codableRoundTrip() throws {
        let shortcut = Shortcut(keyCode: 105, modifiers: [.command, .shift])
        let data = try JSONEncoder().encode(shortcut)
        #expect(try JSONDecoder().decode(Shortcut.self, from: data) == shortcut)
    }
}
