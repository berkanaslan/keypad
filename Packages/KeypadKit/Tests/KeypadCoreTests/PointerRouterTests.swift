import Testing

@testable import KeypadCore

private let leftHalf = ActiveArea(x: 0, y: 0, width: 0.5, height: 1)

private func sample(_ id: Int, _ phase: TouchSample.Phase, x: Double) -> TouchSample {
    TouchSample(id: id, phase: phase, point: TrackpadPoint(x: x, y: 0.5), time: 0)
}

@Suite struct PointerRouterTests {
    private var router = PointerRouter(area: leftHalf)

    private mutating func wake() {
        _ = router.handle(sample(1, .began, x: 0.8))
        _ = router.handle(sample(1, .moved, x: 0.85))
    }

    @Test mutating func stationaryTapOutsideDoesNothing() {
        #expect(router.handle(sample(1, .began, x: 0.8)) == [])
        #expect(router.handle(sample(1, .ended, x: 0.8)) == [])
        #expect(router.mode == .keypad)
    }

    @Test mutating func travelBelowTheLimitStaysAsleep() {
        _ = router.handle(sample(1, .began, x: 0.8))

        #expect(router.handle(sample(1, .moved, x: 0.83)) == [])
    }

    @Test mutating func travelOutsideWakesThePointer() {
        _ = router.handle(sample(1, .began, x: 0.8))

        #expect(router.handle(sample(1, .moved, x: 0.85)) == [.pointer(.pointer), .mousePassThrough(.on)])
        #expect(router.mode == .pointer)
    }

    @Test mutating func restingFingerOutsideStaysAsleepWhileTapping() {
        _ = router.handle(sample(1, .began, x: 0.2))
        _ = router.handle(sample(2, .began, x: 0.8))

        #expect(router.handle(sample(2, .moved, x: 0.9)) == [])
        #expect(router.mode == .keypad)
    }

    @Test mutating func aFingerSlidingOutOfTheAreaStaysAKeypadContact() {
        _ = router.handle(sample(1, .began, x: 0.4))

        #expect(router.handle(sample(1, .moved, x: 0.9)) == [])
        #expect(router.mode == .keypad)
    }

    @Test mutating func aFingerSlidingIntoTheAreaKeepsMovingThePointer() {
        wake()

        #expect(router.handle(sample(1, .moved, x: 0.3)) == [])
        #expect(router.mode == .pointer)
    }

    @Test mutating func lastLiftStartsTheGrace() {
        wake()
        _ = router.handle(sample(2, .began, x: 0.9))

        #expect(router.handle(sample(1, .ended, x: 0.85)) == [])
        #expect(router.handle(sample(2, .ended, x: 0.9)) == [.mousePassThrough(.offAfterGrace)])
    }

    @Test mutating func aCancelledContactCountsAsLifted() {
        wake()

        #expect(router.handle(sample(1, .cancelled, x: 0.85)) == [.mousePassThrough(.offNow)])
    }

    @Test mutating func liftAfterASingleFingerTravelEndsPassThroughAtOnce() {
        wake()

        #expect(router.handle(sample(1, .ended, x: 0.85)) == [.mousePassThrough(.offNow)])
    }

    @Test mutating func liftAfterAStationaryTouchKeepsTheGrace() {
        wake()
        _ = router.handle(sample(1, .ended, x: 0.85))
        _ = router.handle(sample(2, .began, x: 0.8))

        #expect(router.handle(sample(2, .ended, x: 0.8)) == [.mousePassThrough(.offAfterGrace)])
    }

    @Test mutating func fingersAreCountedAfreshForEachTouch() {
        wake()
        _ = router.handle(sample(2, .began, x: 0.9))
        _ = router.handle(sample(1, .ended, x: 0.85))
        _ = router.handle(sample(2, .ended, x: 0.9))
        _ = router.handle(sample(3, .began, x: 0.8))
        _ = router.handle(sample(3, .moved, x: 0.85))

        #expect(router.handle(sample(3, .ended, x: 0.85)) == [.mousePassThrough(.offNow)])
    }

    @Test mutating func aFingerDownThroughATapCanNotWakeThePointer() {
        _ = router.handle(sample(1, .began, x: 0.8))
        _ = router.handle(sample(2, .began, x: 0.2))
        _ = router.handle(sample(2, .ended, x: 0.2))

        #expect(router.handle(sample(1, .moved, x: 0.85)) == [])
        #expect(router.mode == .keypad)
    }

    @Test mutating func landingOutsideInPointerModePassesMouseInput() {
        wake()
        _ = router.handle(sample(1, .ended, x: 0.85))

        #expect(router.handle(sample(2, .began, x: 0.8)) == [.mousePassThrough(.on)])
    }

    @Test mutating func landingInTheAreaEndsPassThroughAtOnce() {
        wake()
        _ = router.handle(sample(1, .ended, x: 0.85))

        #expect(router.handle(sample(2, .began, x: 0.2)) == [.mousePassThrough(.offNow), .pointer(.keypad)])
        #expect(router.mode == .keypad)
    }

    @Test func wholeSurfaceNeverWakes() {
        var router = PointerRouter(area: .fullSurface)
        _ = router.handle(sample(1, .began, x: 0.99))

        #expect(router.handle(sample(1, .moved, x: 0.5)) == [])
        #expect(router.mode == .keypad)
    }

    @Test mutating func resetFromPointerModeFreezes() {
        wake()

        #expect(router.reset() == [.mousePassThrough(.offNow), .pointer(.keypad)])
        #expect(router.mode == .keypad)
    }

    @Test mutating func resetFromKeypadModeDoesNothing() {
        #expect(router.reset() == [])
    }

    @Test mutating func aContactHeldThroughAResetIsIgnored() {
        wake()
        _ = router.reset()

        #expect(router.handle(sample(1, .moved, x: 0.95)) == [])
        #expect(router.handle(sample(1, .ended, x: 0.95)) == [])
        #expect(router.mode == .keypad)
    }
}
