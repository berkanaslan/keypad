import Carbon.HIToolbox
import KeypadCore
import Testing

@testable import KeypadSystem

@MainActor
@Test func namesUseApplesModifierOrder() {
    let names = KeyboardLayoutShortcutNames()
    #expect(names.name(for: Shortcut(keyCode: UInt16(kVK_F5), modifiers: [.command, .control])) == "⌃⌘F5")
    #expect(
        names.name(for: Shortcut(keyCode: UInt16(kVK_LeftArrow), modifiers: [.shift, .option, .control])) == "⌃⌥⇧←")
}

@MainActor
@Test func specialKeysHaveSymbols() {
    let names = KeyboardLayoutShortcutNames()
    #expect(names.name(for: Shortcut(keyCode: UInt16(kVK_Return), modifiers: [])) == "↩")
    #expect(names.name(for: Shortcut(keyCode: UInt16(kVK_Space), modifiers: [])) == "␣")
}
