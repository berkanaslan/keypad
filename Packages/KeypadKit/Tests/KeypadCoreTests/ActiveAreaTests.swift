import Testing

@testable import KeypadCore

@Suite struct ActiveAreaTests {
    @Test func fullSurfaceMapsPointsUnchanged() {
        #expect(ActiveArea.fullSurface.map(TrackpadPoint(x: 0.25, y: 0.75)) == TrackpadPoint(x: 0.25, y: 0.75))
    }

    @Test func pointsOutsideTheAreaAreIgnored() {
        let rightHalf = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)
        #expect(rightHalf.map(TrackpadPoint(x: 0.3, y: 0.5)) == nil)
    }

    @Test func pointsInsideAreRelativeToTheArea() {
        let rightHalf = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)
        #expect(rightHalf.map(TrackpadPoint(x: 0.75, y: 0.5)) == TrackpadPoint(x: 0.5, y: 0.5))
    }

    @Test func edgesBelongToTheArea() {
        #expect(ActiveArea.fullSurface.map(TrackpadPoint(x: 1, y: 0)) == TrackpadPoint(x: 1, y: 0))
    }
}
