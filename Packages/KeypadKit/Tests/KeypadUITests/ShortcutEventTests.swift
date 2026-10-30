import AppKit
import KeypadCore
import Testing

@testable import KeypadUI

@Test func eventFlagsKeepOnlyShortcutModifiers() {
    let flags: NSEvent.ModifierFlags = [.command, .shift, .function, .numericPad, .capsLock]
    #expect(ShortcutModifiers(eventFlags: flags) == [.command, .shift])
}

@Test func eventFlagsMapControlAndOption() {
    #expect(ShortcutModifiers(eventFlags: [.control, .option]) == [.control, .option])
}
