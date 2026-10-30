import CoreGraphics
import KeypadCore
import Testing

@testable import KeypadUI

@MainActor
@Suite struct ActiveAreaEditorTests {
    private let size = CGSize(width: 160, height: 100)

    @Test func viewRectFlipsTheTrackpadYAxis() {
        let rect = ActiveAreaEditor.viewRect(for: ActiveArea(x: 0.5, y: 0, width: 0.5, height: 0.5), in: size)
        #expect(rect == CGRect(x: 80, y: 50, width: 80, height: 50))
    }

    @Test func viewLocationsMapBackToTrackpadPoints() {
        #expect(ActiveAreaEditor.trackpadPoint(for: CGPoint(x: 40, y: 25), in: size) == TrackpadPoint(x: 0.25, y: 0.75))
    }

    @Test func voiceOverReadsSizeAndPosition() {
        let value = ActiveAreaEditor.accessibilityValue(for: ActiveArea(x: 0.2, y: 0.1, width: 0.4, height: 0.5))
        #expect(value == "Width 40%, height 50%, 20% from the left, 10% from the bottom")
    }
}
