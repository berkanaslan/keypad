import AppKit
import Carbon.HIToolbox
import Testing

@testable import KeypadSystem

@Suite struct PostedKeystrokeTagTests {
    private func keyDown() throws -> CGEvent {
        try #require(CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_Keypad7), keyDown: true))
    }

    @Test func taggedEventIsRecognisedAsKeypadsOwn() throws {
        let event = try keyDown()
        PostedKeystrokeTag.mark(event)

        let received = try #require(NSEvent(cgEvent: event))

        #expect(PostedKeystrokeTag.isMarked(received))
    }

    @Test func untaggedEventIsNotRecognised() throws {
        let received = try #require(NSEvent(cgEvent: try keyDown()))

        #expect(!PostedKeystrokeTag.isMarked(received))
    }
}
