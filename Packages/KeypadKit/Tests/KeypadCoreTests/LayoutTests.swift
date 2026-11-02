import Testing

@testable import KeypadCore

@Suite struct LayoutTests {
    @Test func numpadIsThreeByFour() {
        #expect(Layout.numpad.rows == 4 && Layout.numpad.columns == 3 && Layout.numpad.cells.count == 12)
    }

    @Test func topLeftIsSeven() {
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 0.1, y: 0.95))?.action == .digit(7))
    }

    @Test func bottomRowIsZeroSeparatorBackspace() {
        let actions = [0.1, 0.5, 0.9].map { Layout.numpad.cell(at: TrackpadPoint(x: $0, y: 0.05))?.action }
        #expect(actions == [.digit(0), .decimalSeparator, .backspace])
    }

    @Test func centreIsFive() {
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 0.5, y: 0.6))?.action == .digit(5))
    }

    @Test func outerEdgesClampIntoTheGrid() {
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 1, y: 1))?.action == .digit(9))
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 0, y: 0))?.action == .digit(0))
    }
}
