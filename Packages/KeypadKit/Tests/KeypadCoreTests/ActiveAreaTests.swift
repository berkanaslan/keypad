import Foundation
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

    @Test func areaIsClampedInsideTheSurface() {
        let area = ActiveArea(x: 0.9, y: -0.3, width: 0.5, height: 0.5)
        #expect(area.x == 0.5 && area.y == 0 && area.width == 0.5 && area.height == 0.5)
    }

    @Test func areaNeverShrinksBelowTheMinimum() {
        let area = ActiveArea(x: 0.1, y: 0.1, width: 0.01, height: 0)
        #expect(area.width == 0.2 && area.height == 0.2)
    }

    @Test func oversizedAreaBecomesTheWholeSurface() {
        #expect(ActiveArea(x: -1, y: -1, width: 3, height: 3) == .fullSurface)
    }

    @Test func nonFiniteValuesGiveTheWholeSurface() {
        #expect(ActiveArea(x: .nan, y: 0, width: .infinity, height: 0.5) == .fullSurface)
    }

    @Test func draggingPastTheEdgeStopsAtIt() {
        let area = ActiveArea(x: 0.5, y: 0.5, width: 0.4, height: 0.4).moved(byX: 0.5, y: -0.9)
        #expect(approximately(area, ActiveArea(x: 0.6, y: 0, width: 0.4, height: 0.4)))
    }

    @Test func resizingKeepsTheOppositeCorner() {
        let area = ActiveArea(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
            .resized(corner: .topRight, to: TrackpadPoint(x: 0.9, y: 0.8))
        #expect(approximately(area, ActiveArea(x: 0.2, y: 0.2, width: 0.7, height: 0.6)))
    }

    @Test func resizingStopsAtTheMinimum() {
        let area = ActiveArea(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
            .resized(corner: .bottomLeft, to: TrackpadPoint(x: 0.59, y: 0.59))
        #expect(approximately(area, ActiveArea(x: 0.4, y: 0.4, width: 0.2, height: 0.2)))
    }

    @Test func resizingPastTheEdgeKeepsTheOppositeCorner() {
        let area = ActiveArea(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
            .resized(corner: .bottomLeft, to: TrackpadPoint(x: -0.5, y: -0.5))
        #expect(approximately(area, ActiveArea(x: 0, y: 0, width: 0.6, height: 0.6)))
    }

    @Test func draggingACornerPastTheOppositeEdgeStopsAtTheMinimum() {
        let area = ActiveArea(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
            .resized(corner: .topRight, to: TrackpadPoint(x: -0.3, y: 0.5))
        #expect(approximately(area, ActiveArea(x: 0.2, y: 0.2, width: 0.2, height: 0.3)))
    }

    @Test func resizingEvenlyKeepsTheCentre() {
        let area = ActiveArea(x: 0.3, y: 0.3, width: 0.4, height: 0.4).resizedEvenly(by: 0.1)
        #expect(approximately(area, ActiveArea(x: 0.25, y: 0.25, width: 0.5, height: 0.5)))
    }

    @Test func decodingClampsToo() throws {
        let data = Data(#"{"x":0.9,"y":0.9,"width":0.5,"height":0.5}"#.utf8)
        #expect(
            try JSONDecoder().decode(ActiveArea.self, from: data) == ActiveArea(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        )
    }

    private func approximately(_ lhs: ActiveArea, _ rhs: ActiveArea) -> Bool {
        [lhs.x - rhs.x, lhs.y - rhs.y, lhs.width - rhs.width, lhs.height - rhs.height].allSatisfy { abs($0) < 1e-9 }
    }
}
