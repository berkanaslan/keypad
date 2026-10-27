import Testing

@testable import KeypadCore

@Suite struct EntryBufferTests {
    private func entry(_ actions: KeyAction...) -> EntryBuffer {
        var buffer = EntryBuffer()
        for action in actions { buffer.apply(action) }
        return buffer
    }

    @Test func digitsAndSeparatorBuildTheDisplay() {
        let b = entry(.digit(1), .digit(2), .decimalSeparator, .digit(5))
        #expect(b.display(decimalSeparator: ",") == "12,5")
        #expect(b.display(decimalSeparator: ".") == "12.5")
    }

    @Test func noValidationLikeAHardwareNumpad() {
        let b = entry(.digit(0), .digit(0), .decimalSeparator, .decimalSeparator, .digit(7))
        #expect(b.display(decimalSeparator: ".") == "00..7")
    }

    @Test func backspaceRemovesTheLastCharacter() {
        let b = entry(.digit(4), .digit(2), .backspace)
        #expect(b.display(decimalSeparator: ".") == "4")
    }

    @Test func backspaceOnEmptyDoesNothing() {
        var b = EntryBuffer()
        b.apply(.backspace)
        #expect(b.isEmpty)
    }

    @Test func keystrokesMirrorTheEntry() {
        let b = entry(.digit(3), .decimalSeparator, .digit(0))
        #expect(b.keystrokes == [.keypadDigit(3), .keypadDecimal, .keypadDigit(0)])
    }
}
