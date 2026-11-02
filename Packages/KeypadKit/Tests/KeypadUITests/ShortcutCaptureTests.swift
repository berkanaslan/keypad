import KeypadCore
import Testing

@testable import KeypadUI

@MainActor
@Suite struct ShortcutCaptureTests {
    @Test func startingTwiceLeaksNoMonitor() {
        var active = 0
        let capture = ShortcutCapture(
            install: { _, _ in
                active += 1
                return active
            },
            remove: { _ in active -= 1 }
        )
        capture.start(onKey: { _ in }, onCancel: {})
        capture.start(onKey: { _ in }, onCancel: {})
        #expect(active == 2)
        capture.stop()
        #expect(active == 0 && !capture.isCapturing)
    }
}
