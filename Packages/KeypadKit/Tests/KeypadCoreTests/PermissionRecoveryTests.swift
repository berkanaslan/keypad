import Testing

@testable import KeypadCore

@MainActor
struct PermissionRecoveryTests {
    private let permission = FakePermission()
    private let watcher = FakeWatcher()
    private let notices = FakeNotices()
    private let recovery: PermissionRecovery

    init() {
        recovery = PermissionRecovery(permission: permission, watcher: watcher, notices: notices)
    }

    @Test func startsWatchingOnlyWhenMissing() {
        recovery.watchIfMissing()

        #expect(watcher.startCount == 0)
    }

    @Test func watchingTwiceKeepsOneWatcher() {
        permission.canPostEvents = false

        recovery.watchIfMissing()
        recovery.watchIfMissing()

        #expect(watcher.startCount == 1)
    }

    @Test func aTickWithoutAGrantKeepsWatching() {
        permission.canPostEvents = false
        recovery.watchIfMissing()

        watcher.fire()

        #expect(watcher.stopCount == 0)
        #expect(notices.shown == [])
    }

    @Test func aGrantStopsWatchingAndTellsTheUserOnce() {
        permission.canPostEvents = false
        recovery.watchIfMissing()

        permission.canPostEvents = true
        watcher.fire()
        watcher.fire()

        #expect(watcher.stopCount == 1)
        #expect(notices.shown == [.permissionGranted])
    }

    @Test func aRevokeAfterAGrantWatchesAgain() {
        permission.canPostEvents = false
        recovery.watchIfMissing()
        permission.canPostEvents = true
        watcher.fire()

        permission.canPostEvents = false
        recovery.watchIfMissing()

        #expect(watcher.startCount == 2)
    }
}
