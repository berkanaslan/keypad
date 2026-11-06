import Testing

@testable import KeypadSystem

@MainActor @Test func ticksUntilStopped() async {
    let watcher = TimerPermissionWatcher(interval: .milliseconds(5))
    var ticks = 0
    watcher.start { ticks += 1 }

    let deadline = ContinuousClock.now + .seconds(2)
    while ticks == 0 && ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
    watcher.stop()
    let ticksAtStop = ticks
    try? await Task.sleep(for: .milliseconds(30))

    #expect(ticksAtStop > 0)
    #expect(ticks == ticksAtStop)
}
