import Foundation
import Testing

@testable import KeypadCore

private func sample(
    _ id: Int,
    _ phase: TouchSample.Phase,
    _ x: Double,
    _ y: Double,
    _ t: TimeInterval
) -> TouchSample {
    TouchSample(id: id, phase: phase, point: TrackpadPoint(x: x, y: y), time: t)
}

@Suite struct TapRecognizerTests {
    @Test func beganEmitsTouchDown() {
        var r = TapRecognizer()
        #expect(r.handle(sample(1, .began, 0.2, 0.8, 0)) == .touchDown(TrackpadPoint(x: 0.2, y: 0.8)))
    }

    @Test func quickStillTouchIsATapAtItsStartPoint() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        #expect(r.handle(sample(1, .ended, 0.21, 0.8, 0.15)) == .tap(TrackpadPoint(x: 0.2, y: 0.8)))
    }

    @Test func restingTouchNeverTaps() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.41)) == nil)
    }

    @Test func movedTouchIsNotATap() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        _ = r.handle(sample(1, .moved, 0.25, 0.8, 0.1))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.2)) == nil)
    }

    @Test func cancelledTouchIsNotATap() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        _ = r.handle(sample(1, .cancelled, 0.2, 0.8, 0.1))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.15)) == nil)
    }

    @Test func overlappingTouchesTapIndependently() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        _ = r.handle(sample(2, .began, 0.8, 0.2, 0.05))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.1)) == .tap(TrackpadPoint(x: 0.2, y: 0.8)))
        #expect(r.handle(sample(2, .ended, 0.8, 0.2, 0.2)) == .tap(TrackpadPoint(x: 0.8, y: 0.2)))
    }

    @Test func endWithoutBeginIsIgnored() {
        var r = TapRecognizer()
        #expect(r.handle(sample(9, .ended, 0.5, 0.5, 1)) == nil)
    }
}
