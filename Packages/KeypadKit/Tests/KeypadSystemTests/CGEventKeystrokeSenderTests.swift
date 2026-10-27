import Carbon.HIToolbox
import CoreGraphics
import KeypadCore
import Testing

@testable import KeypadSystem

@MainActor
@Suite struct CGEventKeystrokeSenderTests {
    @Test func completionRunsAfterSendReturns() async {
        let sender = CGEventKeystrokeSender(deliveryBase: .milliseconds(1), deliveryPerKeystroke: .zero)
        var completed = false

        await withCheckedContinuation { continuation in
            sender.send([]) {
                completed = true
                continuation.resume()
            }
            #expect(!completed)
        }

        #expect(completed)
    }

    @Test func everyPostedEventCarriesTheKeypadTag() {
        let keystrokes: [Keystroke] = [.keypadDigit(7), .keypadDecimal, .commit(.tab), .commit(.arrow(.left))]

        let events = CGEventKeystrokeSender.events(for: keystrokes)

        #expect(events.count == keystrokes.count * 2)
        for event in events {
            #expect(event.getIntegerValueField(.eventSourceUserData) == PostedKeystrokeTag.value)
        }
    }

    @Test func eventsAlternateKeyDownAndKeyUpPerKeystroke() {
        let events = CGEventKeystrokeSender.events(for: [.keypadDigit(1), .commit(.tab)])

        #expect(
            events.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [
                Int64(kVK_ANSI_Keypad1), Int64(kVK_ANSI_Keypad1), Int64(kVK_Tab), Int64(kVK_Tab),
            ])
        #expect(events.map { $0.type } == [.keyDown, .keyUp, .keyDown, .keyUp])
    }
}
